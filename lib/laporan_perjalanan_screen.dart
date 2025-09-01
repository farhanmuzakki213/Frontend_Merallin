import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/waiting_verification_screen.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../models/vehicle_model.dart';
import '../providers/trip_provider.dart';
import '../services/trip_service.dart' show ApiException;
import '../utils/image_helper.dart';
import 'package:url_launcher/url_launcher.dart';

bool _isStringNullOrEmpty(String? str) {
  return str == null || str.isEmpty;
}

class LaporanDriverScreen extends StatefulWidget {
  final int tripId;
  final bool resumeVerification;

  const LaporanDriverScreen({
    super.key,
    required this.tripId,
    this.resumeVerification = false,
  });

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
  final GlobalKey<_AfterLoadingPageState> _afterLoadingKey = GlobalKey();
  final GlobalKey<_UploadDocumentsPageState> _uploadDocumentsKey = GlobalKey();
  final GlobalKey<_BuktiAkhirPageState> _buktiAkhirKey = GlobalKey();

  bool _isSendingData = false;

  final List<String> _titles = [
    'MULAI PERJALANAN',
    'MENUJU TITIK MUAT',
    'PROSES MUAT',
    'UPLOAD PROSES MUAT',
    'UPLOAD SELESAI MUAT',
    'MENUJU TITIK BONGKAR',
    'PROSES BONGKAR',
    'BUKTI AKHIR & SELESAI'
  ];

  @override
  void initState() {
    super.initState();
    _fetchTripDetailsAndProceed();
  }

  Future<void> _fetchTripDetailsAndProceed({bool forceShowForm = false}) async {
    if (!mounted) return;

    // Hanya tampilkan loading utama jika tidak dipaksa menampilkan form
    if (!forceShowForm) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token!;

      final results = await Future.wait([
        tripProvider.getTripDetails(token, widget.tripId),
        tripProvider.fetchVehicles(token), // Pastikan vehicles juga dimuat
      ]);

      final trip = results[0] as Trip?;

      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _isLoading = false;
          _error = "Gagal memuat data trip.";
        });
        return;
      }

      int determinedPage = _determineInitialPage(trip);

      if (_pageController == null) {
        _pageController = PageController(initialPage: determinedPage);
      } else if (_pageController!.hasClients &&
          _pageController!.page?.round() != determinedPage) {
        // Gunakan jumpToPage di sini karena ini adalah pemulihan state, bukan animasi antar langkah
        _pageController!.jumpToPage(determinedPage);
      }
      setState(() {
        _currentTrip = trip;
        _currentPage = determinedPage;
      });

      bool shouldGoToVerification = (widget.resumeVerification ||
              trip.derivedStatus == TripDerivedStatus.verifikasiGambar) &&
          _hasSubmittedDocsForPage(trip, determinedPage);

      if (shouldGoToVerification && !forceShowForm) {
        // _isLoading tetap true, langsung navigasi ke verifikasi
        await _navigateToVerification(trip);
      } else {
        // Jika tidak perlu verifikasi, baru hentikan loading dan tampilkan form
        setState(() {
          _isLoading = false;
        });
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

  bool _hasSubmittedDocsForPage(Trip trip, int page) {
    switch (page) {
      case 0:
        return !_isStringNullOrEmpty(trip.startKmPhotoPath);
      case 3:
        return !_isStringNullOrEmpty(trip.kmMuatPhotoPath);
      case 4:
        return trip.deliveryLetterPath['initial_letters']?.isNotEmpty ?? false;
      case 7:
        return !_isStringNullOrEmpty(trip.endKmPhotoPath);
      default:
        return false;
    }
  }

  Future<void> _navigateToVerification(Trip trip,
      {bool isRevisionResubmission = false}) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.setPendingTripForVerification(trip.id);

    setState(() {
      _isLoading = false;
    });

    final result = await Navigator.push<VerificationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => WaitingVerificationScreen(
          tripId: trip.id,
          initialPage: _currentPage,
          initialTripState: trip,
          isRevisionResubmission: isRevisionResubmission,
        ),
      ),
    );

    await authProvider.clearPendingTripForVerification();

    if (mounted) {
      if (result == null) {
        _fetchTripDetailsAndProceed();
        return;
      }

      if (result.status == TripStatus.rejected) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Verifikasi ditolak: ${result.rejectionReason ?? "Dokumen ditolak."}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)));
        // Memaksa untuk memuat ulang dan menampilkan form revisi
        _fetchTripDetailsAndProceed(forceShowForm: true);
      } else {
        // Approved
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verifikasi berhasil!'),
            backgroundColor: Colors.green));

        if (result.updatedTrip.isFullyCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Perjalanan telah selesai!'),
              backgroundColor: Colors.blue));
          Navigator.of(context).pop(true);
          return;
        }

        // Setelah approve, muat ulang state untuk maju ke tahap selanjutnya
        setState(() {
          _currentTrip = result.updatedTrip;
          _currentPage = _determineInitialPage(result.updatedTrip);
          if (_pageController!.hasClients) {
            _pageController?.animateToPage(_currentPage,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut);
          }
        });
      }
    }
  }

  int _determineInitialPage(Trip trip) {
    if (trip.derivedStatus == TripDerivedStatus.revisiGambar) {
      return trip.firstRejectedDocumentInfo?.pageIndex ?? 0;
    }

    if (!trip.startKmPhotoStatus.isApproved) {
      return 0;
    }

    bool isAfterLoadingComplete = trip.kmMuatPhotoStatus.isApproved &&
        trip.kedatanganMuatPhotoStatus.isApproved &&
        trip.deliveryOrderStatus.isApproved &&
        trip.muatPhotoStatus.isApproved;

    if (!isAfterLoadingComplete) {
      if (trip.statusLokasi == 'menuju lokasi muat' && trip.statusMuatan == 'kosong') return 1; // Halaman info
      if (trip.statusLokasi == 'di lokasi muat' && trip.statusMuatan == 'proses muat') return 2; // Halaman info
      return 3; // Halaman form upload
    }

    bool isDocumentsComplete = trip.deliveryLetterInitialStatus.isApproved &&
        trip.segelPhotoStatus.isApproved &&
        trip.timbanganKendaraanPhotoStatus.isApproved;

    if (!isDocumentsComplete) {
      return 4; // Halaman form upload
    }

    bool isFinishComplete = trip.kedatanganBongkarPhotoStatus.isApproved &&
        trip.endKmPhotoStatus.isApproved &&
        trip.bongkarPhotoStatus.isApproved &&
        trip.deliveryLetterFinalStatus.isApproved;

    if (!isFinishComplete) {
      if (trip.statusLokasi == 'menuju lokasi bongkar' && trip.statusMuatan == 'termuat')
        return 5; // Halaman info
      if (trip.statusLokasi == 'di lokasi bongkar' && trip.statusMuatan == 'proses bongkar') return 6; // Halaman info
      return 7; // Halaman form upload
    }
    return _currentPage;

    // if (_isStringNullOrEmpty(trip.startKmPhotoPath)) return 0;
    // if (trip.startKmPhotoStatus.status?.toLowerCase() != 'approved') return 0;

    // if (trip.startKmPhotoStatus.status?.toLowerCase() == 'approved' &&
    //     trip.statusLokasi == 'menuju lokasi muat' &&
    //     trip.statusMuatan == 'kosong' &&
    //     trip.muatPhotoStatus.status?.toLowerCase() != 'approved') return 1;

    // if (trip.statusLokasi == 'di lokasi muat' &&
    //     trip.statusMuatan != 'selesai muat' &&
    //     trip.muatPhotoStatus.status?.toLowerCase() != 'approved') return 2;

    // if (_isStringNullOrEmpty(trip.kmMuatPhotoPath) ||
    //         trip.statusLokasi == 'di lokasi muat' &&
    //         trip.statusMuatan == 'selesai muat' &&
    //         trip.startKmPhotoStatus.status?.toLowerCase() == 'approved' &&
    //         trip.muatPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.deliveryOrderStatus.status?.toLowerCase() != 'approved' ||
    //         trip.kmMuatPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.kedatanganMuatPhotoStatus.status?.toLowerCase() != 'approved')
    //   return 3;

    // if (_isStringNullOrEmpty(trip.segelPhotoPath) &&
    //         trip.muatPhotoStatus.status?.toLowerCase() == 'approved' &&
    //         trip.deliveryOrderStatus.status?.toLowerCase() == 'approved' &&
    //         trip.kmMuatPhotoStatus.status?.toLowerCase() == 'approved' &&
    //         trip.kedatanganMuatPhotoStatus.status?.toLowerCase() == 'approved' &&
    //         trip.statusLokasi == 'menuju lokasi bongkar' &&
    //         trip.statusMuatan == 'termuat' &&
    //         trip.deliveryLetterInitialStatus.status?.toLowerCase() != 'approved' ||
    //         trip.segelPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.timbanganKendaraanPhotoStatus.status?.toLowerCase() != 'approved')
    //   return 4;

    // if (trip.deliveryLetterInitialStatus.status?.toLowerCase() == 'approved' &&
    //     trip.segelPhotoStatus.status?.toLowerCase() == 'approved' &&
    //     trip.timbanganKendaraanPhotoStatus.status?.toLowerCase() ==
    //         'approved' &&
    //     trip.statusLokasi == 'menuju lokasi bongkar' &&
    //     trip.statusMuatan == 'termuat' &&
    //     trip.endKmPhotoStatus.status?.toLowerCase() != 'approved') return 5;

    // if (trip.statusLokasi == 'di lokasi bongkar' &&
    //     trip.statusMuatan != 'selesai bongkar' &&
    //     trip.endKmPhotoStatus.status?.toLowerCase() != 'approved') return 6;

    // if (_isStringNullOrEmpty(trip.endKmPhotoPath) &&
    //         trip.statusLokasi == 'di lokasi bongkar' &&
    //         trip.statusMuatan == 'selesai bongkar' &&
    //         trip.endKmPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.kedatanganBongkarPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.bongkarPhotoStatus.status?.toLowerCase() != 'approved' ||
    //         trip.deliveryLetterFinalStatus.status?.toLowerCase() != 'approved')
    //   return 7;
    // if (trip.derivedStatus == TripDerivedStatus.selesai) return 7;

    // return _currentPage;
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
      final bool wasRevision =
          _currentTrip!.derivedStatus == TripDerivedStatus.revisiGambar;

      switch (_currentPage) {
        case 0:
          submittedTrip = await _startTripKey.currentState?.validateAndSubmit();
          break;
        case 1:
          submittedTrip = await _callSimpleAPI(() => context
              .read<TripProvider>()
              .updateToLoadingPoint(
                  token: context.read<AuthProvider>().token!,
                  tripId: _currentTrip!.id));
          break;
        case 2:
          submittedTrip = await _callSimpleAPI(() => context
              .read<TripProvider>()
              .finishLoading(
                  token: context.read<AuthProvider>().token!,
                  tripId: _currentTrip!.id));
          break;
        case 3:
          submittedTrip =
              await _afterLoadingKey.currentState?.validateAndSubmit();
          break;
        case 4:
          submittedTrip =
              await _uploadDocumentsKey.currentState?.validateAndSubmit();
          break;
        case 5:
          submittedTrip = await _callSimpleAPI(() => context
              .read<TripProvider>()
              .updateToUnloadingPoint(
                  token: context.read<AuthProvider>().token!,
                  tripId: _currentTrip!.id));
          break;
        case 6:
          submittedTrip = await _callSimpleAPI(() => context
              .read<TripProvider>()
              .finishUnloading(
                  token: context.read<AuthProvider>().token!,
                  tripId: _currentTrip!.id));
          break;
        case 7:
          submittedTrip =
              await _buktiAkhirKey.currentState?.validateAndSubmit();
          break;
      }

      if (!mounted || submittedTrip == null) {
        setState(() => _isSendingData = false);
        return;
      }

      setState(() => _currentTrip = submittedTrip);

      bool needsVerification = [0, 3, 4, 7].contains(_currentPage);

      if (needsVerification) {
        await _navigateToVerification(submittedTrip,
            isRevisionResubmission: wasRevision);
      } else {
        int nextPage = _currentPage + 1;
        if (nextPage < _titles.length) {
          _pageController?.animateToPage(nextPage,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        }
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

  Future<Trip?> _callSimpleAPI(Future<Trip?> Function() apiCall) async {
    try {
      final updatedTrip = await apiCall();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Status berhasil diperbarui!'),
            backgroundColor: Colors.green));
      return updatedTrip;
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      return null;
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
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop()),
          TextButton(
              child: const Text('Keluar'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        end: Alignment.bottomCenter))),
            SafeArea(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          const Text(
                            'Memuat detail perjalanan dari server, silahkan coba mulai ulang aplikasi...',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _buildPageView(),
            ),
            if (_isSendingData)
              Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    if (_currentTrip == null) {
      return const Center(child: Text("Data perjalanan tidak tersedia."));
    }
    final isRevision =
        _currentTrip!.derivedStatus == TripDerivedStatus.revisiGambar;
    return Column(
      children: [
        _buildCustomAppBar(isRevision: isRevision),
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: _buildProgressIndicator()),
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
        if (_currentTrip?.derivedStatus != TripDerivedStatus.selesai)
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed:
                  _isSendingData ? null : () => _showExitConfirmationDialog()),
          Text(isRevision ? 'KIRIM ULANG REVISI' : _titles[_currentPage],
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
    return Row(
      children: List.generate(
          _titles.length,
          (index) => Expanded(
                child: Row(children: [
                  CircleAvatar(
                      radius: 5,
                      backgroundColor: index <= _currentPage
                          ? Colors.black87
                          : Colors.grey.shade400),
                  if (index < _titles.length - 1)
                    Expanded(
                        child: Container(
                            height: 2,
                            color: index < _currentPage
                                ? Colors.black87
                                : Colors.grey.shade400)),
                ]),
              )),
    );
  }

  Widget _getPageSpecificContent(int index) {
    if (_currentTrip == null) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return _StartTripPage(key: _startTripKey, trip: _currentTrip!);
      case 1:
        return _InfoDisplayPage(
            trip: _currentTrip!,
            isUnloading: false,
            title: 'Menuju Lokasi Muat');
      case 2:
        return _InfoDisplayPage(
            trip: _currentTrip!,
            isUnloading: false,
            title: 'Proses Muat Barang',
            keterangan: 'Muat semua barang sesuai surat jalan.');
      case 3:
        return _AfterLoadingPage(key: _afterLoadingKey, trip: _currentTrip!);
      case 4:
        return _UploadDocumentsPage(
            key: _uploadDocumentsKey, trip: _currentTrip!);
      case 5:
        return _InfoDisplayPage(
            trip: _currentTrip!,
            isUnloading: true,
            title: 'Menuju Lokasi Bongkar');
      case 6:
        return _InfoDisplayPage(
            trip: _currentTrip!,
            isUnloading: true,
            title: 'Proses Bongkar Barang',
            keterangan:
                'Bongkar semua barang dan pastikan surat jalan ditandatangani.');
      case 7:
        return _BuktiAkhirPage(key: _buktiAkhirKey, trip: _currentTrip!);
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
          swipeText = 'Geser Untuk Mulai Perjalanan';
          break;
        case 1:
          swipeText = 'Geser Jika Sudah Sampai';
          break;
        case 2:
          swipeText = 'Geser Jika Selesai Muat';
          break;
        case 3:
        case 4:
          swipeText = 'Geser Untuk Lanjutkan';
          break;
        case 5:
          swipeText = 'Geser Jika Sudah Sampai';
          break;
        case 6:
          swipeText = 'Geser Jika Selesai Bongkar';
          break;
        case 7:
          swipeText = 'Geser Untuk Selesaikan Perjalanan';
          break;
      }
    }
    return _SwipeButton(
        text: swipeText,
        onConfirm: _handleNextPage,
        isSendingData: _isSendingData);
  }
}

// Sisa kode di bawah ini (widget _StartTripPage, _SuratJalanPage, dll) tidak perlu diubah.
// Anda bisa menggunakan versi yang sudah ada.
class _StartTripPage extends StatefulWidget {
  final Trip trip;
  const _StartTripPage({super.key, required this.trip});
  @override
  State<_StartTripPage> createState() => _StartTripPageState();
}

class _StartTripPageState extends State<_StartTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _startKmController = TextEditingController();
  Vehicle? _selectedVehicle;
  File? _kmAwalImageFile;

  @override
  void initState() {
    super.initState();
    final tripProvider = context.read<TripProvider>();

    // Pre-fill data jika trip sudah memiliki vehicle_id (misalnya saat resume)
    if (widget.trip.vehicleId != null && tripProvider.vehicles.isNotEmpty) {
      try {
        _selectedVehicle = tripProvider.vehicles
            .firstWhere((v) => v.id == widget.trip.vehicleId);
      } catch (e) {
        // Jika vehicle tidak ditemukan di list, biarkan null
        _selectedVehicle = null;
      }
    }
    _startKmController.text = widget.trip.startKm?.toString() ?? '';
  }

  /// Memvalidasi input dan mengirim data ke provider untuk diunggah ke API
  Future<Trip?> validateAndSubmit() async {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    // Validasi untuk pengiriman baru
    if (!isRevision) {
      if (!(_formKey.currentState?.validate() ?? false) ||
          _kmAwalImageFile == null) {
        if (_kmAwalImageFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto KM Awal tidak boleh kosong'),
              backgroundColor: Colors.red));
        }
        return null; // Mengembalikan null jika validasi gagal
      }
    } else {
      // Validasi khusus jika sedang dalam mode revisi
      if (widget.trip.startKmPhotoStatus.isRejected &&
          _kmAwalImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto KM Awal yang ditolak.'),
            backgroundColor: Colors.orange));
        return null;
      }
    }

    return provider.updateStartTrip(
      token: token,
      tripId: widget.trip.id,
      vehicleId: _selectedVehicle!.id,
      startKm: _startKmController.text,
      startKmPhoto: _kmAwalImageFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmStatus = widget.trip.startKmPhotoStatus;
    final isFormEnabled =
        !kmStatus.isApproved; // Form dinonaktifkan jika sudah disetujui
    final vehicles = context.watch<TripProvider>().vehicles;

    debugPrint('[UI] Jumlah kendaraan yang diterima UI: ${vehicles.length}');
    debugPrint(
        '[UI] Apakah form aktif (isFormEnabled)? $isFormEnabled (karena status KM Awal approved: ${kmStatus.isApproved})');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lengkapi Data Awal Perjalanan',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 24),

          // Dropdown untuk memilih kendaraan
          DropdownButtonFormField<Vehicle>(
            value: _selectedVehicle,
            items: vehicles.map((Vehicle vehicle) {
              return DropdownMenuItem<Vehicle>(
                value: vehicle,
                child: Text("${vehicle.licensePlate} (${vehicle.model})"),
              );
            }).toList(),
            onChanged: isFormEnabled
                ? (Vehicle? newValue) {
                    setState(() {
                      _selectedVehicle = newValue;
                    });
                  }
                : null,
            decoration: InputDecoration(
              labelText: 'Pilih Kendaraan',
              // Tambahkan hintText untuk memberi tahu user jika nonaktif
              hintText:
                  !isFormEnabled ? 'Data sudah disetujui' : 'Pilih dari daftar',
              filled: true,
              fillColor: isFormEnabled ? Colors.grey[100] : Colors.grey[200],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.directions_car_outlined),
            ),
            validator: (v) => v == null ? 'Kendaraan harus dipilih' : null,
          ),
          const SizedBox(height: 16),

          // Input untuk KM Awal
          TextFormField(
              controller: _startKmController,
              enabled: isFormEnabled,
              decoration: InputDecoration(
                  labelText: 'KM Awal Kendaraan',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.speed_outlined)),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'KM Awal tidak boleh kosong';
                if (int.tryParse(v) == null) {
                  return 'KM Awal harus berupa angka';
                }
                return null;
              }),
          const SizedBox(height: 24),

          // Widget untuk mengambil foto
          _PhotoSection(
              title: 'Foto KM Awal',
              icon: Icons.camera_alt_outlined,
              onImageChanged: (file) => setState(() => _kmAwalImageFile = file),
              rejectionReason: kmStatus.rejectionReason,
              isApproved: kmStatus.isApproved),
        ],
      ),
    );
  }
}

class _AfterLoadingPage extends StatefulWidget {
  final Trip trip;
  const _AfterLoadingPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_AfterLoadingPage> createState() => _AfterLoadingPageState();
}

class _AfterLoadingPageState extends State<_AfterLoadingPage> {
  File? _kmMuatImage;
  File? _kedatanganMuatImage;
  File? _deliveryOrderImage;
  List<File> _muatImages = [];

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    // Validasi untuk pengiriman baru
    if (!isRevision) {
      if (_kmMuatImage == null ||
          _kedatanganMuatImage == null ||
          _deliveryOrderImage == null ||
          _muatImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null); // Return Future<Trip?>
      }
    } else {
      // Validasi untuk pengiriman revisi
      bool needsKMMuat =
          widget.trip.kmMuatPhotoStatus.isRejected && _kmMuatImage == null;
      bool needsKedatangan = widget.trip.kedatanganMuatPhotoStatus.isRejected &&
          _kedatanganMuatImage == null;
      bool needsDO = widget.trip.deliveryOrderStatus.isRejected &&
          _deliveryOrderImage == null;
      bool needsMuat =
          widget.trip.muatPhotoStatus.isRejected && _muatImages.isEmpty;

      if (needsKMMuat || needsKedatangan || needsDO || needsMuat) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }

    return provider.updateAfterLoading(
      token: token,
      tripId: widget.trip.id,
      kmMuatPhoto: _kmMuatImage,
      kedatanganMuatPhoto: _kedatanganMuatImage,
      deliveryOrderPhoto: _deliveryOrderImage,
      muatPhotos: _muatImages.isNotEmpty ? _muatImages : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmMuatStatus = widget.trip.kmMuatPhotoStatus;
    final kedatanganMuatStatus = widget.trip.kedatanganMuatPhotoStatus;
    final doStatus = widget.trip.deliveryOrderStatus;
    final muatStatus = widget.trip.muatPhotoStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Bukti Tiba & Muat',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),

        // Foto KM di Lokasi Muat
        if (!kmMuatStatus.isApproved)
          _PhotoSection(
              title: 'Foto KM di Lokasi Muat',
              icon: Icons.speed_outlined,
              onImageChanged: (file) => setState(() => _kmMuatImage = file),
              rejectionReason: kmMuatStatus.rejectionReason,
              isApproved: kmMuatStatus.isApproved),
        if (kmMuatStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto KM di Lokasi Muat'),
        const SizedBox(height: 24),

        // Foto Tiba di Lokasi Muat
        if (!kedatanganMuatStatus.isApproved)
          _PhotoSection(
              title: 'Foto Tiba di Lokasi Muat',
              icon: Icons.location_on_outlined,
              onImageChanged: (file) =>
                  setState(() => _kedatanganMuatImage = file),
              rejectionReason: kedatanganMuatStatus.rejectionReason,
              isApproved: kedatanganMuatStatus.isApproved),
        if (kedatanganMuatStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Tiba di Lokasi Muat'),
        const SizedBox(height: 24),

        // Foto Delivery Order
        if (!doStatus.isApproved)
          _PhotoSection(
              title: 'Foto Delivery Order (DO)',
              icon: Icons.receipt_long_outlined,
              onImageChanged: (file) =>
                  setState(() => _deliveryOrderImage = file),
              rejectionReason: doStatus.rejectionReason,
              isApproved: doStatus.isApproved),
        if (doStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Delivery Order (DO)'),
        const SizedBox(height: 24),

        // Foto Proses Muat
        if (!muatStatus.isApproved)
          _MultiPhotoSection(
              title: 'Foto Proses Muat (Bisa lebih dari 1)',
              icon: Icons.inventory_2_outlined,
              onImagesChanged: (files) => setState(() => _muatImages = files),
              rejectionReason: muatStatus.rejectionReason,
              isApproved: muatStatus.isApproved),
        if (muatStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Proses Muat'),
      ],
    );
  }
}

class _UploadDocumentsPage extends StatefulWidget {
  final Trip trip;
  const _UploadDocumentsPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_UploadDocumentsPage> createState() => _UploadDocumentsPageState();
}

class _UploadDocumentsPageState extends State<_UploadDocumentsPage> {
  List<File> _suratJalanAwalImages = [];
  File? _segelImage;
  File? _timbanganImage;

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      if (_suratJalanAwalImages.isEmpty ||
          _segelImage == null ||
          _timbanganImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      bool needsSuratJalan =
          widget.trip.deliveryLetterInitialStatus.isRejected &&
              _suratJalanAwalImages.isEmpty;
      bool needsSegel =
          widget.trip.segelPhotoStatus.isRejected && _segelImage == null;
      bool needsTimbangan =
          widget.trip.timbanganKendaraanPhotoStatus.isRejected &&
              _timbanganImage == null;
      if (needsSuratJalan || needsSegel || needsTimbangan) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }

    return provider.uploadTripDocuments(
      token: token,
      tripId: widget.trip.id,
      deliveryLetters:
          _suratJalanAwalImages.isNotEmpty ? _suratJalanAwalImages : null,
      segelPhoto: _segelImage,
      timbanganPhoto: _timbanganImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final suratJalanStatus = widget.trip.deliveryLetterInitialStatus;
    final segelStatus = widget.trip.segelPhotoStatus;
    final timbanganStatus = widget.trip.timbanganKendaraanPhotoStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Upload Dokumen Perjalanan',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 24),

        // Foto Surat Jalan Awal
        if (!suratJalanStatus.isApproved)
          _MultiPhotoSection(
              title: 'Foto Surat Jalan Awal (Bisa lebih dari 1)',
              icon: Icons.document_scanner_outlined,
              onImagesChanged: (files) =>
                  setState(() => _suratJalanAwalImages = files),
              rejectionReason: suratJalanStatus.rejectionReason,
              isApproved: suratJalanStatus.isApproved),
        if (suratJalanStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Surat Jalan Awal'),
        const SizedBox(height: 24),

        // Foto Segel
        if (!segelStatus.isApproved)
          _PhotoSection(
              title: 'Foto Segel',
              icon: Icons.shield_outlined,
              onImageChanged: (file) => setState(() => _segelImage = file),
              rejectionReason: segelStatus.rejectionReason,
              isApproved: segelStatus.isApproved),
        if (segelStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Segel'),
        const SizedBox(height: 24),

        // Foto Timbangan Kendaraan
        if (!timbanganStatus.isApproved)
          _PhotoSection(
              title: 'Foto Timbangan Kendaraan',
              icon: Icons.scale_outlined,
              onImageChanged: (file) => setState(() => _timbanganImage = file),
              rejectionReason: timbanganStatus.rejectionReason,
              isApproved: timbanganStatus.isApproved),
        if (timbanganStatus.isApproved)
          _ApprovedDocumentPlaceholder(title: 'Foto Timbangan Kendaraan'),
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
  File? _kmAkhirImage;
  File? _kedatanganBongkarImage;
  List<File> _bongkarBarangImages = [];
  List<File> _suratJalanAkhirImages = [];

  @override
  void initState() {
    super.initState();
    _endKmController.text = widget.trip.endKm?.toString() ?? '';
  }

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (!isRevision) {
      final isFormValid = _formKey.currentState?.validate() ?? false;
      if (_kmAkhirImage == null ||
          _kedatanganBongkarImage == null ||
          _bongkarBarangImages.isEmpty ||
          _suratJalanAkhirImages.isEmpty ||
          !isFormValid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua field dan foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      bool needsKmAkhir =
          widget.trip.endKmPhotoStatus.isRejected && _kmAkhirImage == null;
      bool needsKedatanganBongkar =
          widget.trip.kedatanganBongkarPhotoStatus.isRejected &&
              _kedatanganBongkarImage == null;
      bool needsBongkar = widget.trip.bongkarPhotoStatus.isRejected &&
          _bongkarBarangImages.isEmpty;
      bool needsSuratJalan = widget.trip.deliveryLetterFinalStatus.isRejected &&
          _suratJalanAkhirImages.isEmpty;

      if (needsKmAkhir ||
          needsKedatanganBongkar ||
          needsBongkar ||
          needsSuratJalan) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }

    return provider.updateFinishTrip(
      token: token,
      tripId: widget.trip.id,
      endKm: _endKmController.text,
      endKmPhoto: _kmAkhirImage,
      kedatanganBongkarPhoto: _kedatanganBongkarImage,
      bongkarPhotos:
          _bongkarBarangImages.isNotEmpty ? _bongkarBarangImages : null,
      deliveryLetters:
          _suratJalanAkhirImages.isNotEmpty ? _suratJalanAkhirImages : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmAkhirStatus = widget.trip.endKmPhotoStatus;
    final kedatanganBongkarStatus = widget.trip.kedatanganBongkarPhotoStatus;
    final bongkarStatus = widget.trip.bongkarPhotoStatus;
    final suratJalanAkhirStatus = widget.trip.deliveryLetterFinalStatus;

    final isFormEnabled = !kmAkhirStatus.isApproved;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lengkapi Data Akhir Perjalanan',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 24),
          TextFormField(
              enabled: isFormEnabled,
              controller: _endKmController,
              decoration: InputDecoration(
                  labelText: 'KM Akhir Kendaraan',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.speed_outlined)),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'KM Akhir tidak boleh kosong';
                }
                final endKm = int.tryParse(v);
                if (endKm == null) return 'KM Akhir harus berupa angka';
                if (widget.trip.startKm != null &&
                    endKm <= widget.trip.startKm!) {
                  return 'KM Akhir harus > KM Awal (${widget.trip.startKm})';
                }
                return null;
              }),
          const SizedBox(height: 24),
          if (!kedatanganBongkarStatus.isApproved)
            _PhotoSection(
                title: 'Foto Tiba di Lokasi Bongkar',
                icon: Icons.location_on_outlined,
                onImageChanged: (file) =>
                    setState(() => _kedatanganBongkarImage = file),
                rejectionReason: kedatanganBongkarStatus.rejectionReason,
                isApproved: kedatanganBongkarStatus.isApproved),
          if (kedatanganBongkarStatus.isApproved)
            _ApprovedDocumentPlaceholder(title: 'Foto Tiba di Lokasi Bongkar'),
          const SizedBox(height: 24),
          if (!kmAkhirStatus.isApproved)
            _PhotoSection(
                title: 'Foto KM Akhir',
                icon: Icons.camera_alt_outlined,
                onImageChanged: (file) => setState(() => _kmAkhirImage = file),
                rejectionReason: kmAkhirStatus.rejectionReason,
                isApproved: kmAkhirStatus.isApproved),
          if (kmAkhirStatus.isApproved)
            _ApprovedDocumentPlaceholder(title: 'Foto KM Akhir'),
          const SizedBox(height: 24),
          if (!bongkarStatus.isApproved)
            _MultiPhotoSection(
                title: 'Foto Bongkar Barang (Bisa lebih dari 1)',
                icon: Icons.inventory_outlined,
                onImagesChanged: (files) =>
                    setState(() => _bongkarBarangImages = files),
                rejectionReason: bongkarStatus.rejectionReason,
                isApproved: bongkarStatus.isApproved),
          if (bongkarStatus.isApproved)
            _ApprovedDocumentPlaceholder(title: 'Foto Bongkar Barang'),
          const SizedBox(height: 24),
          if (!suratJalanAkhirStatus.isApproved)
            _MultiPhotoSection(
                title: 'Foto Surat Jalan Akhir (Bisa lebih dari 1)',
                icon: Icons.document_scanner_outlined,
                onImagesChanged: (files) =>
                    setState(() => _suratJalanAkhirImages = files),
                rejectionReason: suratJalanAkhirStatus.rejectionReason,
                isApproved: suratJalanAkhirStatus.isApproved),
          if (suratJalanAkhirStatus.isApproved)
            _ApprovedDocumentPlaceholder(title: 'Foto Surat Jalan Akhir'),
        ],
      ),
    );
  }
}

class _InfoDisplayPage extends StatelessWidget {
  final Trip trip;
  final bool isUnloading;
  final String title;
  final String? keterangan;

  const _InfoDisplayPage({
    required this.trip,
    required this.isUnloading,
    required this.title,
    this.keterangan,
  });

  // Fungsi helper untuk membuka URL
  Future<void> _launchUrl(String urlString, BuildContext context) async {
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Link Google Maps tidak tersedia untuk lokasi ini."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Tidak bisa membuka link: $urlString"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan alamat dan link mana yang akan digunakan (origin atau destination)
    final String address =
        isUnloading ? trip.destinationAddress : trip.originAddress;
    final String link = isUnloading ? trip.destinationLink : trip.originLink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 20),

        // Menampilkan Alamat dengan Tombol Link
        _buildInfoRowWithLink('Alamat', address, link, context),

        _buildInfoRow('Proyek', trip.projectName),

        if (keterangan != null) _buildInfoRow('Keterangan', keterangan!),
      ],
    );
  }

  // Widget untuk menampilkan baris info biasa (tanpa link)
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Widget baru untuk menampilkan baris info DENGAN tombol link
  Widget _buildInfoRowWithLink(
      String label, String value, String link, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
              ),
              // Tombol hanya akan muncul jika link tidak kosong
              if (link.isNotEmpty)
                SizedBox(
                  height: 36, // Menyamakan tinggi dengan teks
                  child: IconButton(
                    padding: const EdgeInsets.only(left: 12.0),
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
                    onPressed: () => _launchUrl(link, context),
                    tooltip: 'Buka di Google Maps',
                  ),
                ),
            ],
          ),
        ],
      ),
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
                  child: const Icon(Icons.local_shipping,
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
    final newImage = await ImageHelper.takeGeotaggedPhoto(context);
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

class _MultiPhotoSection extends StatefulWidget {
  final String title;
  final String? rejectionReason;
  final IconData icon;
  final ValueChanged<List<File>> onImagesChanged;
  final bool isApproved;
  const _MultiPhotoSection(
      {required this.title,
      required this.icon,
      required this.onImagesChanged,
      this.rejectionReason,
      this.isApproved = false});
  @override
  State<_MultiPhotoSection> createState() => _MultiPhotoSectionState();
}

class _MultiPhotoSectionState extends State<_MultiPhotoSection> {
  final List<File> _imageFiles = [];
  bool get isRejected =>
      widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty;

  Future<void> _takePicture() async {
    if (widget.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dokumen ini sudah disetujui.'),
          backgroundColor: Colors.green));
      return;
    }
    final File? newImage = await ImageHelper.takePhoto(context);
    if (newImage != null) {
      if (!mounted) return;
      setState(() => _imageFiles.add(newImage));
      widget.onImagesChanged(_imageFiles);
    }
  }

  void _removeImage(int index) {
    setState(() => _imageFiles.removeAt(index));
    widget.onImagesChanged(_imageFiles);
  }

  void _showPreview(File imageFile) {
    if (mounted)
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => _ImagePreviewScreen(imageFile: imageFile)));
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade300;
    if (widget.isApproved) borderColor = Colors.green;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      if (isRejected)
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Revisi: ${widget.rejectionReason}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold))),
      if (widget.isApproved)
        const Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Disetujui',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Container(
          padding: const EdgeInsets.all(8),
          width: double.infinity,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1)),
          child: _imageFiles.isEmpty
              ? _buildImagePickerPlaceholder()
              : _buildImageGrid()),
      const SizedBox(height: 12),
      Center(
          child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text('Tambah Foto'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Theme.of(context).primaryColor)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24)),
              onPressed: _takePicture)),
    ]);
  }

  Widget _buildImageGrid() => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) => GestureDetector(
          onTap: () => _showPreview(_imageFiles[index]),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)),
                clipBehavior: Clip.antiAlias,
                child: Image.file(_imageFiles[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity)),
            Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.red,
                        child:
                            Icon(Icons.close, color: Colors.white, size: 18))))
          ])));
  Widget _buildImagePickerPlaceholder() => GestureDetector(
      onTap: _takePicture,
      child: SizedBox(
          height: 100,
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(widget.icon, size: 40, color: Colors.grey.shade600),
                const SizedBox(height: 8),
                const Text('Ketuk untuk mengambil foto',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey))
              ]))));
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

extension PhotoStatusCheck on PhotoVerificationStatus {
  bool get isRejected => (status?.toLowerCase() == 'rejected' ||
      (rejectionReason != null && rejectionReason!.isNotEmpty));
  bool get isApproved => status?.toLowerCase() == 'approved';
}
