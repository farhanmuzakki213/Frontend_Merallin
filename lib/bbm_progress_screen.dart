// lib/screens/bbm_progress_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/widgets/in_app_widgets.dart';
import 'package:provider/provider.dart';
import 'bbm_waiting_verification.dart';
import 'models/bbm_model.dart';
import 'providers/auth_provider.dart';
import 'providers/bbm_provider.dart';
import 'services/bbm_service.dart'; // Import ApiException
import 'utils/image_helper.dart';

// Helper function
bool _isStringNullOrEmpty(String? str) {
  return str == null || str.isEmpty;
}

class BbmProgressScreen extends StatefulWidget {
  final int bbmId;
  final bool resumeVerification;

  const BbmProgressScreen({
    super.key,
    required this.bbmId,
    this.resumeVerification = false,
  });

  @override
  State<BbmProgressScreen> createState() => _BbmProgressScreenState();
}

class _BbmProgressScreenState extends State<BbmProgressScreen> {
  PageController? _pageController;
  int _currentPage = 0;
  BbmKendaraan? _currentBbm;
  bool _isLoading = true;
  bool _isSendingData = false;
  String? _error;

  final GlobalKey<_PageKmStartStateState> _kmStartKey = GlobalKey();
  final GlobalKey<_PageKmEndState> _kmEndKey = GlobalKey();

  final List<String> _pageTitles = [
    'FOTO KM AWAL',
    'PROSES PENGISIAN',
    'BUKTI AKHIR & SELESAI',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        context.read<AttendanceProvider>().checkTodayAttendanceStatus(
              context: context,
              token: authProvider.token!,
            );
      }
      _fetchDetailsAndProceed();
    });
  }

  Future<void> _fetchDetailsAndProceed({bool forceShowForm = false}) async {
    if (!mounted) return;
    if (!forceShowForm) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final provider = context.read<BbmProvider>();
      final token = context.read<AuthProvider>().token!;
      final bbm = await provider.getBbmDetails(token, widget.bbmId);

      if (!mounted || bbm == null) {
        setState(() {
          _isLoading = false;
          _error = "Gagal memuat data.";
        });
        return;
      }

      if (bbm.isFullyCompleted || bbm.statusBbmKendaraan == 'selesai') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tugas ini sudah selesai.'),
          backgroundColor: Colors.green,
        ));
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        return; // Hentikan eksekusi lebih lanjut
      }

      int determinedPage = _determineInitialPage(bbm);

      if (_pageController == null) {
        _pageController = PageController(initialPage: determinedPage);
      } else if (_pageController!.hasClients &&
          _pageController!.page?.round() != determinedPage) {
        _pageController!.jumpToPage(determinedPage);
      }

      setState(() {
        _currentBbm = bbm;
        _currentPage = determinedPage;
      });

      bool shouldGoToVerification = (widget.resumeVerification ||
              bbm.derivedStatus == BbmStatus.verifikasiGambar) &&
          !bbm.isFullyCompleted &&
          _hasSubmittedDocsForPage(bbm, determinedPage);

      if (shouldGoToVerification && !forceShowForm) {
        await _handleVerificationResult(bbm);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error di _fetchTripDetailsAndProceed: ${e.toString()}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Terjadi kesalahan: ${e.toString()}";
        });
      }
    }
  }

  bool _hasSubmittedDocsForPage(BbmKendaraan bbm, int page) {
    switch (page) {
      case 0:
        return !_isStringNullOrEmpty(bbm.startKmPhotoPath);
      case 2:
        return !_isStringNullOrEmpty(bbm.endKmPhotoPath) ||
            !_isStringNullOrEmpty(bbm.notaPengisianPhotoPath);
      default:
        return false;
    }
  }

  Future<void> _handleVerificationResult(BbmKendaraan bbm,
      {bool isRevisionResubmission = false}) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.setPendingBbmForVerification(bbm.id);

    setState(() {
      _isLoading = false;
    });

    final result = await Navigator.push<BbmVerificationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BbmWaitingVerificationScreen(
          bbmId: bbm.id,
          initialPage: _currentPage,
          initialBbmState: bbm,
          isRevisionResubmission: isRevisionResubmission,
        ),
      ),
    );

    await authProvider.clearPendingBbmForVerification();

    if (mounted) {
      if (result == null) {
        _fetchDetailsAndProceed(forceShowForm: true);
        return;
      }

      if (result.status == BbmFlowStatus.rejected) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Revisi Diperlukan: ${result.rejectionReason ?? "Dokumen ditolak."}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
        _fetchDetailsAndProceed(forceShowForm: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verifikasi berhasil!'),
          backgroundColor: Colors.green,
        ));
        if (result.updatedBbm.isFullyCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pengisian BBM telah selesai sepenuhnya!'),
            backgroundColor: Colors.blue));
        
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        return;
      }
        setState(() {
          _currentBbm = result.updatedBbm;
          _currentPage = _determineInitialPage(result.updatedBbm);
          if (_pageController!.hasClients) {
            _pageController?.animateToPage(_currentPage,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut);
          }
        });
      }
    }
  }

  int _determineInitialPage(BbmKendaraan bbm) {
    if (bbm.derivedStatus == BbmStatus.revisiGambar) {
      return bbm.firstRejectedDocumentInfo?.pageIndex ?? 0;
    }
    if (_isStringNullOrEmpty(bbm.startKmPhotoPath) ||
        !bbm.startKmPhotoStatus.isApproved) {
      return 0;
    }
    if (bbm.statusPengisian == 'sedang isi bbm') {
      return 1;
    }
    if (_isStringNullOrEmpty(bbm.endKmPhotoPath) ||
        !bbm.endKmPhotoStatus.isApproved ||
        _isStringNullOrEmpty(bbm.notaPengisianPhotoPath) ||
        !bbm.notaPengisianPhotoStatus.isApproved) {
      return 2;
    }
    // Jika semua sudah selesai
    return _currentPage;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _handleNextPage() async {
    if (_isSendingData || _currentBbm == null) return;
    setState(() => _isSendingData = true);

    try {
      BbmKendaraan? submittedBbm;
      final bool wasRevision =
          _currentBbm!.derivedStatus == BbmStatus.revisiGambar;

      switch (_currentPage) {
        case 0:
          submittedBbm = await _kmStartKey.currentState?.validateAndSubmit();
          break;
        case 1:
          submittedBbm = await _callSimpleAPI(
              () => context.read<BbmProvider>().finishFilling(
                    context.read<AuthProvider>().token!,
                    _currentBbm!.id,
                  ));
          break;
        case 2:
          submittedBbm = await _kmEndKey.currentState?.validateAndSubmit();
          break;
      }

      if (!mounted || submittedBbm == null) {
        setState(() => _isSendingData = false);
        return;
      }

      setState(() => _currentBbm = submittedBbm);

      bool needsVerification = [0, 2].contains(_currentPage);

      if (needsVerification) {
        await _handleVerificationResult(submittedBbm,
            isRevisionResubmission: wasRevision);
      } else {
        int nextPage = _currentPage + 1;
        if (nextPage < _pageTitles.length) {
          _pageController?.animateToPage(nextPage,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSendingData = false);
    }
  }

  Future<BbmKendaraan?> _callSimpleAPI(
      Future<BbmKendaraan> Function() apiCall) async {
    try {
      final updatedBbm = await apiCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Status berhasil diperbarui!'),
          backgroundColor: Colors.green,
        ));
      }
      return updatedBbm;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  void _showCannotExitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anda harus menyelesaikan pengisian BBM untuk keluar.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showCannotExitMessage();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    ))
                  : _error != null
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(_error!)))
                      : _buildPageView(),
            ),
            if (_isSendingData)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
            if (!_isLoading && _error == null && _currentBbm != null)
              DraggableSpeedDial(
                currentVehicle: _currentBbm!.vehicle,
                showBbmOption: false, // true untuk trip & trip geser
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    if (_currentBbm == null) {
      return const Center(child: Text("Data tidak tersedia."));
    }
    final isRevision = _currentBbm!.derivedStatus == BbmStatus.revisiGambar;

    return Column(
      children: [
        const AttendanceNotificationBanner(),
        _buildCustomAppBar(isRevision: isRevision),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: _buildProgressIndicator(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) =>
                _PageCardWrapper(child: _getPageContent(index)),
            itemCount: _pageTitles.length,
          ),
        ),
        if (_currentBbm?.derivedStatus != BbmStatus.selesai)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _buildBottomButton(isRevision: isRevision),
          ),
      ],
    );
  }

  Widget _buildCustomAppBar({required bool isRevision}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isRevision ? 'KIRIM ULANG REVISI' : _pageTitles[_currentPage],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          // const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    List<Widget> children = [];
    for (int i = 0; i < _pageTitles.length; i++) {
      final bool isActive = i <= _currentPage;
      // Tambah lingkaran
      children.add(
        CircleAvatar(
          radius: 5,
          backgroundColor: isActive ? Colors.black87 : Colors.grey.shade400,
        ),
      );

      // Tambah garis (kecuali untuk item terakhir)
      if (i < _pageTitles.length - 1) {
        children.add(
          Container(
            width: 80, // Lebar garis yang tetap
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            color: (i < _currentPage) ? Colors.black87 : Colors.grey.shade400,
          ),
        );
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _getPageContent(int index) {
    if (_currentBbm == null) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return _PageKmStartState(key: _kmStartKey, bbm: _currentBbm!);
      case 1:
        return const _PageInfo(
          title: 'Proses Pengisian BBM',
          subtitle:
              'Geser tombol di bawah jika Anda sudah selesai mengisi BBM.',
        );
      case 2:
        return _PageKmEnd(key: _kmEndKey, bbm: _currentBbm!);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton({required bool isRevision}) {
    String swipeText =
        isRevision ? 'Geser Untuk Kirim Revisi' : 'Geser Untuk Lanjutkan';
    if (!isRevision) {
      switch (_currentPage) {
        case 0:
          swipeText = 'Geser Untuk Mulai Pengisian';
          break;
        case 1:
          swipeText = 'Geser Jika Selesai Mengisi';
          break;
        case 2:
          swipeText = 'Geser Untuk Selesaikan';
          break;
      }
    }
    return _SwipeButton(
      text: swipeText,
      onConfirm: _handleNextPage,
      isSendingData: _isSendingData,
    );
  }
}

class _PageCardWrapper extends StatelessWidget {
  final Widget child;
  const _PageCardWrapper({required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          elevation: 5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(padding: const EdgeInsets.all(20.0), child: child),
        ),
      );
}

class _PageKmStartState extends StatefulWidget {
  final BbmKendaraan bbm;
  const _PageKmStartState({super.key, required this.bbm});
  @override
  State<_PageKmStartState> createState() => _PageKmStartStateState();
}

class _PageKmStartStateState extends State<_PageKmStartState> {
  File? _kmPhoto;

  Future<BbmKendaraan?> validateAndSubmit() async {
    if (_kmPhoto == null) {
      if (widget.bbm.startKmPhotoStatus.isRejected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto yang ditolak wajib diunggah ulang.'),
          backgroundColor: Colors.red,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto KM Awal wajib diisi.'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }
    return context.read<BbmProvider>().uploadStartKm(
          context.read<AuthProvider>().token!,
          widget.bbm.id,
          _kmPhoto!,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Lengkapi Data Awal',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),
        if (widget.bbm.startKmPhotoStatus.isApproved)
          const _ApprovedDocumentPlaceholder(title: 'Foto KM Awal')
        else
          _PhotoSection(
            title: 'Foto Seluruh Dashboard KM Awal',
            icon: Icons.speed,
            onImageChanged: (file) => setState(() => _kmPhoto = file),
            isApproved: widget.bbm.startKmPhotoStatus.isApproved,
            rejectionReason: widget.bbm.startKmPhotoStatus.rejectionReason,
          ),
      ],
    );
  }
}

class _PageInfo extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageInfo({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(subtitle,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _PageKmEnd extends StatefulWidget {
  final BbmKendaraan bbm;
  const _PageKmEnd({super.key, required this.bbm});
  @override
  State<_PageKmEnd> createState() => _PageKmEndState();
}

class _PageKmEndState extends State<_PageKmEnd> {
  File? _kmPhoto;
  File? _notaPhoto;

  Future<BbmKendaraan?> validateAndSubmit() async {
    final bool isKmRequired = !widget.bbm.endKmPhotoStatus.isApproved;
    final bool isNotaRequired = !widget.bbm.notaPengisianPhotoStatus.isApproved;

    if (isKmRequired && _kmPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto KM Akhir wajib diisi.'),
        backgroundColor: Colors.red,
      ));
      return null;
    }
    if (isNotaRequired && _notaPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto Nota Pengisian wajib diisi.'),
        backgroundColor: Colors.red,
      ));
      return null;
    }

    // Jika tidak ada foto baru yang perlu diupload (karena tidak direject)
    if (_kmPhoto == null && _notaPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Silakan unggah setidaknya satu foto revisi.'),
        backgroundColor: Colors.orange,
      ));
      return null;
    }

    return context.read<BbmProvider>().uploadEndKmAndNota(
          context.read<AuthProvider>().token!,
          widget.bbm.id,
          _kmPhoto,
          _notaPhoto,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Lengkapi Bukti Akhir',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),
        if (widget.bbm.endKmPhotoStatus.isApproved)
          const _ApprovedDocumentPlaceholder(title: 'Foto KM Akhir')
        else
          _PhotoSection(
            title: 'Foto KM Akhir',
            icon: Icons.speed,
            onImageChanged: (file) => setState(() => _kmPhoto = file),
            isApproved: widget.bbm.endKmPhotoStatus.isApproved,
            rejectionReason: widget.bbm.endKmPhotoStatus.rejectionReason,
          ),
        const SizedBox(height: 24),
        if (widget.bbm.notaPengisianPhotoStatus.isApproved)
          const _ApprovedDocumentPlaceholder(title: 'Foto Nota Pengisian')
        else
          _PhotoSection(
            title: 'Foto Nota Pengisian',
            icon: Icons.receipt_long,
            onImageChanged: (file) => setState(() => _notaPhoto = file),
            isApproved: widget.bbm.notaPengisianPhotoStatus.isApproved,
            rejectionReason:
                widget.bbm.notaPengisianPhotoStatus.rejectionReason,
          ),
      ],
    );
  }
}

class _SwipeButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirm;
  final bool isSendingData;
  const _SwipeButton(
      {required this.text,
      required this.onConfirm,
      required this.isSendingData});
  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  double _swipePosition = 0.0;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 60,
      decoration: BoxDecoration(
          color: const Color(0xFFFF7043),
          borderRadius: BorderRadius.circular(30)),
      child: GestureDetector(
        onHorizontalDragUpdate: widget.isSendingData
            ? null
            : (details) => setState(() => _swipePosition =
                (_swipePosition + details.delta.dx).clamp(0, 280)),
        onHorizontalDragEnd: widget.isSendingData
            ? null
            : (details) {
                if (_swipePosition > 280 * 0.75) widget.onConfirm();
                setState(() => _swipePosition = 0);
              },
        child: Stack(alignment: Alignment.center, children: [
          Text(widget.text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 50),
            left: _swipePosition,
            child: Container(
              width: 70,
              height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFF00838F),
                  borderRadius: BorderRadius.circular(30)),
              child: const Icon(Icons.local_gas_station,
                  color: Colors.white, size: 30),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PhotoSection extends StatefulWidget {
  final String title;
  final String? rejectionReason;
  final IconData icon;
  final ValueChanged<File?> onImageChanged;
  final bool isApproved;
  const _PhotoSection(
      {required this.title,
      required this.icon,
      required this.onImageChanged,
      this.rejectionReason,
      this.isApproved = false});
  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  File? _imageFile;
  bool get isRejected =>
      widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty;

  Future<void> _takePicture() async {
    if (widget.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dokumen ini sudah disetujui.'),
          backgroundColor: Colors.green));
      return;
    }
    final newImage = await ImageHelper.takePhoto(context);
    if (newImage != null) {
      if (!mounted) return;
      setState(() => _imageFile = newImage);
      widget.onImageChanged(_imageFile);
    }
  }

  void _showPreview() {
    if (_imageFile != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => _ImagePreviewScreen(imageFile: _imageFile!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade400;
    if (widget.isApproved) borderColor = Colors.green;

    return Column(children: [
      Text(widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      if (isRejected)
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Revisi: ${widget.rejectionReason}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center)),
      if (widget.isApproved)
        const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('Disetujui',
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _imageFile == null ? _takePicture : _showPreview,
        child: Container(
          height: 150,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5)),
          child: _imageFile == null
              ? Center(
                  child:
                      Icon(widget.icon, size: 50, color: Colors.grey.shade600))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                        child: Image.file(_imageFile!, fit: BoxFit.cover)),
                    Container(color: Colors.black.withOpacity(0.20)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 32),
                    )
                  ],
                ),
        ),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
          icon: Icon(_imageFile == null
              ? Icons.camera_alt_outlined
              : Icons.replay_outlined),
          label: Text(_imageFile == null ? 'Ambil Foto' : 'Ambil Ulang'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Theme.of(context).primaryColor)),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 24)),
          onPressed: _takePicture),
    ]);
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final File imageFile;
  const _ImagePreviewScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: false,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(imageFile),
        ),
      ),
    );
  }
}

class _ApprovedDocumentPlaceholder extends StatelessWidget {
  final String title;
  const _ApprovedDocumentPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title (Sudah Disetujui)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
