// lib/screens/vehicle_location_progress_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/models/trip_model.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/bbm_provider.dart';
import 'package:frontend_merallin/providers/vehicle_location_provider.dart';
import 'package:frontend_merallin/models/vehicle_location_model.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:frontend_merallin/widgets/in_app_widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/trip_service.dart' show ApiException;
import '../utils/image_helper.dart';
import 'bbm_progress_screen.dart';
import 'models/bbm_model.dart';
import 'vehicle_location_waiting_screen.dart';

// Helper function
bool _isStringNullOrEmpty(String? str) {
  return str == null || str.isEmpty;
}

class VehicleLocationProgressScreen extends StatefulWidget {
  final int locationId;
  final bool resumeVerification;

  const VehicleLocationProgressScreen({
    super.key,
    required this.locationId,
    this.resumeVerification = false,
  });

  @override
  State<VehicleLocationProgressScreen> createState() =>
      _VehicleLocationProgressScreenState();
}

class _VehicleLocationProgressScreenState
    extends State<VehicleLocationProgressScreen> {
  PageController? _pageController;
  int _currentPage = 0;
  VehicleLocation? _currentLocation;
  bool _isLoading = true;
  String? _error;

  final GlobalKey<_StartLocationPageState> _startLocationKey = GlobalKey();
  final GlobalKey<_EndLocationPageState> _endLocationKey = GlobalKey();

  bool _isSendingData = false;

  final List<String> _titles = [
    'LOKASI AWAL & STANDBY',
    'MENUJU LOKASI TUJUAN',
    'BUKTI AKHIR & SELESAI'
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
      final locationProvider = context.read<VehicleLocationProvider>();
      final authProvider = context.read<AuthProvider>();
      final location = await locationProvider.getDetails(
          authProvider.token!, widget.locationId);

      if (!mounted || location == null) {
        setState(() {
          _isLoading = false;
          _error = "Gagal memuat data.";
        });
        return;
      }

      if (location.isFullyCompleted ||
          location.statusVehicleLocation == 'selesai') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tugas Trip Geser ini sudah selesai.'),
          backgroundColor: Colors.green,
        ));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        return; // Hentikan eksekusi fungsi agar tidak lanjut ke bawah
      }

      int determinedPage = _determineInitialPage(location);

      if (_pageController == null) {
        _pageController = PageController(initialPage: determinedPage);
      } else if (_pageController!.hasClients &&
          _pageController!.page != determinedPage) {
        _pageController!.jumpToPage(determinedPage);
      }

      setState(() {
        _currentLocation = location;
        _currentPage = determinedPage;
      });

      bool shouldGoToVerification = (widget.resumeVerification ||
              location.derivedStatus == TripDerivedStatus.verifikasiGambar) &&
          !location.isFullyCompleted &&
          _hasSubmittedDocsForPage(location, determinedPage);

      if (shouldGoToVerification && !forceShowForm) {
        await _handleVerificationResult(location);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Terjadi kesalahan: ${e.toString()}";
        });
      }
    }
  }

  bool _hasSubmittedDocsForPage(VehicleLocation location, int page) {
    switch (page) {
      case 0:
        return !_isStringNullOrEmpty(location.standbyPhotoPath) ||
            !_isStringNullOrEmpty(location.startKmPhotoPath);
      case 2:
        return !_isStringNullOrEmpty(location.endKmPhotoPath);
      default:
        return false;
    }
  }

  void _handleApiResponse(VehicleLocation updatedLocation) {
    if (updatedLocation.isFullyCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trip Geser telah selesai!'),
          backgroundColor: Colors.blue));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      return;
    }

    final nextPage = _determineInitialPage(updatedLocation);

    setState(() {
      _currentLocation = updatedLocation;
      _currentPage = nextPage;
    });

    if (_pageController!.hasClients) {
      _pageController!.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleVerificationResult(VehicleLocation location,
      {bool isRevisionResubmission = false}) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.setPendingVehicleLocationForVerification(location.id);

    setState(() {
      _isLoading = false;
    });

    final result = await Navigator.push<VehicleLocationVerificationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WaitingVehicleLocationVerificationScreen(
          locationId: location.id,
          initialPage: _currentPage,
          initialLocationState: location,
          isRevisionResubmission: isRevisionResubmission,
        ),
      ),
    );

    await authProvider.clearPendingVehicleLocationForVerification();

    if (!mounted) return;

    if (result == null) {
      _fetchDetailsAndProceed();
      return;
    }

    if (result.status == VehicleLocationStatus.rejected) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Verifikasi ditolak: ${result.rejectionReason ?? "Dokumen ditolak."}'),
          backgroundColor: Colors.red));
      _fetchDetailsAndProceed(forceShowForm: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verifikasi berhasil!'),
          backgroundColor: Colors.green));
    }

    _handleApiResponse(result.updatedLocation);
  }

  int _determineInitialPage(VehicleLocation location) {
    // Jika ada dokumen yang ditolak, langsung ke halaman revisi
    if (location.derivedStatus == TripDerivedStatus.revisiGambar) {
      return location.firstRejectedDocumentInfo?.pageIndex ?? 0;
    }

    // Halaman 0: Belum upload foto awal atau foto awal belum disetujui
    if (_isStringNullOrEmpty(location.standbyPhotoPath) ||
        _isStringNullOrEmpty(location.startKmPhotoPath) ||
        !location.standbyPhotoStatus.isApproved ||
        !location.startKmPhotoStatus.isApproved) {
      return 0;
    }

    // Halaman 1: Foto awal sudah disetujui, sedang menuju lokasi
    if (location.statusLokasi == 'menuju lokasi') {
      return 1;
    }

    // Halaman 2: Sudah sampai di lokasi atau sudah upload KM akhir
    if (location.statusLokasi == 'sampai di lokasi' ||
        !_isStringNullOrEmpty(location.endKmPhotoPath)) {
      return 2;
    }

    // Default kembali ke halaman 0 jika tidak ada kondisi yang cocok
    return 0;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _handleNextPage() async {
    if (_isSendingData || _currentLocation == null) return;
    setState(() => _isSendingData = true);

    try {
      VehicleLocation? submittedLocation;
      final bool wasRevision =
          _currentLocation!.derivedStatus == TripDerivedStatus.revisiGambar;

      switch (_currentPage) {
        case 0:
          submittedLocation =
              await _startLocationKey.currentState?.validateAndSubmit();
          break;
        case 1:
          submittedLocation = await _callSimpleAPI(() => context
              .read<VehicleLocationProvider>()
              .arriveAtLocation(
                  token: context.read<AuthProvider>().token!,
                  locationId: _currentLocation!.id));
          break;
        case 2:
          submittedLocation =
              await _endLocationKey.currentState?.validateAndSubmit();
          break;
      }

      if (!mounted || submittedLocation == null) {
        setState(() => _isSendingData = false);
        return;
      }

      bool needsVerification = [0, 2].contains(_currentPage);

      if (needsVerification) {
        await _handleVerificationResult(submittedLocation,
            isRevisionResubmission: wasRevision);
      } else {
        _handleApiResponse(submittedLocation);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingData = false);
      }
    }
  }

  Future<void> _handleBbmTap() async {
    // Tahap di mana driver sedang diam di lokasi awal (0) atau akhir (2)
    final restrictedPages = [0, 2];

    if (restrictedPages.contains(_currentPage)) {
      // Tampilkan pesan peringatan jika di halaman yang dibatasi
      showInfoSnackBar(context, 'Tidak bisa meminta BBM saat sedang tidak dalam perjalanan.');
      return;
    }

    // Logika ini untuk melanjutkan fungsionalitas normal di halaman yang diizinkan (tahap 1)
    final bbmProvider = context.read<BbmProvider>();
    final authProvider = context.read<AuthProvider>();

    final bool hasOngoing = bbmProvider.bbmRequests
        .any((bbm) => bbm.derivedStatus != BbmStatus.selesai);
    if (hasOngoing) {
      showInfoSnackBar(context,
          'Tidak bisa membuat permintaan baru. Masih ada proses BBM yang sedang berjalan.');
      return;
    }

    if (_currentLocation?.vehicle == null) {
      showErrorSnackBar(context,
          'Data kendaraan tidak ditemukan untuk membuat permintaan BBM.');
      return;
    }

    showInfoSnackBar(context,
        'Membuat permintaan BBM untuk ${_currentLocation!.vehicle!.licensePlate}...');
    final newRequest = await bbmProvider.createBbmRequest(
        context: context,
        token: authProvider.token!,
        vehicleId: _currentLocation!.vehicle!.id);

    if (!context.mounted || newRequest == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BbmProgressScreen(bbmId: newRequest.id),
      ),
    );

    if (context.mounted) {
      await bbmProvider.fetchBbmRequests(
        context: context,
        token: authProvider.token!,
      );
    }
  }

  Future<VehicleLocation?> _callSimpleAPI(
      Future<VehicleLocation?> Function() apiCall) async {
    try {
      final updatedLocation = await apiCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Status berhasil diperbarui!'),
            backgroundColor: Colors.green));
      }
      return updatedLocation;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
      return null;
    }
  }

  void _showCannotExitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anda harus menyelesaikan tugas ini untuk keluar.'),
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
                        end: Alignment.bottomCenter))),
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
                  child: const Center(child: CircularProgressIndicator())),
                  if (!_isLoading && _error == null && _currentLocation != null)
              DraggableSpeedDial(
                currentVehicle: _currentLocation!.vehicle,
                showBbmOption: true,
                onBbmPressed: _handleBbmTap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    if (_currentLocation == null) {
      return const Center(child: Text("Data tidak tersedia."));
    }
    final isRevision =
        _currentLocation!.derivedStatus == TripDerivedStatus.revisiGambar;
    return Column(
      children: [
        const AttendanceNotificationBanner(),
        _buildCustomAppBar(isRevision: isRevision),
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: Center(child: _buildProgressIndicator())),
        Expanded(
          child: PageView.builder(
            controller: _pageController!,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) =>
                _PageCardWrapper(child: _getPageSpecificContent(index)),
            itemCount: _titles.length,
          ),
        ),
        if (_currentLocation?.derivedStatus != TripDerivedStatus.selesai)
          Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _buildBottomButton(isRevision: isRevision)),
      ],
    );
  }

  Widget _buildCustomAppBar({required bool isRevision}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isRevision ? 'KIRIM ULANG REVISI' : _titles[_currentPage],
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          // const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    List<Widget> children = [];
    for (int i = 0; i < _titles.length; i++) {
      final bool isActive = i <= _currentPage;
      // Tambah lingkaran
      children.add(
        CircleAvatar(
          radius: 5,
          backgroundColor: isActive ? Colors.black87 : Colors.grey.shade400,
        ),
      );

      // Tambah garis (kecuali untuk item terakhir)
      if (i < _titles.length - 1) {
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

  Widget _getPageSpecificContent(int index) {
    if (_currentLocation == null) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return _StartLocationPage(
            key: _startLocationKey, location: _currentLocation!);
      case 1:
        return _InfoDisplayPage(
            title: 'Menuju Lokasi Tujuan',
            description:
                'Anda sedang dalam perjalanan.\n\n"${_currentLocation!.keterangan ?? 'Tidak ada keterangan.'}"\n\nTekan tombol di bawah jika Anda sudah sampai di lokasi tujuan.');
      case 2:
        return _EndLocationPage(
            key: _endLocationKey, location: _currentLocation!);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton({required bool isRevision}) {
    String swipeText =
        isRevision ? 'Geser Untuk Kirim Revisi' : 'Geser Untuk Konfirmasi';
    if (!isRevision) {
      switch (_currentPage) {
        case 0:
          swipeText = 'Geser Untuk Memulai';
          break;
        case 1:
          swipeText = 'Geser Jika Sudah Sampai';
          break;
        case 2:
          swipeText = 'Geser Untuk Selesaikan';
          break;
      }
    }
    return _SwipeButton(
        text: swipeText,
        onConfirm: _handleNextPage,
        isSendingData: _isSendingData);
  }
}

class _StartLocationPage extends StatefulWidget {
  final VehicleLocation location;
  const _StartLocationPage({super.key, required this.location});
  @override
  State<_StartLocationPage> createState() => _StartLocationPageState();
}

class _StartLocationPageState extends State<_StartLocationPage> {
  File? _standbyImageFile;
  File? _startKmImageFile;

  Future<VehicleLocation?> validateAndSubmit() async {
    final provider = context.read<VehicleLocationProvider>();
    final token = context.read<AuthProvider>().token!;

    final isRevision =
        widget.location.derivedStatus == TripDerivedStatus.revisiGambar;
    if (!isRevision) {
      if (_standbyImageFile == null || _startKmImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua foto wajib diisi.'),
            backgroundColor: Colors.red));
        return null;
      }
    } else {
      if ((widget.location.standbyPhotoStatus.isRejected &&
              _standbyImageFile == null) &&
          (widget.location.startKmPhotoStatus.isRejected &&
              _startKmImageFile == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return null;
      }
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengambil lokasi GPS...'),
          ],
        ),
      ));

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      return provider.uploadStandbyAndStartKm(
        token: token,
        locationId: widget.location.id,
        standbyPhoto: _standbyImageFile,
        startKmPhoto: _startKmImageFile,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mendapatkan lokasi GPS: ${e.toString()}'),
          backgroundColor: Colors.red));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Bukti Awal',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),

        // --- PERBAIKAN DI SINI ---
        if (!widget.location.standbyPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto Standby Kendaraan',
            icon: Icons.local_parking_outlined,
            onImageChanged: (file) => setState(() => _standbyImageFile = file),
            rejectionReason: widget.location.standbyPhotoStatus.rejectionReason,
            isApproved: widget.location.standbyPhotoStatus.isApproved,
          ),
        if (widget.location.standbyPhotoStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Standby Kendaraan'),

        const SizedBox(height: 24),

        // --- PERBAIKAN DI SINI ---
        if (!widget.location.startKmPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto KM Awal',
            icon: Icons.speed_outlined,
            onImageChanged: (file) => setState(() => _startKmImageFile = file),
            rejectionReason: widget.location.startKmPhotoStatus.rejectionReason,
            isApproved: widget.location.startKmPhotoStatus.isApproved,
          ),
        if (widget.location.startKmPhotoStatus.isApproved)
          const _ApprovedDocumentPlaceholder(title: 'Foto KM Awal'),
      ],
    );
  }
}

class _EndLocationPage extends StatefulWidget {
  final VehicleLocation location;
  const _EndLocationPage({super.key, required this.location});
  @override
  State<_EndLocationPage> createState() => _EndLocationPageState();
}

class _EndLocationPageState extends State<_EndLocationPage> {
  File? _endKmImageFile;

  Future<VehicleLocation?> validateAndSubmit() async {
    final provider = context.read<VehicleLocationProvider>();
    final token = context.read<AuthProvider>().token!;

    final isRevision =
        widget.location.derivedStatus == TripDerivedStatus.revisiGambar;
    if (!isRevision) {
      if (_endKmImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto KM Akhir wajib diisi.'),
            backgroundColor: Colors.red));
        return null;
      }
    } else {
      if (widget.location.endKmPhotoStatus.isRejected &&
          _endKmImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return null;
      }
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengambil lokasi GPS...'),
          ],
        ),
      ));

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      return provider.uploadEndKm(
        token: token,
        locationId: widget.location.id,
        endKmPhoto: _endKmImageFile!,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mendapatkan lokasi GPS: ${e.toString()}'),
          backgroundColor: Colors.red));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Bukti Akhir',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),

        // --- PERBAIKAN DI SINI ---
        if (!widget.location.endKmPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto KM Akhir',
            icon: Icons.speed_outlined,
            onImageChanged: (file) => setState(() => _endKmImageFile = file),
            rejectionReason: widget.location.endKmPhotoStatus.rejectionReason,
            isApproved: widget.location.endKmPhotoStatus.isApproved,
          ),
        if (widget.location.endKmPhotoStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto KM Akhir'),
      ],
    );
  }
}

class _InfoDisplayPage extends StatelessWidget {
  final String title;
  final String description;
  const _InfoDisplayPage({required this.title, required this.description});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 20),
        Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54)),
      ],
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
          child: Padding(padding: const EdgeInsets.all(20.0), child: child)));
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
                  child: const Icon(Icons.alt_route,
                      color: Colors.white, size: 30))),
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
    if (_imageFile != null && mounted)
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => _ImagePreviewScreen(imageFile: _imageFile!)));
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
            padding: const EdgeInsets.only(top: 8.0),
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
                      child: Icon(widget.icon,
                          size: 50, color: Colors.grey.shade600))
                  : Stack(alignment: Alignment.center, children: [
                      Positioned.fill(
                          child: Image.file(_imageFile!, fit: BoxFit.cover)),
                      Container(color: Colors.black.withOpacity(0.20)),
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.zoom_in,
                              color: Colors.white, size: 32))
                    ]))),
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
              onPressed: () => Navigator.of(context).pop())),
      body: Center(
          child: InteractiveViewer(
              panEnabled: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(imageFile))),
    );
  }
}

// --- WIDGET BARU YANG DITAMBAHKAN ---
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

extension PhotoStatusCheck on PhotoVerificationStatus {
  bool get isRejected => (status?.toLowerCase() == 'rejected' ||
      (rejectionReason != null && rejectionReason!.isNotEmpty));
  bool get isApproved => status?.toLowerCase() == 'approved';
  bool get isPending =>
      status?.toLowerCase() == 'pending' ||
      status == null ||
      status!.isEmpty; // untuk trip geser
}
