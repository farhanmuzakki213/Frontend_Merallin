// lib/screens/waiting_vehicle_location_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/vehicle_location_progress_screen.dart';
import 'package:provider/provider.dart';
import '../models/vehicle_location_model.dart';
import '../providers/vehicle_location_provider.dart';
import 'models/trip_model.dart';

// Helper class khusus untuk hasil verifikasi VehicleLocation
enum VehicleLocationStatus { approved, rejected }

class VehicleLocationVerificationResult {
  final VehicleLocationStatus status;
  final int targetPage;
  final VehicleLocation updatedLocation; // Menggunakan model yang sesuai
  final String? rejectionReason;

  VehicleLocationVerificationResult({
    required this.status,
    required this.targetPage,
    required this.updatedLocation,
    this.rejectionReason,
  });
}


class WaitingVehicleLocationVerificationScreen extends StatefulWidget {
  final int locationId;
  final int initialPage;
  final VehicleLocation? initialLocationState; // Menggunakan model yang sesuai
  final bool isRevisionResubmission;

  const WaitingVehicleLocationVerificationScreen({
    Key? key,
    required this.locationId,
    required this.initialPage,
    this.initialLocationState,
    this.isRevisionResubmission = false,
  }) : super(key: key);

  @override
  State<WaitingVehicleLocationVerificationScreen> createState() => _WaitingVehicleLocationVerificationScreenState();
}

class _WaitingVehicleLocationVerificationScreenState extends State<WaitingVehicleLocationVerificationScreen> with WidgetsBindingObserver {
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
      debugPrint("Aplikasi kembali aktif, memeriksa status verifikasi VehicleLocation...");
      _checkLocationStatus();
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _showTimeoutMessage = true;
        });
      }
    });
  }

  void _startPolling() {
    Future.microtask(() => _checkLocationStatus(isFirstCheck: true));

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _pollingCount++;
        });
      }
      _checkLocationStatus();
    });
  }

  Future<void> _checkLocationStatus({bool isFirstCheck = false}) async {
    if (!mounted) return;

    VehicleLocation? location;
    final locationProvider = Provider.of<VehicleLocationProvider>(context, listen: false);

    try {
      if (isFirstCheck && !widget.isRevisionResubmission && widget.initialLocationState != null) {
        location = widget.initialLocationState;
      } else {
        location = await locationProvider.getDetails(context.read<AuthProvider>().token!, widget.locationId);
      }
    } catch (e) {
      debugPrint("Error polling vehicle location status: $e");
      return;
    }
    
    if (!mounted || location == null) return;

    final relevantStatuses = _getRelevantStatuses(location);
    if (relevantStatuses.isEmpty) return; 

    final bool hasPending = relevantStatuses.any((s) => s.status == null || s.status!.isEmpty || s.status!.toLowerCase() == 'pending');
    if (hasPending) {
      return; // Lanjutkan polling
    }

    _stopTimers();

    final bool hasRejection = relevantStatuses.any((s) => s.status?.toLowerCase() == 'rejected');
    if (hasRejection) {
      final rejectedDoc = location.firstRejectedDocumentInfo;
      final result = VehicleLocationVerificationResult(
        status: VehicleLocationStatus.rejected,
          rejectionReason: location.allRejectionReasons ?? "Satu atau lebih dokumen ditolak.",
          targetPage: rejectedDoc?.pageIndex ?? widget.initialPage,
          updatedLocation: location,
      );
      locationProvider.setAndProcessVerificationResult(result);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) =>
                  VehicleLocationProgressScreen(locationId: widget.locationId)),
          (route) => false);
    } else {
      final newPage = _determinePageAfterApproval(location);
      if (location.isFullyCompleted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clearPendingVehicleLocationForVerification();
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false);
      } else {
        final result = VehicleLocationVerificationResult(
          status: VehicleLocationStatus.approved,
          targetPage: newPage,
          updatedLocation: location,
        );
        locationProvider.setAndProcessVerificationResult(result);
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => VehicleLocationProgressScreen(
                    locationId: widget.locationId)),
            (route) => false);
      }
    }
  }

  List<PhotoVerificationStatus> _getRelevantStatuses(VehicleLocation location) {
    switch (widget.initialPage) {
      case 0: // From 'Lokasi Awal & Standby'
        return [location.standbyPhotoStatus, location.startKmPhotoStatus];
      case 2: // From 'Bukti Akhir'
        return [location.endKmPhotoStatus];
      default:
        return [];
    }
  }

  int _determinePageAfterApproval(VehicleLocation location) {
    if (location.isFullyCompleted) {
      return 2; // Stay on the last page if finished
    }
    if (location.statusLokasi == 'menuju lokasi') {
      return 1; // Go to 'Tiba di Lokasi'
    }
    //
    if (location.statusLokasi == 'sampai di lokasi') {
      return 2;
    }
    return 1; // Fallback
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
    // UI-nya identik dengan waiting screen sebelumnya untuk konsistensi
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
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                const Text(
                  'Menunggu Verifikasi Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Data Anda sedang diperiksa oleh admin. Mohon tunggu sebentar.\n\n(Mengecek status ke server: #${_pollingCount + 1})',
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