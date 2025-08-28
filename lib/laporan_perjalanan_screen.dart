// lib/laporan_perjalanan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/waiting_verification_screen.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/trip_service.dart' show ApiException;
import '../utils/image_helper.dart';

class LaporanDriverScreen extends StatefulWidget {
  final int tripId;
  const LaporanDriverScreen({super.key, required this.tripId});

  @override
  State<LaporanDriverScreen> createState() => _LaporanDriverScreenState();
}

class _LaporanDriverScreenState extends State<LaporanDriverScreen> {
  PageController? _pageController;
  int _currentPage = 0;
  Trip? _currentTrip;
  bool _isLoading = true;
  String? _error;

  final GlobalKey<_StartTripPageState> _startTripKey = GlobalKey();
  final GlobalKey<_SuratJalanPageState> _suratJalanKey = GlobalKey();
  final GlobalKey<_DokumenTambahanPageState> _dokumenTambahanKey = GlobalKey();
  final GlobalKey<_BuktiAkhirPageState> _buktiAkhirKey = GlobalKey();
  
  bool _isSendingData = false;
  bool _hasCheckedForVerification = false;

  final List<String> _titles = ['MULAI PERJALANAN', 'MENUJU TITIK MUAT', 'PROSES MUAT', 'SURAT JALAN AWAL', 'DOKUMEN TAMBAHAN', 'MENUJU TITIK BONGKAR', 'PROSES BONGKAR', 'BUKTI AKHIR & SELESAI'];

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
  }

  Future<void> _fetchTripDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasCheckedForVerification = false; 
    });

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();
      final trip = await tripProvider.getTripDetails(authProvider.token!, widget.tripId);

      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _isLoading = false;
          _error = "Gagal memuat data trip atau data kosong.";
        });
        return;
      }
      
      int determinedPage = _determineInitialPage(trip);
      
      if (_pageController == null) {
        _pageController = PageController(initialPage: determinedPage);
      } else if (_pageController!.hasClients && _pageController!.page?.round() != determinedPage) {
        _pageController!.jumpToPage(determinedPage);
      }
      
      setState(() {
        _currentTrip = trip;
        _currentPage = determinedPage;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error di _fetchTripDetails: ${e.toString()}");
      if (mounted) {
        setState(() { 
          _error = "Terjadi kesalahan saat memuat data: \n${e.toString()}"; 
          _isLoading = false; 
        });
      }
    }
  }

  void _handleVerificationCheck() {
    if (_isLoading || !mounted || _currentTrip == null || _hasCheckedForVerification) {
      return;
    }

    setState(() {
      _hasCheckedForVerification = true;
    });

    if (_currentTrip!.derivedStatus == TripDerivedStatus.verifikasiGambar) {
      final authProvider = context.read<AuthProvider>();
      authProvider.setPendingTripForVerification(_currentTrip!.id);

      Navigator.push<VerificationResult>(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingVerificationScreen(
            tripId: _currentTrip!.id,
            initialPage: _currentPage,
            initialTripState: _currentTrip,
          ),
        ),
      ).then((_) {
        authProvider.clearPendingTripForVerification();
        if (mounted) {
          _fetchTripDetails();
        }
      });
    }
  }
  
  void _navigateToNextPageAfterApproval(Trip updatedTrip) {
    if (_currentPage == 7 && updatedTrip.derivedStatus == TripDerivedStatus.selesai) {
      Navigator.pop(context, true);
    } else if (_currentPage < _titles.length - 1) {
      int nextPage = _currentPage + 1;
      _pageController?.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  int _determineInitialPage(Trip trip) {
    if (trip.derivedStatus == TripDerivedStatus.revisiGambar) {
      return trip.firstRejectedDocumentInfo?.pageIndex ?? 0;
    }
    
    if (trip.derivedStatus == TripDerivedStatus.verifikasiGambar) {
      if (trip.startKmPhotoStatus.status?.toLowerCase() == 'pending') return 0;
      if ((trip.muatPhotoStatus.status?.toLowerCase() == 'pending' || trip.deliveryLetterInitialStatus.status?.toLowerCase() == 'pending')) return 3;
      if ((trip.deliveryOrderStatus.status?.toLowerCase() == 'pending' || trip.segelPhotoStatus.status?.toLowerCase() == 'pending' || trip.timbanganKendaraanPhotoStatus.status?.toLowerCase() == 'pending')) return 4;
      if ((trip.endKmPhotoStatus.status?.toLowerCase() == 'pending' || trip.bongkarPhotoStatus.status?.toLowerCase() == 'pending' || trip.deliveryLetterFinalStatus.status?.toLowerCase() == 'pending')) return 7;
    }

    if (trip.startKmPhotoPath == null) return 0;
    if (trip.startKmPhotoStatus.status?.toLowerCase() != 'approved') return 0;
    if (trip.statusLokasi == 'menuju lokasi muat') return 1;
    if (trip.statusLokasi == 'di lokasi muat') return 2;
    if (trip.muatPhotoPath == null) return 3;
    if (trip.muatPhotoStatus.status?.toLowerCase() != 'approved' || trip.deliveryLetterInitialStatus.status?.toLowerCase() != 'approved') return 3;
    if (trip.deliveryOrderPath == null) return 4;
    if (trip.deliveryOrderStatus.status?.toLowerCase() != 'approved' || trip.segelPhotoStatus.status?.toLowerCase() != 'approved' || trip.timbanganKendaraanPhotoStatus.status?.toLowerCase() != 'approved') return 4;
    if (trip.statusLokasi == 'menuju lokasi bongkar') return 5;
    if (trip.statusLokasi == 'di lokasi bongkar') return 6;
    if (trip.endKmPhotoPath == null) return 7;
    if (trip.endKmPhotoStatus.status?.toLowerCase() != 'approved' || trip.bongkarPhotoStatus.status?.toLowerCase() != 'approved' || trip.deliveryLetterFinalStatus.status?.toLowerCase() != 'approved') return 7;
    
    return 7;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _handleNextPage() async {
    if (_isSendingData || _currentTrip == null) return;
    setState(() => _isSendingData = true);
    try {
      Trip? submittedTrip;
      final bool wasRevision = _currentTrip!.derivedStatus == TripDerivedStatus.revisiGambar;

      switch (_currentPage) {
        case 0: submittedTrip = await _startTripKey.currentState?.validateAndSubmit(); break;
        case 3: submittedTrip = await _suratJalanKey.currentState?.validateAndSubmit(); break;
        case 4: submittedTrip = await _dokumenTambahanKey.currentState?.validateAndSubmit(); break;
        case 7: submittedTrip = await _buktiAkhirKey.currentState?.validateAndSubmit(); break;
        case 1: submittedTrip = await _callSimpleAPI(() => context.read<TripProvider>().updateToLoadingPoint(token: context.read<AuthProvider>().token!, tripId: _currentTrip!.id)); break;
        case 2: submittedTrip = await _callSimpleAPI(() => context.read<TripProvider>().finishLoading(token: context.read<AuthProvider>().token!, tripId: _currentTrip!.id)); break;
        case 5: submittedTrip = await _callSimpleAPI(() => context.read<TripProvider>().updateToUnloadingPoint(token: context.read<AuthProvider>().token!, tripId: _currentTrip!.id)); break;
        case 6: submittedTrip = await _callSimpleAPI(() => context.read<TripProvider>().finishUnloading(token: context.read<AuthProvider>().token!, tripId: _currentTrip!.id)); break;
      }

      if (!mounted || submittedTrip == null) {
        setState(() => _isSendingData = false);
        return;
      }
      
      setState(() => _currentTrip = submittedTrip);
      
      bool needsVerification = [0, 3, 4, 7].contains(_currentPage);

      if (needsVerification) {
        final authProvider = context.read<AuthProvider>();
        authProvider.setPendingTripForVerification(_currentTrip!.id);

        final result = await Navigator.push<VerificationResult>(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingVerificationScreen(
              tripId: _currentTrip!.id,
              initialPage: _currentPage,
              initialTripState: submittedTrip,
              isRevisionResubmission: wasRevision,
            ),
          ),
        );
        authProvider.clearPendingTripForVerification();

        if (!mounted || result == null) {
          _fetchTripDetails();
          return;
        }

        setState(() => _currentTrip = result.updatedTrip);

        if (result.status == TripStatus.approved) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifikasi berhasil!'), backgroundColor: Colors.green));
          
          // Re-determine page after approval to jump to the correct next step
          int nextPage = _determineInitialPage(result.updatedTrip);
          _pageController?.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);

        } else { // Rejected
          _pageController?.jumpToPage(result.targetPage);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verifikasi ditolak: ${result.rejectionReason ?? "Silakan periksa kembali dokumen Anda."}'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
        }
      } else { // No verification needed, e.g., for simple status updates
        int nextPage = _determineInitialPage(submittedTrip);
        if (nextPage > _currentPage) {
          _pageController?.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      }
      
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
        if (mounted) {
            setState(() => _isSendingData = false);
        }
    }
  }

  Future<Trip?> _callSimpleAPI(Future<Trip?> Function() apiCall) async {
    try {
      final updatedTrip = await apiCall();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status berhasil diperbarui!'), backgroundColor: Colors.green));
      return updatedTrip;
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      return null;
    }
  }

  Future<void> _showExitConfirmationDialog() async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Progres Anda sudah tersimpan. Yakin ingin keluar?'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(context).pop()),
          TextButton(child: const Text('Keluar'), onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(true); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVerificationCheck();
    });

    return WillPopScope(
      onWillPop: () async { _showExitConfirmationDialog(); return false; },
      child: Scaffold(
        body: Stack(
          children: [
            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _buildPageView(),
            ),
            if (_isSendingData) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPageView() {
    if (_pageController == null || !_pageController!.hasClients || _currentTrip == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final isRevision = _currentTrip!.derivedStatus == TripDerivedStatus.revisiGambar;
    return Column(
      children: [
        _buildCustomAppBar(isRevision: isRevision),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0), child: _buildProgressIndicator()),
        Expanded(
          child: PageView.builder(
            controller: _pageController!,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _PageCardWrapper(child: _getPageSpecificContent(index)),
            itemCount: _titles.length,
          ),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 20.0), child: _buildBottomButton(isRevision: isRevision)),
      ],
    );
  }

  Widget _buildCustomAppBar({required bool isRevision}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.black54), onPressed: _isSendingData ? null : () => _showExitConfirmationDialog()),
          Text(isRevision ? 'KIRIM ULANG REVISI' : _titles[_currentPage], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(_titles.length, (index) => Expanded(
        child: Row(children: [
          CircleAvatar(radius: 5, backgroundColor: index <= _currentPage ? Colors.black87 : Colors.grey.shade400),
          if (index < _titles.length - 1) Expanded(child: Container(height: 2, color: index < _currentPage ? Colors.black87 : Colors.grey.shade400)),
        ]),
      )),
    );
  }

  Widget _getPageSpecificContent(int index) {
    if (_currentTrip == null) return const SizedBox.shrink();
    switch (index) {
      case 0: return _StartTripPage(key: _startTripKey, trip: _currentTrip!);
      case 1: return _InfoDisplayPage(trip: _currentTrip!, isUnloading: false, title: 'Menuju Lokasi Muat');
      case 2: return _InfoDisplayPage(trip: _currentTrip!, isUnloading: false, title: 'Proses Muat Barang', keterangan: 'Muat semua barang sesuai surat jalan.');
      case 3: return _SuratJalanPage(key: _suratJalanKey, trip: _currentTrip!);
      case 4: return _DokumenTambahanPage(key: _dokumenTambahanKey, trip: _currentTrip!);
      case 5: return _InfoDisplayPage(trip: _currentTrip!, isUnloading: true, title: 'Menuju Lokasi Bongkar');
      case 6: return _InfoDisplayPage(trip: _currentTrip!, isUnloading: true, title: 'Proses Bongkar Barang', keterangan: 'Bongkar semua barang dan pastikan surat jalan ditandatangani.');
      case 7: return _BuktiAkhirPage(key: _buktiAkhirKey, trip: _currentTrip!);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton({required bool isRevision}) {
    String swipeText = isRevision ? 'Geser Untuk Kirim Revisi' : 'Geser Untuk Konfirmasi';
    if (!isRevision) {
      switch (_currentPage) {
        case 0: swipeText = 'Geser Untuk Mulai Perjalanan'; break;
        case 1: swipeText = 'Geser Jika Sudah Sampai'; break;
        case 2: swipeText = 'Geser Jika Selesai Muat'; break;
        case 3: case 4: swipeText = 'Geser Untuk Lanjutkan'; break;
        case 5: swipeText = 'Geser Jika Sudah Sampai'; break;
        case 6: swipeText = 'Geser Jika Selesai Bongkar'; break;
        case 7: swipeText = 'Geser Untuk Selesaikan Perjalanan'; break;
      }
    }
    return _SwipeButton(text: swipeText, onConfirm: _handleNextPage, isSendingData: _isSendingData);
  }
}

class _StartTripPage extends StatefulWidget {
  final Trip trip;
  const _StartTripPage({super.key, required this.trip});
  @override
  State<_StartTripPage> createState() => _StartTripPageState();
}

class _StartTripPageState extends State<_StartTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _startKmController = TextEditingController();
  File? _kmAwalImageFile;

  @override
  void initState() {
    super.initState();
    _licensePlateController.text = widget.trip.licensePlate ?? '';
    _startKmController.text = widget.trip.startKm?.toString() ?? '';
  }

  Future<Trip?> validateAndSubmit() async {
    final isRevision = widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      if (!(_formKey.currentState?.validate() ?? false) || _kmAwalImageFile == null) {
        if (_kmAwalImageFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto KM Awal tidak boleh kosong'), backgroundColor: Colors.red),
          );
        }
        return null;
      }
    }
    
    if (isRevision && widget.trip.startKmPhotoStatus.isRejected && _kmAwalImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan unggah ulang foto KM Awal yang ditolak.'), backgroundColor: Colors.orange),
        );
        return null;
    }

    return provider.updateStartTrip(
      token: token,
      tripId: widget.trip.id,
      licensePlate: _licensePlateController.text,
      startKm: _startKmController.text,
      startKmPhoto: _kmAwalImageFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lengkapi Data Awal Perjalanan', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 24),
          TextFormField(controller: _licensePlateController, enabled: !(widget.trip.startKmPhotoStatus.isApproved), decoration: InputDecoration(labelText: 'Nomor Plat Kendaraan', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.directions_car_outlined)), validator: (v) => (v == null || v.isEmpty) ? 'Nomor plat tidak boleh kosong' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _startKmController, enabled: !(widget.trip.startKmPhotoStatus.isApproved), decoration: InputDecoration(labelText: 'KM Awal Kendaraan', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.speed_outlined)), keyboardType: TextInputType.number, validator: (v) { if (v == null || v.isEmpty) return 'KM Awal tidak boleh kosong'; if (int.tryParse(v) == null) return 'KM Awal harus berupa angka'; return null; }),
          const SizedBox(height: 24),
          _PhotoSection(title: 'Foto KM Awal', icon: Icons.camera_alt_outlined, onImageChanged: (file) => setState(() => _kmAwalImageFile = file), rejectionReason: widget.trip.startKmPhotoStatus.rejectionReason, isApproved: widget.trip.startKmPhotoStatus.isApproved),
        ],
      ),
    );
  }
}

class _SuratJalanPage extends StatefulWidget {
  final Trip trip;
  const _SuratJalanPage({super.key, required this.trip});
  @override
  State<_SuratJalanPage> createState() => _SuratJalanPageState();
}

class _SuratJalanPageState extends State<_SuratJalanPage> {
  List<File> _suratJalanImages = [];
  File? _muatBarangImage;

  Future<Trip?> validateAndSubmit() async {
    final isRevision = widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      if (_suratJalanImages.isEmpty || _muatBarangImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua foto wajib diisi.'), backgroundColor: Colors.red));
        return null;
      }
    }

    if (isRevision) {
      bool needsMuatPhoto = widget.trip.muatPhotoStatus.isRejected && _muatBarangImage == null;
      bool needsSuratJalan = widget.trip.deliveryLetterInitialStatus.isRejected && _suratJalanImages.isEmpty;
      if (needsMuatPhoto || needsSuratJalan) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan unggah ulang foto yang ditolak.'), backgroundColor: Colors.orange));
         return null;
      }
    }

    return provider.updateAfterLoading(
      token: token,
      tripId: widget.trip.id,
      deliveryLetters: _suratJalanImages.isNotEmpty ? _suratJalanImages : null,
      muatPhoto: _muatBarangImage,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Foto Bukti Muat', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 24),
        _MultiPhotoSection(title: 'Foto Surat Jalan Awal (Bisa lebih dari 1)', icon: Icons.document_scanner_outlined, onImagesChanged: (files) => setState(() => _suratJalanImages = files), rejectionReason: widget.trip.deliveryLetterInitialStatus.rejectionReason, isApproved: widget.trip.deliveryLetterInitialStatus.isApproved),
        const SizedBox(height: 24),
        _PhotoSection(title: 'Foto Saat Memuat Barang', icon: Icons.inventory_2_outlined, onImageChanged: (file) => setState(() => _muatBarangImage = file), rejectionReason: widget.trip.muatPhotoStatus.rejectionReason, isApproved: widget.trip.muatPhotoStatus.isApproved),
      ],
    );
  }
}

class _DokumenTambahanPage extends StatefulWidget {
  final Trip trip;
  const _DokumenTambahanPage({super.key, required this.trip});
  @override
  State<_DokumenTambahanPage> createState() => _DokumenTambahanPageState();
}

class _DokumenTambahanPageState extends State<_DokumenTambahanPage> {
  File? _deliveryOrderImage;
  File? _segelImage;
  File? _timbanganImage;

  Future<Trip?> validateAndSubmit() async {
    final isRevision = widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      if (_deliveryOrderImage == null || _segelImage == null || _timbanganImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua foto wajib diisi.'), backgroundColor: Colors.red));
        return null;
      }
    }

    if (isRevision) {
      bool needsDo = widget.trip.deliveryOrderStatus.isRejected && _deliveryOrderImage == null;
      bool needsSegel = widget.trip.segelPhotoStatus.isRejected && _segelImage == null;
      bool needsTimbangan = widget.trip.timbanganKendaraanPhotoStatus.isRejected && _timbanganImage == null;
      if (needsDo || needsSegel || needsTimbangan) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan unggah ulang foto yang ditolak.'), backgroundColor: Colors.orange));
        return null;
      }
    }

    return provider.uploadTripDocuments(
      token: token,
      tripId: widget.trip.id,
      deliveryOrder: _deliveryOrderImage,
      segelPhoto: _segelImage,
      timbanganPhoto: _timbanganImage,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Dokumen Tambahan', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 24),
        _PhotoSection(title: 'Foto Delivery Order (DO)', icon: Icons.receipt_long_outlined, onImageChanged: (file) => setState(() => _deliveryOrderImage = file), rejectionReason: widget.trip.deliveryOrderStatus.rejectionReason, isApproved: widget.trip.deliveryOrderStatus.isApproved),
        const SizedBox(height: 24),
        _PhotoSection(title: 'Foto Segel', icon: Icons.shield_outlined, onImageChanged: (file) => setState(() => _segelImage = file), rejectionReason: widget.trip.segelPhotoStatus.rejectionReason, isApproved: widget.trip.segelPhotoStatus.isApproved),
        const SizedBox(height: 24),
        _PhotoSection(title: 'Foto Timbangan Kendaraan', icon: Icons.scale_outlined, onImageChanged: (file) => setState(() => _timbanganImage = file), rejectionReason: widget.trip.timbanganKendaraanPhotoStatus.rejectionReason, isApproved: widget.trip.timbanganKendaraanPhotoStatus.isApproved),
      ],
    );
  }
}

class _BuktiAkhirPage extends StatefulWidget {
  final Trip trip;
  const _BuktiAkhirPage({super.key, required this.trip});
  @override
  State<_BuktiAkhirPage> createState() => _BuktiAkhirPageState();
}

class _BuktiAkhirPageState extends State<_BuktiAkhirPage> {
  final _formKey = GlobalKey<FormState>();
  final _endKmController = TextEditingController();
  List<File> _bongkarBarangImages = [];
  List<File> _suratJalanAkhirImages = [];
  File? _kmAkhirImage;

  @override
  void initState() {
    super.initState();
    _endKmController.text = widget.trip.endKm?.toString() ?? '';
  }

  Future<Trip?> validateAndSubmit() async {
    final isRevision = widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      final isFormValid = _formKey.currentState?.validate() ?? false;
      if (_kmAkhirImage == null || _bongkarBarangImages.isEmpty || _suratJalanAkhirImages.isEmpty || !isFormValid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field dan foto wajib diisi.'), backgroundColor: Colors.red));
        return null;
      }
    }

    if (isRevision) {
      bool needsKmAkhir = widget.trip.endKmPhotoStatus.isRejected && _kmAkhirImage == null;
      bool needsBongkar = widget.trip.bongkarPhotoStatus.isRejected && _bongkarBarangImages.isEmpty;
      bool needsSuratJalan = widget.trip.deliveryLetterFinalStatus.isRejected && _suratJalanAkhirImages.isEmpty;
      if (needsKmAkhir || needsBongkar || needsSuratJalan) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan unggah ulang foto yang ditolak.'), backgroundColor: Colors.orange));
        return null;
      }
    }

    return provider.updateFinishTrip(
      token: token,
      tripId: widget.trip.id,
      endKm: _endKmController.text,
      endKmPhoto: _kmAkhirImage,
      bongkarPhoto: _bongkarBarangImages.isNotEmpty ? _bongkarBarangImages : null,
      deliveryLetters: _suratJalanAkhirImages.isNotEmpty ? _suratJalanAkhirImages : null,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lengkapi Data Akhir Perjalanan', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 24),
          TextFormField(controller: _endKmController, decoration: InputDecoration(labelText: 'KM Akhir Kendaraan', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.speed_outlined)), keyboardType: TextInputType.number, validator: (v) { if (v == null || v.isEmpty) return 'KM Akhir tidak boleh kosong'; final endKm = int.tryParse(v); if (endKm == null) return 'KM Akhir harus berupa angka'; if (widget.trip.startKm != null && int.tryParse(v)! <= widget.trip.startKm!) return 'KM Akhir harus > KM Awal (${widget.trip.startKm})'; return null; }),
          const SizedBox(height: 24),
          _PhotoSection(title: 'Foto KM Akhir', icon: Icons.camera_alt_outlined, onImageChanged: (file) => setState(() => _kmAkhirImage = file), rejectionReason: widget.trip.endKmPhotoStatus.rejectionReason, isApproved: widget.trip.endKmPhotoStatus.isApproved),
          const SizedBox(height: 24),
          _MultiPhotoSection(title: 'Foto Bongkar Barang (Bisa lebih dari 1)', icon: Icons.inventory_outlined, onImagesChanged: (files) => setState(() => _bongkarBarangImages = files), rejectionReason: widget.trip.bongkarPhotoStatus.rejectionReason, isApproved: widget.trip.bongkarPhotoStatus.isApproved),
          const SizedBox(height: 24),
          _MultiPhotoSection(title: 'Foto Surat Jalan Akhir (Bisa lebih dari 1)', icon: Icons.document_scanner_outlined, onImagesChanged: (files) => setState(() => _suratJalanAkhirImages = files), rejectionReason: widget.trip.deliveryLetterFinalStatus.rejectionReason, isApproved: widget.trip.deliveryLetterFinalStatus.isApproved),
        ],
      ),
    );
  }
}

class _InfoDisplayPage extends StatelessWidget {
  final Trip trip; final bool isUnloading; final String title; final String? keterangan;
  const _InfoDisplayPage({required this.trip, required this.isUnloading, required this.title, this.keterangan});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 20),
      _buildInfoRow('Alamat', isUnloading ? trip.destination : trip.origin),
      _buildInfoRow('Proyek', trip.projectName),
      if (keterangan != null) _buildInfoRow('Keterangan', keterangan!),
    ]);
  }
  Widget _buildInfoRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54, fontSize: 16)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16))]));
}

class _PageCardWrapper extends StatelessWidget {
  final Widget child; const _PageCardWrapper({required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Card(elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20.0), child: child)));
}

class _SwipeButton extends StatefulWidget {
  final String text; final VoidCallback onConfirm; final bool isSendingData;
  const _SwipeButton({required this.text, required this.onConfirm, required this.isSendingData});
  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  double _swipePosition = 0.0;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350, height: 60,
      decoration: BoxDecoration(color: const Color(0xFFFF7043), borderRadius: BorderRadius.circular(30)),
      child: GestureDetector(
        onHorizontalDragUpdate: widget.isSendingData ? null : (details) => setState(() => _swipePosition = (_swipePosition + details.delta.dx).clamp(0, 280)),
        onHorizontalDragEnd: widget.isSendingData ? null : (details) { if (_swipePosition > 280 * 0.75) widget.onConfirm(); setState(() => _swipePosition = 0); },
        child: Stack(alignment: Alignment.center, children: [
          Text(widget.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          AnimatedPositioned(duration: const Duration(milliseconds: 50), left: _swipePosition, child: Container(width: 70, height: 60, decoration: BoxDecoration(color: const Color(0xFF00838F), borderRadius: BorderRadius.circular(30)), child: const Icon(Icons.local_shipping, color: Colors.white, size: 30))),
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

  const _PhotoSection({super.key, required this.title, required this.icon, required this.onImageChanged, this.rejectionReason, this.isApproved = false});
  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  File? _imageFile;
  bool get isRejected => widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty;

  Future<void> _takePicture() async {
    if (widget.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen ini sudah disetujui.'), backgroundColor: Colors.green));
      return;
    }
    final newImage = await ImageHelper.takeGeotaggedPhoto(context);
    if (newImage != null) { 
      if (!mounted) return;
      setState(() => _imageFile = newImage); 
      widget.onImageChanged(_imageFile); 
    }
  }

  void _showPreview() { if (_imageFile != null && mounted) Navigator.of(context).push(MaterialPageRoute(builder: (context) => _ImagePreviewScreen(imageFile: _imageFile!))); }
  
  @override
  Widget build(BuildContext context) {
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade400;
    if (widget.isApproved) borderColor = Colors.green;

    return Column(children: [
      Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
      if (isRejected) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Revisi: ${widget.rejectionReason}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      if (widget.isApproved) const Padding(padding: EdgeInsets.only(top: 8.0), child: Text('Disetujui', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      const SizedBox(height: 12),
      GestureDetector(onTap: _imageFile == null ? _takePicture : _showPreview, child: Container(height: 150, width: double.infinity, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)), child: _imageFile == null ? Center(child: Icon(widget.icon, size: 50, color: Colors.grey.shade600)) : Stack(alignment: Alignment.center, children: [Positioned.fill(child: Image.file(_imageFile!, fit: BoxFit.cover)), Container(color: Colors.black.withOpacity(0.20)), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle), child: const Icon(Icons.zoom_in, color: Colors.white, size: 32))]))),
      const SizedBox(height: 12),
      ElevatedButton.icon(icon: Icon(_imageFile == null ? Icons.camera_alt_outlined : Icons.replay_outlined), label: Text(_imageFile == null ? 'Ambil Foto' : 'Ambil Ulang'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Theme.of(context).primaryColor, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).primaryColor)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24)), onPressed: _takePicture),
    ]);
  }
}

class _MultiPhotoSection extends StatefulWidget {
  final String title;
  final String? rejectionReason;
  final IconData icon;
  final ValueChanged<List<File>> onImagesChanged;
  final bool isApproved;

  const _MultiPhotoSection({super.key, required this.title, required this.icon, required this.onImagesChanged, this.rejectionReason, this.isApproved = false});
  @override
  State<_MultiPhotoSection> createState() => _MultiPhotoSectionState();
}

class _MultiPhotoSectionState extends State<_MultiPhotoSection> {
  final List<File> _imageFiles = [];
  bool get isRejected => widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty;

  Future<void> _takePicture() async { 
    if (widget.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen ini sudah disetujui.'), backgroundColor: Colors.green));
      return;
    }
    final File? newImage = await ImageHelper.takePhoto(context); 
    if (newImage != null) { 
      if (!mounted) return;
      setState(() => _imageFiles.add(newImage)); 
      widget.onImagesChanged(_imageFiles); 
    } 
  }
  void _removeImage(int index) { setState(() => _imageFiles.removeAt(index)); widget.onImagesChanged(_imageFiles); }
  void _showPreview(File imageFile) { if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (context) => _ImagePreviewScreen(imageFile: imageFile))); }
  @override
  Widget build(BuildContext context) {
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade300;
    if (widget.isApproved) borderColor = Colors.green;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
      if (isRejected) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Revisi: ${widget.rejectionReason}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      if (widget.isApproved) const Padding(padding: EdgeInsets.only(top: 8.0), child: Text('Disetujui', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(8), width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1)), child: _imageFiles.isEmpty ? _buildImagePickerPlaceholder() : _buildImageGrid()),
      const SizedBox(height: 12),
      Center(child: ElevatedButton.icon(icon: const Icon(Icons.camera_alt_outlined, size: 20), label: const Text('Tambah Foto'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Theme.of(context).primaryColor, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).primaryColor)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24)), onPressed: _takePicture)),
    ]);
  }
  Widget _buildImageGrid() => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: _imageFiles.length, itemBuilder: (context, index) => GestureDetector(onTap: () => _showPreview(_imageFiles[index]), child: Stack(clipBehavior: Clip.none, children: [Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), clipBehavior: Clip.antiAlias, child: Image.file(_imageFiles[index], fit: BoxFit.cover, width: double.infinity, height: double.infinity)), Positioned(top: -10, right: -10, child: GestureDetector(onTap: () => _removeImage(index), child: const CircleAvatar(radius: 14, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 18))))])));
  Widget _buildImagePickerPlaceholder() => GestureDetector(onTap: _takePicture, child: SizedBox(height: 100, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(widget.icon, size: 40, color: Colors.grey.shade600), const SizedBox(height: 8), const Text('Ketuk untuk mengambil foto', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]))));
}

class _ImagePreviewScreen extends StatelessWidget {
  final File imageFile; const _ImagePreviewScreen({super.key, required this.imageFile});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop())),
      body: Center(child: InteractiveViewer(panEnabled: false, boundaryMargin: const EdgeInsets.all(20), minScale: 0.5, maxScale: 4, child: Image.file(imageFile))),
    );
  }
}

extension PhotoStatusCheck on PhotoVerificationStatus {
  bool get isRejected => (status?.toLowerCase() == 'rejected' || (rejectionReason != null && rejectionReason!.isNotEmpty));
  bool get isApproved => status?.toLowerCase() == 'approved';
}