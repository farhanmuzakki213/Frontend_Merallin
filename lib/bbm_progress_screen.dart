import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bbm_waiting_verification.dart';
import 'models/bbm_model.dart';
import 'providers/auth_provider.dart';
import 'providers/bbm_provider.dart';
import 'utils/image_helper.dart';

class BbmProgressScreen extends StatefulWidget {
  final int bbmId;
  final bool resumeVerification;

  const BbmProgressScreen({super.key, required this.bbmId, this.resumeVerification = false});

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
    'BUKTI AKHIR',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDetailsAndProceed();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _fetchDetailsAndProceed({bool forceShowForm = false}) async {
    if (!mounted) return;
    if (!forceShowForm) setState(() => _isLoading = true);

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

      bool shouldGoToVerification = (widget.resumeVerification || bbm.derivedStatus == BbmStatus.verifikasiGambar) &&
                                     _hasSubmittedDocsForPage(bbm, determinedPage);

      if (shouldGoToVerification && !forceShowForm) {
        await _navigateToVerification(bbm);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  bool _hasSubmittedDocsForPage(BbmKendaraan bbm, int page) {
    switch (page) {
      case 0: // FOTO KM AWAL
        return bbm.startKmPhotoPath != null && bbm.startKmPhotoPath!.isNotEmpty;
      case 2: // BUKTI AKHIR (KM Akhir dan Nota)
        return (bbm.endKmPhotoPath != null && bbm.endKmPhotoPath!.isNotEmpty) &&
            (bbm.notaPengisianPhotoPath != null &&
                bbm.notaPengisianPhotoPath!.isNotEmpty);
      default:
        return false;
    }
  }

  bool _hasPendingRevisions(BbmKendaraan bbm) {
    // Check if any rejected photo has been re-uploaded (path exists) and is now pending approval
    bool startKmPending = bbm.startKmPhotoStatus.isRejected &&
        (bbm.startKmPhotoPath != null && bbm.startKmPhotoPath!.isNotEmpty) &&
        !bbm.startKmPhotoStatus
            .isApproved; // Assuming not approved means pending after re-upload

    bool endKmPending = bbm.endKmPhotoStatus.isRejected &&
        (bbm.endKmPhotoPath != null && bbm.endKmPhotoPath!.isNotEmpty) &&
        !bbm.endKmPhotoStatus.isApproved;

    bool notaPending = bbm.notaPengisianPhotoStatus.isRejected &&
        (bbm.notaPengisianPhotoPath != null &&
            bbm.notaPengisianPhotoPath!.isNotEmpty) &&
        !bbm.notaPengisianPhotoStatus.isApproved;

    return startKmPending || endKmPending || notaPending;
  }

  bool _hasAnyPendingDocs(BbmKendaraan bbm) {
    bool startKmPendingAndSubmitted = bbm.startKmPhotoStatus.isPending &&
        (bbm.startKmPhotoPath != null && bbm.startKmPhotoPath!.isNotEmpty);

    bool endKmPendingAndSubmitted = bbm.endKmPhotoStatus.isPending &&
        (bbm.endKmPhotoPath != null && bbm.endKmPhotoPath!.isNotEmpty);

    bool notaPendingAndSubmitted = bbm.notaPengisianPhotoStatus.isPending &&
        (bbm.notaPengisianPhotoPath != null &&
            bbm.notaPengisianPhotoPath!.isNotEmpty);

    return startKmPendingAndSubmitted ||
        endKmPendingAndSubmitted ||
        notaPendingAndSubmitted;
  }

  int _determineInitialPage(BbmKendaraan bbm) {
    // Prioritas 1: Tangani revisi terlebih dahulu
    if (bbm.startKmPhotoStatus.isRejected) {
      return 0;
    }
    if (bbm.endKmPhotoStatus.isRejected || bbm.notaPengisianPhotoStatus.isRejected) {
      return 2;
    }
    
    // Prioritas 2: Ikuti alur normal secara sekuensial (seperti checklist)
    // Jika KM Awal belum disetujui, HARUS di halaman 0.
    if (!bbm.startKmPhotoStatus.isApproved) {
      return 0;
    }
    
    // Jika KM Awal sudah disetujui dan statusnya 'sedang isi bbm', HARUS di halaman 1.
    if (bbm.progressStatus == BbmProgressStatus.sedangIsiBbm) {
      return 1;
    }
    
    // Jika semua kondisi di atas sudah lewat (KM Awal approved, tidak sedang isi bbm),
    // maka HARUS berada di halaman terakhir untuk mengunggah bukti akhir.
    return 2;
  }

  Future<void> _navigateToVerification(BbmKendaraan bbm) async {
    final authProvider = context.read<AuthProvider>(); // Ambil AuthProvider
    await authProvider
        .setPendingBbmForVerification(bbm.id); // <-- SIMPAN PROGRES DI SINI

    final result = await Navigator.push<BbmVerificationResult>(
      context,
      MaterialPageRoute(
          builder: (_) => BbmWaitingVerificationScreen(
                bbmId: bbm.id,
                initialPage: _currentPage,
              )),
    );

    await authProvider
        .clearPendingBbmForVerification(); // <-- HAPUS PROGRES SETELAH SELESAI

    if (!mounted || result == null) {
      _fetchDetailsAndProceed(forceShowForm: true);
      return;
    }

    if (!result.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Satu atau lebih dokumen ditolak. Silakan unggah ulang.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
      _fetchDetailsAndProceed(forceShowForm: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Verifikasi berhasil!'),
        backgroundColor: Colors.green,
      ));

      final updatedBbm = result.updatedBbm;
      if (updatedBbm == null) {
        _fetchDetailsAndProceed();
        return;
      }

      if (updatedBbm.derivedStatus == BbmStatus.selesai) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Proses pengisian BBM telah selesai!'),
            backgroundColor: Colors.blue));
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _currentBbm = updatedBbm;
        _currentPage = _determineInitialPage(updatedBbm);
        if (_pageController!.hasClients) {
          _pageController?.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleNextPage() async {
    if (_isSendingData || _currentBbm == null) return;
    setState(() => _isSendingData = true);
    final provider = context.read<BbmProvider>();
    final token = context.read<AuthProvider>().token!;

    try {
      BbmKendaraan? newBbmState;
      bool needsVerification = false;

      switch (_currentPage) {
        case 0:
          final photo = _kmStartKey.currentState?.getImage();
          if (photo == null && !_currentBbm!.startKmPhotoStatus.isApproved) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto KM Awal wajib diisi.'),
              backgroundColor: Colors.red,
            ));
            setState(() => _isSendingData = false);
            return;
          }
          if (photo != null) {
            newBbmState =
                await provider.uploadStartKm(token, widget.bbmId, photo);
            needsVerification = true;
          } else {
            newBbmState = _currentBbm;
          }
          break;
        case 1:
          newBbmState = await provider.finishFilling(token, widget.bbmId);
          break;
        case 2:
          final photos = _kmEndKey.currentState?.getImages();
          final kmPhotoFile = photos?['km'];
          final notaPhotoFile = photos?['nota'];

          bool isKmRejected = _currentBbm!.endKmPhotoStatus.isRejected;
          bool isNotaRejected =
              _currentBbm!.notaPengisianPhotoStatus.isRejected;
          bool isInitialUpload = !isKmRejected && !isNotaRejected;

          if (isKmRejected && kmPhotoFile == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto KM Akhir yang ditolak wajib diunggah ulang.'),
              backgroundColor: Colors.red,
            ));
            setState(() => _isSendingData = false);
            return;
          }
          if (isNotaRejected && notaPhotoFile == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto Nota yang ditolak wajib diunggah ulang.'),
              backgroundColor: Colors.red,
            ));
            setState(() => _isSendingData = false);
            return;
          }
          if (isInitialUpload &&
              (kmPhotoFile == null || notaPhotoFile == null)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto KM Akhir dan Foto Nota wajib diisi.'),
              backgroundColor: Colors.red,
            ));
            setState(() => _isSendingData = false);
            return;
          }

          newBbmState = await provider.uploadEndKmAndNota(
              token, widget.bbmId, kmPhotoFile, notaPhotoFile);
          needsVerification = true;
          break;
      }

      if (mounted && newBbmState != null) {
        setState(() => _currentBbm = newBbmState);
        if (needsVerification) {
          await _navigateToVerification(newBbmState);
        } else {
          int nextPage = _determineInitialPage(newBbmState);
          _pageController?.animateToPage(nextPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _isSendingData = false);
    }
  }

  Future<void> _showExitConfirmationDialog() async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content:
            const Text('Progres Anda sudah tersimpan. Yakin ingin keluar?'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
          TextButton(
            child: const Text('Keluar'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFinished = _currentBbm?.derivedStatus == BbmStatus.selesai;
    bool isRevision = _currentBbm != null &&
        (_currentBbm!.startKmPhotoStatus.isRejected ||
            _currentBbm!.endKmPhotoStatus.isRejected ||
            _currentBbm!.notaPengisianPhotoStatus.isRejected);

    return WillPopScope(
      onWillPop: () async {
        _showExitConfirmationDialog();
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
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : Column(
                          children: [
                            _buildCustomAppBar(isRevision: isRevision),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0, vertical: 16.0),
                              child: _buildProgressIndicator(),
                            ),
                            Expanded(
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: (page) =>
                                    setState(() => _currentPage = page),
                                children: [
                                  _PageCardWrapper(
                                      child: _PageKmStartState(
                                          key: _kmStartKey, bbm: _currentBbm!)),
                                  const _PageCardWrapper(
                                      child: _PageInfo(
                                          title: 'Selesai Mengisi',
                                          subtitle:
                                              'Geser tombol di bawah jika Anda sudah selesai mengisi BBM.')),
                                  _PageCardWrapper(
                                      child: _PageKmEnd(
                                          key: _kmEndKey, bbm: _currentBbm!)),
                                ],
                              ),
                            ),
                            if (!isFinished)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child:
                                    _buildBottomButton(isRevision: isRevision),
                              ),
                          ],
                        ),
            ),
            if (_isSendingData)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar({required bool isRevision}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: _isSendingData ? null : _showExitConfirmationDialog,
          ),
          Text(isRevision ? 'KIRIM ULANG REVISI' : _pageTitles[_currentPage],
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _pageTitles.length * 2 - 1,
          (index) {
            if (index.isEven) {
              final dotIndex = index ~/ 2;
              return CircleAvatar(
                radius: 5,
                backgroundColor: dotIndex <= _currentPage
                    ? Colors.black87
                    : Colors.grey.shade400,
              );
            } else {
              final lineIndex = (index - 1) ~/ 2;
              return Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                color: lineIndex < _currentPage
                    ? Colors.black87
                    : Colors.grey.shade400,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBottomButton({required bool isRevision}) {
    String swipeText =
        isRevision ? 'Geser Untuk Kirim Revisi' : 'Geser Untuk Lanjutkan';
    if (!isRevision) {
      if (_currentPage == 1) swipeText = 'Geser Jika Selesai Mengisi';
    }
    return _SwipeButton(
        text: swipeText,
        onConfirm: _handleNextPage,
        isSendingData: _isSendingData);
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
  File? getImage() => _kmPhoto;

  @override
  Widget build(BuildContext context) {
    if (widget.bbm.startKmPhotoStatus.isApproved) {
      return const _ApprovedDocumentPlaceholder(
          title: 'Foto Seluruh Dashboard KM Awal');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Lengkapi Data Awal',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),
        _PhotoSection(
          title: 'Foto Seluruh Dashboard KM Awal',
          icon: Icons.speed,
          onImageChanged: (file) => setState(() => _kmPhoto = file),
          isApproved: widget.bbm.startKmPhotoStatus.isApproved,
          rejectionReason: widget.bbm.startKmPhotoStatus.rejectionReason,
        )
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
  Map<String, File?> getImages() => {'km': _kmPhoto, 'nota': _notaPhoto};

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

// Widget placeholder untuk dokumen yang sudah disetujui
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
