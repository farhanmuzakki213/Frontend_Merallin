// lib/bbm_waiting_verification.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'models/bbm_model.dart';
import 'models/trip_model.dart'; // Dibutuhkan untuk extension .isRejected
import 'providers/auth_provider.dart';
import 'providers/bbm_provider.dart';

class BbmVerificationResult {
  final bool isApproved;
  final BbmKendaraan? updatedBbm;
  BbmVerificationResult({required this.isApproved, this.updatedBbm});
}

class BbmWaitingVerificationScreen extends StatefulWidget {
  final int bbmId;
  final int initialPage;

  const BbmWaitingVerificationScreen({
    super.key, 
    required this.bbmId,
    required this.initialPage,
  });

  @override
  State<BbmWaitingVerificationScreen> createState() => _BbmWaitingVerificationScreenState();
}

class _BbmWaitingVerificationScreenState extends State<BbmWaitingVerificationScreen> {
  Timer? _pollingTimer;
  Timer? _timeoutTimer; // Timer untuk pesan timeout
  bool _showTimeoutMessage = false; // State untuk menampilkan pesan

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer(); // Jalankan timer timeout
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startPolling();
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _checkBbmStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkBbmStatus());
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

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel(); // Matikan juga timer timeout
    super.dispose();
  }

  void _stopAllTimers() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  Future<void> _checkBbmStatus() async {
    if (!mounted) return;
    
    final provider = context.read<BbmProvider>();
    final token = context.read<AuthProvider>().token!;
    final bbm = await provider.getBbmDetails(token, widget.bbmId);

    if (!mounted || bbm == null) return;

    List<BbmPhotoVerificationStatus> getRelevantStatuses(BbmKendaraan bbm) {
      switch (widget.initialPage) {
        case 0: return [bbm.startKmPhotoStatus];
        case 2: return [bbm.endKmPhotoStatus, bbm.notaPengisianPhotoStatus];
        default: return [];
      }
    }

    final relevantStatuses = getRelevantStatuses(bbm);
    if (relevantStatuses.isEmpty) {
      _stopAllTimers();
      Navigator.of(context).pop();
      return;
    }

    final bool allPhotosDecided = relevantStatuses.every((s) => !s.isPending);

    if (!allPhotosDecided) {
      return; // Lanjutkan polling
    }

    _stopAllTimers();

    final bool hasAnyRejection = relevantStatuses.any((s) => s.isRejected);

    Navigator.of(context).pop(
      BbmVerificationResult(
        isApproved: !hasAnyRejection,
        updatedBbm: bbm,
      ),
    );
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
                SvgPicture.asset('assets/MERALLIN_LOGO_WAITING.svg', height: 70),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                const Text('Menunggu Verifikasi Admin',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('Data pengisian BBM Anda sedang diperiksa. Mohon tunggu sebentar.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center),
                
                // --- WIDGET PESAN TIMEOUT ---
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
