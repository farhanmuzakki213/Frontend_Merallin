// lib/bbm_waiting_verification.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend_merallin/bbm_progress_screen.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:provider/provider.dart';
import 'models/bbm_model.dart';
import 'providers/auth_provider.dart';
import 'providers/bbm_provider.dart';

enum BbmFlowStatus { approved, rejected }

class BbmVerificationResult {
  final BbmFlowStatus status;
  final int targetPage;
  final BbmKendaraan updatedBbm;
  final String? rejectionReason;

  BbmVerificationResult({
    required this.status,
    required this.targetPage,
    required this.updatedBbm,
    this.rejectionReason,
  });
}

class BbmWaitingVerificationScreen extends StatefulWidget {
  final int bbmId;
  final int initialPage;
  final BbmKendaraan? initialBbmState;
  final bool isRevisionResubmission;

  const BbmWaitingVerificationScreen({
    super.key,
    required this.bbmId,
    required this.initialPage,
    this.initialBbmState,
    this.isRevisionResubmission = false,
  });

  @override
  State<BbmWaitingVerificationScreen> createState() =>
      _BbmWaitingVerificationScreenState();
}

class _BbmWaitingVerificationScreenState
    extends State<BbmWaitingVerificationScreen> with WidgetsBindingObserver {
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  bool _showTimeoutMessage = false;

  @override
  void initState() {
    super.initState();
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
      debugPrint("Aplikasi kembali aktif, memeriksa status verifikasi BBM...");
      _checkBbmStatus();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _checkBbmStatus(isFirstCheck: true);
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkBbmStatus());
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _showTimeoutMessage = true);
    });
  }

  @override
  void dispose() {
    _stopAllTimers();
    super.dispose();
  }

  void _stopAllTimers() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  List<BbmPhotoVerificationStatus> _getRelevantStatuses(BbmKendaraan bbm) {
    switch (widget.initialPage) {
      case 0:
        return [bbm.startKmPhotoStatus];
      case 2:
        return [bbm.endKmPhotoStatus, bbm.notaPengisianPhotoStatus];
      default:
        // Jika halaman tidak relevan untuk verifikasi, kembalikan list kosong
        return [];
    }
  }

  Future<void> _checkBbmStatus({bool isFirstCheck = false}) async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<BbmProvider>();

    final isSessionValid = await authProvider.checkActiveSession();
    if (!isSessionValid) {
      _stopAllTimers();
      return;
    }

    final token = authProvider.token!;
    BbmKendaraan? bbm;

    try {
      // Logika utama: tentukan apakah perlu fetch API atau bisa pakai data awal
      if (isFirstCheck &&
          !widget.isRevisionResubmission &&
          widget.initialBbmState != null) {
        bbm = widget.initialBbmState;
      } else {
        bbm = await provider.getBbmDetails(token, widget.bbmId);
      }
    } catch (e) {
      debugPrint("Gagal polling status BBM: $e");
      return; // Coba lagi di iterasi berikutnya
    }

    if (!mounted || bbm == null) return;

    final relevantStatuses = _getRelevantStatuses(bbm);
    if (relevantStatuses.isEmpty) {
      _stopAllTimers();
      final result = BbmVerificationResult(
        status: BbmFlowStatus.approved,
        updatedBbm: bbm,
        targetPage: widget.initialPage + 1,
      );
      provider.setAndProcessVerificationResult(result);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => BbmProgressScreen(bbmId: widget.bbmId)),
          (route) => false);
      return;
    }

    final bool hasPending = relevantStatuses.any((s) =>
        s.status == null ||
        s.status!.isEmpty ||
        s.status!.toLowerCase() == 'pending');
    if (hasPending) {
      return; // Lanjutkan polling
    }

    _stopAllTimers();

    final bool hasRejection = relevantStatuses.any((s) => s.isRejected);
    if (hasRejection) {
      final rejectedInfo = bbm.firstRejectedDocumentInfo;
      final result = BbmVerificationResult(
        status: BbmFlowStatus.rejected,
        updatedBbm: bbm,
        targetPage: rejectedInfo?.pageIndex ?? widget.initialPage,
        rejectionReason: bbm.allRejectionReasons,
      );
      provider.setAndProcessVerificationResult(result);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => BbmProgressScreen(bbmId: widget.bbmId)),
          (route) => false);
    } else {
      // Jika semua disetujui
      if (bbm.isFullyCompleted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.clearPendingBbmForVerification();
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false);
      } else {
        final result = BbmVerificationResult(
          status: BbmFlowStatus.approved,
          updatedBbm: bbm,
          targetPage: widget.initialPage + 1,
        );
        provider.setAndProcessVerificationResult(result);
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => BbmProgressScreen(bbmId: widget.bbmId)),
            (route) => false);
      }
    }
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
                SvgPicture.asset('assets/MERALLIN_LOGO_WAITING.svg',
                    height: 70),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                const Text('Menunggu Verifikasi Admin',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                    'Data pengisian BBM Anda sedang diperiksa. Mohon tunggu sebentar.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center),
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
