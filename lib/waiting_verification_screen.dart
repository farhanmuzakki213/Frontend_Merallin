// lib/waiting_verification_screen.dart

import 'dart:async'; // <-- PERBAIKAN DI SINI
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';

// Helper class to pass result back from the waiting screen
enum TripStatus { approved, rejected }

class VerificationResult {
  final TripStatus status;
  final int targetPage;
  final Trip updatedTrip; // Pass the whole trip back for consistency
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

class WaitingVerificationScreenState extends State<WaitingVerificationScreen> {
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  bool _showTimeoutMessage = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startTimeoutTimer();
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
    // Perform the first check immediately.
    Future.microtask(() => _checkTripStatus(isFirstCheck: true));

    // Start polling the server after a short delay to get subsequent updates.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
      Navigator.of(context).pop(
        VerificationResult(
          status: TripStatus.rejected,
          rejectionReason: trip.allRejectionReasons ?? "Satu atau lebih dokumen ditolak.",
          targetPage: rejectedDoc?.pageIndex ?? widget.initialPage,
          updatedTrip: trip,
        ),
      );
    } else {
      // 4. Jika tidak ada yang PENDING dan tidak ada yang REJECTED, berarti semua APPROVED.
      // Lanjutkan ke halaman berikutnya.
      final newPage = _determinePageAfterApproval(trip);
      Navigator.of(context).pop(
        VerificationResult(
          status: TripStatus.approved,
          targetPage: newPage,
          updatedTrip: trip,
        ),
      );
    }
  }

  List<PhotoVerificationStatus> _getRelevantStatuses(Trip trip) {
    // Check the approval status only for the documents relevant to the page we came from.
    switch (widget.initialPage) {
      case 0: // From 'Mulai Perjalanan'
        return [trip.startKmPhotoStatus];
      case 3: // From 'Surat Jalan Awal'
        return [trip.muatPhotoStatus, trip.deliveryLetterInitialStatus];
      case 4: // From 'Dokumen Tambahan'
        return [trip.deliveryOrderStatus, trip.segelPhotoStatus, trip.timbanganKendaraanPhotoStatus];
      case 7: // From 'Bukti Akhir'
        return [trip.endKmPhotoStatus, trip.bongkarPhotoStatus, trip.deliveryLetterFinalStatus];
      default:
        return [];
    }
  }

  int _determinePageAfterApproval(Trip trip) {
    if (trip.derivedStatus == TripDerivedStatus.selesai || trip.endKm != null) {
      return 7;
    }
    if (trip.statusMuatan == 'selesai bongkar') {
      return 7;
    }
    if (trip.statusLokasi == 'di lokasi bongkar') {
      return 6;
    }
    if (trip.statusLokasi == 'menuju lokasi bongkar') {
      if (trip.deliveryOrderPath == null || trip.segelPhotoPath == null || trip.timbanganKendaraanPhotoPath == null) {
        return 4; 
      }
      return 5;
    }
    if (trip.statusMuatan == 'selesai muat') {
      if (trip.muatPhotoPath == null) {
        return 3;
      }
      return 4;
    }
    if (trip.statusLokasi == 'di lokasi muat') {
      return 2;
    }
    if (trip.statusLokasi == 'menuju lokasi muat' || trip.startKm != null) {
      return 1;
    }
    return 0;
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
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Menunggu Verifikasi Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Data Anda sedang diperiksa oleh admin. Mohon tunggu sebentar.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
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