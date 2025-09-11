// lib/waiting_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/laporan_perjalanan_screen.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';

enum TripStatus { approved, rejected }

class VerificationResult {
  final TripStatus status;
  final int targetPage;
  final Trip updatedTrip;
  final String? rejectionReason;

  VerificationResult({
    required this.status,
    required this.targetPage,
    required this.updatedTrip,
    this.rejectionReason,
  });
}


class WaitingVerificationScreen extends StatefulWidget {
  final int tripId;
  final int initialPage;
  final Trip? initialTripState;
  final bool isRevisionResubmission;

  const WaitingVerificationScreen({
    Key? key,
    required this.tripId,
    required this.initialPage,
    this.initialTripState,
    this.isRevisionResubmission = false,
  }) : super(key: key);

  @override
  State<WaitingVerificationScreen> createState() => WaitingVerificationScreenState();
}

class WaitingVerificationScreenState extends State<WaitingVerificationScreen> with WidgetsBindingObserver {
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  bool _showTimeoutMessage = false;
  int _pollingCount = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startTimeoutTimer();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint("Aplikasi kembali aktif, memeriksa status verifikasi Trip...");
      _checkTripStatus();
    }
  }

  void _startTimeoutTimer() {
    // Set a timeout for 1 minute
    _timeoutTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _showTimeoutMessage = true;
        });
      }
    });
  }

  void _startPolling() {
    Future.microtask(() => _checkTripStatus(isFirstCheck: true));

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // <-- PERUBAHAN 2: Tambahkan setState untuk update counter -->
      if (mounted) {
        setState(() {
          _pollingCount++;
        });
      }
      _checkTripStatus();
    });
  }

  Future<void> _checkTripStatus({bool isFirstCheck = false}) async {
    if (!mounted) return;

    Trip? trip;
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    try {
      if (isFirstCheck && !widget.isRevisionResubmission && widget.initialTripState != null) {
        trip = widget.initialTripState;
      } else {
        trip = await tripProvider.getTripDetails(context.read<AuthProvider>().token!, widget.tripId);
      }
    } catch (e) {
      debugPrint("Error polling trip status: $e");
      return;
    }
    
    if (!mounted || trip == null) return;

    final relevantStatuses = _getRelevantStatuses(trip);
    if (relevantStatuses.isEmpty) return; 

    // 1. Periksa dulu apakah masih ada yang PENDING (belum diverifikasi).
    // Jika ya, maka tetap di halaman ini dan lanjutkan polling.
    final bool hasPending = relevantStatuses.any((s) => s.status == null || s.status!.isEmpty || s.status!.toLowerCase() == 'pending');
    if (hasPending) {
      return; // Lanjutkan polling
    }

    // 2. Jika KODE MENCAPAI TITIK INI, artinya admin sudah selesai memeriksa SEMUA foto
    // (tidak ada lagi yang PENDING). Sekarang saatnya menentukan hasilnya.
    _stopTimers();

    // 3. Periksa apakah ada yang REJECTED.
    final bool hasRejection = relevantStatuses.any((s) => s.status?.toLowerCase() == 'rejected');
    if (hasRejection) {
      // Jika ada, kembali untuk revisi.
      final rejectedDoc = trip.firstRejectedDocumentInfo;
      final result = VerificationResult(
        status: TripStatus.rejected,
        rejectionReason: trip.allRejectionReasons ?? "Satu atau lebih dokumen ditolak.",
        targetPage: rejectedDoc?.pageIndex ?? widget.initialPage,
        updatedTrip: trip,
      );
      tripProvider.setAndProcessVerificationResult(result);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LaporanDriverScreen(tripId: widget.tripId)),
        (route) => false,
      );
    } else {
      if (trip.isFullyCompleted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clearPendingTripForVerification();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        // Jika tahap selesai, buat result dan simpan ke provider
        final result = VerificationResult(
          status: TripStatus.approved,
          targetPage: _determinePageAfterApproval(trip),
          updatedTrip: trip,
        );
        tripProvider.setAndProcessVerificationResult(result);
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LaporanDriverScreen(tripId: widget.tripId)),
          (route) => false,
        );
      }
    }
  }

  List<PhotoVerificationStatus> _getRelevantStatuses(Trip trip) {
    switch (widget.initialPage) {
      case 0: // MULAI PERJALANAN
        return [trip.startKmPhotoStatus];
      case 2: // BUKTI KEDATANGAN MUAT
        return [
          trip.kmMuatPhotoStatus,
          trip.kedatanganMuatPhotoStatus,
          trip.deliveryOrderStatus
        ];
      case 3: // BUKTI PROSES MUAT
        return [trip.muatPhotoStatus];
      case 4: // DOKUMEN SELESAI MUAT
        return [
          trip.deliveryLetterInitialStatus,
          trip.segelPhotoStatus,
          trip.timbanganKendaraanPhotoStatus
        ];
      case 6: // BUKTI KEDATANGAN BONGKAR
        return [trip.endKmPhotoStatus, trip.kedatanganBongkarPhotoStatus];
      case 7: // BUKTI PROSES BONGKAR
        return [trip.bongkarPhotoStatus];
      case 8: // DOKUMEN SELESAI BONGKAR
        return [trip.deliveryLetterFinalStatus];
      default:
        // Halaman info (1, 5) tidak memerlukan pengecekan
        return [];
    }
  }

  int _determinePageAfterApproval(Trip trip) {
    if (widget.initialPage < 8) {
      return widget.initialPage + 1;
    }
    return 8;
  }


  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/MERALLIN_LOGO_WAITING.svg',
                  height: 70,
                ),
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                const Text(
                  'Menunggu Verifikasi Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // <-- PERUBAHAN 3: Perbarui teks untuk menampilkan counter -->
                const Text(
                  'Data Anda sedang diperiksa oleh admin. Mohon tunggu sebentar.',
                  // \n\n(Mengecek status ke server: #${_pollingCount + 1})'
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                if (_showTimeoutMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Card(
                      color: Colors.yellow[100],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Verifikasi memakan waktu lebih dari 1 menit. Anda dapat menghubungi admin untuk mempercepat proses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}