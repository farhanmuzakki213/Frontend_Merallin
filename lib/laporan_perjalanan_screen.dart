import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/waiting_verification_screen.dart';
import 'package:frontend_merallin/widgets/in_app_widgets.dart';
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
  final GlobalKey<_KedatanganMuatPageState> _kedatanganMuatKey = GlobalKey();
  final GlobalKey<_ProsesMuatPageState> _prosesMuatKey = GlobalKey();
  final GlobalKey<_SelesaiMuatPageState> _selesaiMuatKey = GlobalKey();
  final GlobalKey<_KedatanganBongkarPageState> _kedatanganBongkarKey =
      GlobalKey();
  final GlobalKey<_ProsesBongkarPageState> _prosesBongkarKey = GlobalKey();
  final GlobalKey<_SelesaiBongkarPageState> _selesaiBongkarKey = GlobalKey();

  bool _isSendingData = false;

  final List<String> _titles = [
    '1. MULAI PERJALANAN',
    '2. TIBA DI LOKASI MUAT',
    '3. BUKTI AWAL MUAT',
    '4. BUKTI PROSES MUAT',
    '5. BUKTI SELESAI MUAT',
    '6. TIBA DI LOKASI BONGKAR',
    '7. BUKTI AWAL BONGKAR',
    '8. BUKTI PROSES BONGKAR',
    '9. BUKTI SELESAI BONGKAR',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Panggil pengecekan status absensi setiap kali layar ini dibuka
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        context.read<AttendanceProvider>().checkTodayAttendanceStatus(
              context: context,
              token: authProvider.token!,
            );
      }
    _fetchTripDetailsAndProceed();
  }
  );
  }

  Future<void> _fetchTripDetailsAndProceed({bool forceShowForm = false}) async {
    if (!mounted) return;

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
        tripProvider.fetchVehicles(context: context, token: token),
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
        await _navigateToVerification(trip);
      } else {
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
      case 2:
        return !_isStringNullOrEmpty(trip.kmMuatPhotoPath);
      case 3:
        return trip.muatPhotoPath.keys.length >= (trip.jumlahGudangMuat ?? 1);
      case 4:
        return trip.deliveryLetterPath['initial_letters']?.isNotEmpty ?? false;
      case 6:
        return !_isStringNullOrEmpty(trip.endKmPhotoPath);
      case 7:
        return trip.bongkarPhotoPath.keys.length >= (trip.jumlahGudangBongkar ?? 1);
      case 8:
        return trip.deliveryLetterPath['final_letters']?.isNotEmpty ?? false;
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
        _fetchTripDetailsAndProceed(forceShowForm: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verifikasi berhasil!'),
            backgroundColor: Colors.green));

        if (result.updatedTrip.isFullyCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Trip telah selesai!'),
              backgroundColor: Colors.blue));
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false);
          return;
        }

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

    if (trip.statusLokasi == 'menuju lokasi muat') {
      return 1;
    }

    bool isKedatanganMuatApproved = trip.kmMuatPhotoStatus.isApproved &&
        trip.kedatanganMuatPhotoStatus.isApproved &&
        trip.deliveryOrderStatus.isApproved;
    if (!isKedatanganMuatApproved) {
      return 2;
    }

    if (!trip.muatPhotoStatus.isApproved) {
      return 3;
    }

    bool isSelesaiMuatApproved = trip.deliveryLetterInitialStatus.isApproved &&
        trip.segelPhotoStatus.isApproved &&
        trip.timbanganKendaraanPhotoStatus.isApproved;
    if (!isSelesaiMuatApproved) {
      return 4;
    }

    if (trip.statusLokasi == 'menuju lokasi bongkar') {
      return 5;
    }

    bool isKedatanganBongkarApproved = trip.endKmPhotoStatus.isApproved &&
        trip.kedatanganBongkarPhotoStatus.isApproved;
    if (!isKedatanganBongkarApproved) {
      return 6;
    }

    if (!trip.bongkarPhotoStatus.isApproved) {
      return 7;
    }

    if (!trip.deliveryLetterFinalStatus.isApproved) {
      return 8;
    }

    return _currentPage;
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
          submittedTrip =
              await _kedatanganMuatKey.currentState?.validateAndSubmit();
          break;
        case 3:
          submittedTrip =
              await _prosesMuatKey.currentState?.validateAndSubmit();
          break;
        case 4:
          submittedTrip =
              await _selesaiMuatKey.currentState?.validateAndSubmit();
          break;
        case 5:
          submittedTrip = await _callSimpleAPI(() => context
              .read<TripProvider>()
              .updateToUnloadingPoint(
                  token: context.read<AuthProvider>().token!,
                  tripId: _currentTrip!.id));
          break;
        case 6:
          submittedTrip =
              await _kedatanganBongkarKey.currentState?.validateAndSubmit();
          break;
        case 7:
          submittedTrip =
              await _prosesBongkarKey.currentState?.validateAndSubmit();
          break;
        case 8:
          submittedTrip =
              await _selesaiBongkarKey.currentState?.validateAndSubmit();
          break;
      }

      if (!mounted || submittedTrip == null) {
        setState(() => _isSendingData = false);
        return;
      }

      setState(() => _currentTrip = submittedTrip);

      bool needsVerification = [0, 2, 3, 4, 6, 7, 8].contains(_currentPage);

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Status berhasil diperbarui!'),
            backgroundColor: Colors.green));
      }
      return updatedTrip;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
      return null;
    }
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Memuat detail perjalanan...',
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
            if (!_isLoading && _error == null && _currentTrip != null)
              DraggableSpeedDial(
                currentVehicle: _currentTrip!.vehicle,
                showBbmOption: true, // true untuk trip & trip geser
              ),
          ],
        ),
      ),
    );
  }

  void _showCannotExitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Anda harus menyelesaikan perjalanan terlebih dahulu untuk keluar.'),
        backgroundColor: Colors.orange,
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
        const AttendanceNotificationBanner(),
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
            title: 'Menuju Lokasi Muat',
            keterangan:
                'Geser tombol di bawah jika Anda sudah tiba di lokasi muat.',
            trip: _currentTrip!,
            isUnloading: false);
      case 2:
        return _KedatanganMuatPage(
            key: _kedatanganMuatKey, trip: _currentTrip!);
      case 3:
        return _ProsesMuatPage(key: _prosesMuatKey, trip: _currentTrip!);
      case 4:
        return _SelesaiMuatPage(key: _selesaiMuatKey, trip: _currentTrip!);
      case 5:
        return _InfoDisplayPage(
            title: 'Menuju Lokasi Bongkar',
            keterangan:
                'Geser tombol di bawah jika Anda sudah tiba di lokasi bongkar.',
            trip: _currentTrip!,
            isUnloading: true);
      case 6:
        return _KedatanganBongkarPage(
            key: _kedatanganBongkarKey, trip: _currentTrip!);
      case 7:
        return _ProsesBongkarPage(key: _prosesBongkarKey, trip: _currentTrip!);
      case 8:
        return _SelesaiBongkarPage(
            key: _selesaiBongkarKey, trip: _currentTrip!);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton({required bool isRevision}) {
    String swipeText =
        isRevision ? 'Geser Untuk Kirim Revisi' : 'Geser Untuk Konfirmasi';
    if (!isRevision) {
      switch (_currentPage) {
        case 1:
          swipeText = 'Geser Konfirmasi Tiba di Lokasi Muat';
          break;
        case 5:
          swipeText = 'Geser Konfirmasi Tiba di Lokasi Bongkar';
          break;
        case 8:
          swipeText = 'Geser Untuk Selesaikan Perjalanan';
          break;
        default:
          swipeText = 'Geser Untuk Lanjutkan';
      }
    }
    return _SwipeButton(
        text: swipeText,
        onConfirm: _handleNextPage,
        isSendingData: _isSendingData);
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
  final _startKmController = TextEditingController();
  Vehicle? _selectedVehicle;
  File? _kmAwalImageFile;

  @override
  void initState() {
    super.initState();
    final tripProvider = context.read<TripProvider>();

    if (widget.trip.vehicleId != null && tripProvider.vehicles.isNotEmpty) {
      try {
        _selectedVehicle = tripProvider.vehicles
            .firstWhere((v) => v.id == widget.trip.vehicleId);
      } catch (e) {
        _selectedVehicle = null;
      }
    }
    _startKmController.text = widget.trip.startKm?.toString() ?? '';
  }

  Future<Trip?> validateAndSubmit() async {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    final provider = context.read<TripProvider>();
    final token = context.read<AuthProvider>().token!;

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kendaraan harus dipilih.'),
          backgroundColor: Colors.red));
      return null;
    }

    if (!isRevision) {
      if (!(_formKey.currentState?.validate() ?? false) ||
          _kmAwalImageFile == null) {
        if (_kmAwalImageFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Foto KM Awal tidak boleh kosong'),
              backgroundColor: Colors.red));
        }
        return null;
      }
    } else {
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
    final isFormEnabled = !kmStatus.isApproved;
    final vehicles = context.watch<TripProvider>().vehicles;

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
          DropdownButtonFormField<Vehicle>(
            value: _selectedVehicle,
            items: vehicles.map((Vehicle vehicle) {
              return DropdownMenuItem<Vehicle>(
                value: vehicle,
                child: Text("${vehicle.licensePlate} (${vehicle.model})"),
              );
            }).toList(),
            onChanged: isFormEnabled
                ? (Vehicle? newValue) =>
                    setState(() => _selectedVehicle = newValue)
                : null,
            decoration: InputDecoration(
              labelText: 'Pilih Kendaraan',
              hintText:
                  !isFormEnabled ? 'Data sudah disetujui' : 'Pilih dari daftar',
              filled: true,
              fillColor: isFormEnabled ? Colors.grey[100] : Colors.grey[200],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.directions_car_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
              controller: _startKmController,
              enabled: isFormEnabled,
              decoration: InputDecoration(
                  labelText: 'KM Awal Kendaraan',
                  filled: true,
                  fillColor:
                      isFormEnabled ? Colors.grey[100] : Colors.grey[200],
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
          if (!kmStatus.isApproved)
            _PhotoSection(
              title: 'Foto KM Awal',
              icon: Icons.camera_alt_outlined,
              onImageChanged: (file) => setState(() => _kmAwalImageFile = file),
              rejectionReason: kmStatus.rejectionReason,
              isApproved: kmStatus.isApproved,
              existingImageUrl: widget.trip.fullStartKmPhotoUrl,
            )
          else
            _ApprovedDocumentPlaceholder(title: 'Foto KM Awal'),
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
        _buildInfoRowWithLink('Alamat', address, link, context),
        _buildInfoRow('Proyek', trip.projectName),
        if (keterangan != null) _buildInfoRow('Keterangan', keterangan!),
      ],
    );
  }

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
              if (link.isNotEmpty)
                SizedBox(
                  height: 36,
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

class _KedatanganMuatPage extends StatefulWidget {
  final Trip trip;
  const _KedatanganMuatPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_KedatanganMuatPage> createState() => _KedatanganMuatPageState();
}

class _KedatanganMuatPageState extends State<_KedatanganMuatPage> {
  File? _kmMuatImage;
  File? _kedatanganMuatImage;
  File? _deliveryOrderImage;

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;
    if (!isRevision) {
      if (_isStringNullOrEmpty(widget.trip.kmMuatPhotoPath) &&
              _kmMuatImage == null ||
          _isStringNullOrEmpty(widget.trip.kedatanganMuatPhotoPath) &&
              _kedatanganMuatImage == null ||
          _isStringNullOrEmpty(widget.trip.deliveryOrderPath) &&
              _deliveryOrderImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      bool kmMuatNeedsUpdate =
          widget.trip.kmMuatPhotoStatus.isRejected && _kmMuatImage == null;
      bool kedatanganMuatNeedsUpdate =
          widget.trip.kedatanganMuatPhotoStatus.isRejected &&
              _kedatanganMuatImage == null;
      bool doNeedsUpdate = widget.trip.deliveryOrderStatus.isRejected &&
          _deliveryOrderImage == null;

      if (kmMuatNeedsUpdate || kedatanganMuatNeedsUpdate || doNeedsUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }
    return context.read<TripProvider>().submitKedatanganMuat(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          kmMuatPhoto: _kmMuatImage,
          kedatanganMuatPhoto: _kedatanganMuatImage,
          deliveryOrderPhoto: _deliveryOrderImage,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.trip.kmMuatPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto KM di Lokasi Muat',
            icon: Icons.speed_outlined,
            onImageChanged: (f) => _kmMuatImage = f,
            rejectionReason: widget.trip.kmMuatPhotoStatus.rejectionReason,
            isApproved: widget.trip.kmMuatPhotoStatus.isApproved,
            existingImageUrl: widget.trip.fullKmMuatPhotoUrl,
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto KM di Lokasi Muat'),
        const SizedBox(height: 24),
        if (!widget.trip.kedatanganMuatPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto Tiba di Lokasi Muat',
            icon: Icons.location_on_outlined,
            onImageChanged: (f) => _kedatanganMuatImage = f,
            rejectionReason:
                widget.trip.kedatanganMuatPhotoStatus.rejectionReason,
            isApproved: widget.trip.kedatanganMuatPhotoStatus.isApproved,
            existingImageUrl: widget.trip.fullKedatanganMuatPhotoUrl,
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto Tiba di Lokasi Muat'),
        const SizedBox(height: 24),
        if (!widget.trip.deliveryOrderStatus.isApproved)
          _PhotoSection(
            title: 'Foto Delivery Order (DO)',
            icon: Icons.receipt_long_outlined,
            onImageChanged: (f) => _deliveryOrderImage = f,
            rejectionReason: widget.trip.deliveryOrderStatus.rejectionReason,
            isApproved: widget.trip.deliveryOrderStatus.isApproved,
            existingImageUrl: widget.trip.fullDeliveryOrderUrl,
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto Delivery Order (DO)'),
      ],
    );
  }
}

class _ProsesMuatPage extends StatefulWidget {
  final Trip trip;
  const _ProsesMuatPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_ProsesMuatPage> createState() => _ProsesMuatPageState();
}

class _ProsesMuatPageState extends State<_ProsesMuatPage> {
  final List<_GudangData> _gudangDataList = [];
  List<_GudangData> get gudangDataList => _gudangDataList;

  @override
  void initState() {
    super.initState();
    final bool isRevision = widget.trip.muatPhotoStatus.isRejected;

    widget.trip.muatPhotoPath.forEach((gudangName, photoPaths) {
      if (photoPaths.isNotEmpty) {
        _gudangDataList.add(_GudangData()
          ..nameController.text = gudangName
          ..existingPhotoUrls = widget.trip.fullMuatPhotoUrls[gudangName] ?? []
          ..isSaved = !isRevision);
      }
    });

    final int populatedCount = _gudangDataList.length;
    final int totalCount = widget.trip.jumlahGudangMuat ?? 1;
    final int remainingCount = totalCount - populatedCount;

    if (remainingCount > 0) {
      for (int i = 0; i < remainingCount; i++) {
        _gudangDataList.add(_GudangData());
      }
    }
  }

  @override
  void dispose() {
    for (var data in _gudangDataList) {
      data.nameController.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSingleGudang(int index) async {
    final data = _gudangDataList[index];
    if (data.nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nama Gudang tidak boleh kosong.'),
          backgroundColor: Colors.red));
      return;
    }
    if (data.photos.isEmpty && data.existingPhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto untuk gudang ini tidak boleh kosong.'),
          backgroundColor: Colors.red));
      return;
    }

    final parentState =
        context.findAncestorStateOfType<_LaporanDriverScreenState>();
    parentState?.setState(() => parentState._isSendingData = true);

    try {
      final Map<String, List<File>> photosByWarehouse = {
        data.nameController.text.trim(): data.photos
      };

      final updatedTrip = await context.read<TripProvider>().submitProsesMuat(
            token: context.read<AuthProvider>().token!,
            tripId: widget.trip.id,
            photosByWarehouse: photosByWarehouse,
          );

      if (mounted && updatedTrip != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Data gudang berhasil disimpan!'),
            backgroundColor: Colors.green));
        await parentState?._fetchTripDetailsAndProceed(forceShowForm: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        parentState?.setState(() => parentState._isSendingData = false);
      }
    }
  }

  Future<Trip?> validateAndSubmit() {
    // 1. Validasi SEMUA field harus terisi
    for (int i = 0; i < _gudangDataList.length; i++) {
      final data = _gudangDataList[i];
      if (data.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Nama Gudang ke-${i + 1} tidak boleh kosong.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
      if (data.photos.isEmpty && data.existingPhotoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Foto untuk Gudang "${data.nameController.text}" tidak boleh kosong.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    }

    // 2. Kumpulkan semua foto BARU dari semua gudang (terutama gudang terakhir)
    final Map<String, List<File>> photosToUpload = {};
    for (var data in _gudangDataList) {
      if (data.photos.isNotEmpty) {
        photosToUpload[data.nameController.text.trim()] = data.photos;
      }
    }

    // 3. Jika tidak ada foto baru (semua sudah disimpan), lanjutkan saja
    if (photosToUpload.isEmpty) {
      return Future.value(widget.trip);
    }

    // 4. Kirim sisa data yang belum disimpan ke API
    return context.read<TripProvider>().submitProsesMuat(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          photosByWarehouse: photosToUpload,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trip.muatPhotoStatus.isApproved) {
      return const _ApprovedDocumentPlaceholder(title: 'Foto Proses Muat');
    }

    return Column(
      children: [
        ..._gudangDataList.asMap().entries.map((entry) {
          int idx = entry.key;
          _GudangData data = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gudang Muat ${idx + 1}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                    // HILANGKAN TOMBOL SIMPAN PADA GUDANG TERAKHIR
                    if (idx < _gudangDataList.length - 1 && !data.isSaved)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Simpan'),
                        onPressed: () => _saveSingleGudang(idx),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: data.nameController,
                  enabled: !data.isSaved,
                  decoration: InputDecoration(
                    labelText: 'Nama Gudang',
                    filled: true,
                    fillColor:
                        !data.isSaved ? Colors.grey[100] : Colors.grey[200],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                _MultiPhotoSection(
                  title: 'Foto-foto Muat',
                  icon: Icons.photo_library_outlined,
                  onImagesChanged: (files) {
                    setState(() => data.photos = files);
                  },
                  existingImageUrls: data.existingPhotoUrls,
                  isApproved: data.isSaved,
                  rejectionReason: widget.trip.muatPhotoStatus.rejectionReason,
                  isRejected: widget.trip.muatPhotoStatus.isRejected,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _SelesaiMuatPage extends StatefulWidget {
  final Trip trip;
  const _SelesaiMuatPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_SelesaiMuatPage> createState() => _SelesaiMuatPageState();
}

class _SelesaiMuatPageState extends State<_SelesaiMuatPage> {
  List<File> _suratJalanAwalImages = [];
  File? _segelImage;
  File? _timbanganImage;

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;

    bool sjReady = _suratJalanAwalImages.isNotEmpty ||
        (widget.trip.deliveryLetterPath['initial_letters']?.isNotEmpty ??
            false);
    bool segelReady = _segelImage != null ||
        !_isStringNullOrEmpty(widget.trip.segelPhotoPath);
    bool timbanganReady = _timbanganImage != null ||
        !_isStringNullOrEmpty(widget.trip.timbanganKendaraanPhotoPath);

    if (!isRevision) {
      if (!sjReady || !segelReady || !timbanganReady) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      bool sjNeedsUpdate = widget.trip.deliveryLetterInitialStatus.isRejected &&
          _suratJalanAwalImages.isEmpty;
      bool segelNeedsUpdate =
          widget.trip.segelPhotoStatus.isRejected && _segelImage == null;
      bool timbanganNeedsUpdate =
          widget.trip.timbanganKendaraanPhotoStatus.isRejected &&
              _timbanganImage == null;

      if (sjNeedsUpdate || segelNeedsUpdate || timbanganNeedsUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Silakan unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }
    return context.read<TripProvider>().submitSelesaiMuat(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          deliveryLetters: _suratJalanAwalImages,
          segelPhoto: _segelImage,
          timbanganPhoto: _timbanganImage,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.trip.deliveryLetterInitialStatus.isApproved)
          _MultiPhotoSection(
            title: 'Foto Surat Jalan Awal',
            icon: Icons.document_scanner_outlined,
            onImagesChanged: (f) => _suratJalanAwalImages = f,
            rejectionReason:
                widget.trip.deliveryLetterInitialStatus.rejectionReason,
            isApproved: widget.trip.deliveryLetterInitialStatus.isApproved,
            isRejected: widget.trip.deliveryLetterInitialStatus.isRejected,
            existingImageUrls:
                widget.trip.fullDeliveryLetterUrls['initial'] ?? [],
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto Surat Jalan Awal'),
        const SizedBox(height: 24),
        if (!widget.trip.segelPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto Segel',
            icon: Icons.shield_outlined,
            onImageChanged: (f) => _segelImage = f,
            rejectionReason: widget.trip.segelPhotoStatus.rejectionReason,
            isApproved: widget.trip.segelPhotoStatus.isApproved,
            existingImageUrl: widget.trip.fullSegelPhotoUrl,
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto Segel'),
        const SizedBox(height: 24),
        if (!widget.trip.timbanganKendaraanPhotoStatus.isApproved)
          _PhotoSection(
            title: 'Foto Timbangan Kendaraan',
            icon: Icons.scale_outlined,
            onImageChanged: (f) => _timbanganImage = f,
            rejectionReason:
                widget.trip.timbanganKendaraanPhotoStatus.rejectionReason,
            isApproved: widget.trip.timbanganKendaraanPhotoStatus.isApproved,
            existingImageUrl: widget.trip.fullTimbanganKendaraanPhotoUrl,
          )
        else
          const _ApprovedDocumentPlaceholder(title: 'Foto Timbangan Kendaraan'),
      ],
    );
  }
}

class _KedatanganBongkarPage extends StatefulWidget {
  final Trip trip;
  const _KedatanganBongkarPage({super.key, required this.trip});
  @override
  State<_KedatanganBongkarPage> createState() => _KedatanganBongkarPageState();
}

class _KedatanganBongkarPageState extends State<_KedatanganBongkarPage> {
  final _formKey = GlobalKey<FormState>();
  final _endKmController = TextEditingController();
  File? _kmAkhirImage;
  File? _kedatanganBongkarImage;

  @override
  void initState() {
    super.initState();
    _endKmController.text = widget.trip.endKm?.toString() ?? '';
  }

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;

    bool kmReady = _kmAkhirImage != null ||
        !_isStringNullOrEmpty(widget.trip.endKmPhotoPath);
    bool kedatanganReady = _kedatanganBongkarImage != null ||
        !_isStringNullOrEmpty(widget.trip.kedatanganBongkarPhotoPath);

    if (!isRevision) {
      if (!(_formKey.currentState?.validate() ?? false) ||
          !kmReady ||
          !kedatanganReady) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Semua field dan foto wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      bool kmNeedsUpdate =
          widget.trip.endKmPhotoStatus.isRejected && _kmAkhirImage == null;
      bool kedatanganNeedsUpdate =
          widget.trip.kedatanganBongkarPhotoStatus.isRejected &&
              _kedatanganBongkarImage == null;

      if (kmNeedsUpdate || kedatanganNeedsUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unggah ulang foto yang ditolak.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }

    return context.read<TripProvider>().submitKedatanganBongkar(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          endKm: _endKmController.text,
          endKmPhoto: _kmAkhirImage,
          kedatanganBongkarPhoto: _kedatanganBongkarImage,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isFormEnabled = !widget.trip.endKmPhotoStatus.isApproved ||
        !widget.trip.kedatanganBongkarPhotoStatus.isApproved;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            enabled: isFormEnabled,
            controller: _endKmController,
            decoration: InputDecoration(
                labelText: 'KM Akhir Kendaraan',
                filled: true,
                fillColor: isFormEnabled ? Colors.grey[100] : Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.speed_outlined)),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'KM Akhir tidak boleh kosong';
              final endKm = int.tryParse(v);
              if (endKm == null) return 'KM Akhir harus berupa angka';
              if (widget.trip.startKm != null &&
                  endKm <= widget.trip.startKm!) {
                return 'KM Akhir harus > KM Awal (${widget.trip.startKm})';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (!widget.trip.endKmPhotoStatus.isApproved)
            _PhotoSection(
              title: 'Foto KM Akhir',
              icon: Icons.camera_alt_outlined,
              onImageChanged: (f) => _kmAkhirImage = f,
              rejectionReason: widget.trip.endKmPhotoStatus.rejectionReason,
              isApproved: widget.trip.endKmPhotoStatus.isApproved,
              existingImageUrl: widget.trip.fullEndKmPhotoUrl,
            )
          else
            const _ApprovedDocumentPlaceholder(title: 'Foto KM Akhir'),
          const SizedBox(height: 24),
          if (!widget.trip.kedatanganBongkarPhotoStatus.isApproved)
            _PhotoSection(
              title: 'Foto Tiba di Lokasi Bongkar',
              icon: Icons.location_on_outlined,
              onImageChanged: (f) => _kedatanganBongkarImage = f,
              rejectionReason:
                  widget.trip.kedatanganBongkarPhotoStatus.rejectionReason,
              isApproved: widget.trip.kedatanganBongkarPhotoStatus.isApproved,
              existingImageUrl: widget.trip.fullKedatanganBongkarPhotoUrl,
            )
          else
            const _ApprovedDocumentPlaceholder(
                title: 'Foto Tiba di Lokasi Bongkar'),
        ],
      ),
    );
  }
}

class _ProsesBongkarPage extends StatefulWidget {
  final Trip trip;
  const _ProsesBongkarPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_ProsesBongkarPage> createState() => _ProsesBongkarPageState();
}

class _ProsesBongkarPageState extends State<_ProsesBongkarPage> {
  final List<_GudangData> _gudangDataList = [];
  List<_GudangData> get gudangDataList => _gudangDataList;

  @override
  void initState() {
    super.initState();
    final bool isRevision = widget.trip.bongkarPhotoStatus.isRejected;

    widget.trip.bongkarPhotoPath.forEach((gudangName, photoPaths) {
      if (photoPaths.isNotEmpty) {
        _gudangDataList.add(_GudangData()
          ..nameController.text = gudangName
          ..existingPhotoUrls =
              widget.trip.fullBongkarPhotoUrls[gudangName] ?? []
          ..isSaved = !isRevision);
      }
    });

    final int populatedCount = _gudangDataList.length;
    final int totalCount = widget.trip.jumlahGudangBongkar ?? 1;
    final int remainingCount = totalCount - populatedCount;

    if (remainingCount > 0) {
      for (int i = 0; i < remainingCount; i++) {
        _gudangDataList.add(_GudangData());
      }
    }
  }

  @override
  void dispose() {
    for (var data in _gudangDataList) {
      data.nameController.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSingleGudang(int index) async {
    final data = _gudangDataList[index];
    if (data.nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nama Gudang tidak boleh kosong.'),
          backgroundColor: Colors.red));
      return;
    }
    if (data.photos.isEmpty && data.existingPhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto untuk gudang ini tidak boleh kosong.'),
          backgroundColor: Colors.red));
      return;
    }

    final parentState =
        context.findAncestorStateOfType<_LaporanDriverScreenState>();
    parentState?.setState(() => parentState._isSendingData = true);

    try {
      final Map<String, List<File>> photosByWarehouse = {
        data.nameController.text.trim(): data.photos
      };

      final updatedTrip =
          await context.read<TripProvider>().submitProsesBongkar(
                token: context.read<AuthProvider>().token!,
                tripId: widget.trip.id,
                photosByWarehouse: photosByWarehouse,
              );

      if (mounted && updatedTrip != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Data gudang berhasil disimpan!'),
            backgroundColor: Colors.green));
        await parentState?._fetchTripDetailsAndProceed(forceShowForm: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        parentState?.setState(() => parentState._isSendingData = false);
      }
    }
  }

  Future<Trip?> validateAndSubmit() {
    // 1. Validasi SEMUA field harus terisi
    for (int i = 0; i < _gudangDataList.length; i++) {
      final data = _gudangDataList[i];
      if (data.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Nama Gudang ke-${i + 1} tidak boleh kosong.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
      if (data.photos.isEmpty && data.existingPhotoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Foto untuk Gudang "${data.nameController.text}" tidak boleh kosong.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    }

    // 2. Kumpulkan semua foto BARU dari semua gudang (terutama gudang terakhir)
    final Map<String, List<File>> photosToUpload = {};
    for (var data in _gudangDataList) {
      if (data.photos.isNotEmpty) {
        photosToUpload[data.nameController.text.trim()] = data.photos;
      }
    }

    // 3. Jika tidak ada foto baru (semua sudah disimpan), lanjutkan saja
    if (photosToUpload.isEmpty) {
      return Future.value(widget.trip);
    }

    // 4. Kirim sisa data yang belum disimpan ke API
    return context.read<TripProvider>().submitProsesBongkar(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          photosByWarehouse: photosToUpload,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trip.bongkarPhotoStatus.isApproved) {
      return const _ApprovedDocumentPlaceholder(title: 'Foto Proses Bongkar');
    }

    return Column(
      children: [
        ..._gudangDataList.asMap().entries.map((entry) {
          int idx = entry.key;
          _GudangData data = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gudang Bongkar ${idx + 1}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                    // HILANGKAN TOMBOL SIMPAN PADA GUDANG TERAKHIR
                    if (idx < _gudangDataList.length - 1 && !data.isSaved)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Simpan'),
                        onPressed: () => _saveSingleGudang(idx),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: data.nameController,
                  enabled: !data.isSaved,
                  decoration: InputDecoration(
                    labelText: 'Nama Gudang',
                    filled: true,
                    fillColor:
                        !data.isSaved ? Colors.grey[100] : Colors.grey[200],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                _MultiPhotoSection(
                  title: 'Foto-foto Bongkar',
                  icon: Icons.photo_library_outlined,
                  onImagesChanged: (files) {
                    setState(() => data.photos = files);
                  },
                  existingImageUrls: data.existingPhotoUrls,
                  isApproved: data.isSaved,
                  rejectionReason:
                      widget.trip.bongkarPhotoStatus.rejectionReason,
                  isRejected: widget.trip.bongkarPhotoStatus.isRejected,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _SelesaiBongkarPage extends StatefulWidget {
  final Trip trip;
  const _SelesaiBongkarPage({Key? key, required this.trip}) : super(key: key);
  @override
  State<_SelesaiBongkarPage> createState() => _SelesaiBongkarPageState();
}

class _SelesaiBongkarPageState extends State<_SelesaiBongkarPage> {
  List<File> _suratJalanAkhirImages = [];

  Future<Trip?> validateAndSubmit() {
    final isRevision =
        widget.trip.derivedStatus == TripDerivedStatus.revisiGambar;

    bool sjReady = _suratJalanAkhirImages.isNotEmpty ||
        (widget.trip.deliveryLetterPath['final_letters']?.isNotEmpty ?? false);

    if (!isRevision) {
      if (!sjReady) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Surat jalan akhir wajib diisi.'),
            backgroundColor: Colors.red));
        return Future.value(null);
      }
    } else {
      if (widget.trip.deliveryLetterFinalStatus.isRejected &&
          _suratJalanAkhirImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unggah ulang surat jalan akhir.'),
            backgroundColor: Colors.orange));
        return Future.value(null);
      }
    }
    return context.read<TripProvider>().submitSelesaiBongkar(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          deliveryLetters: _suratJalanAkhirImages,
        );
  }

  @override
  Widget build(BuildContext context) {
    return !widget.trip.deliveryLetterFinalStatus.isApproved
        ? _MultiPhotoSection(
            title: 'Foto Surat Jalan Akhir (Telah Ditandatangani)',
            icon: Icons.document_scanner_outlined,
            onImagesChanged: (files) => _suratJalanAkhirImages = files,
            rejectionReason:
                widget.trip.deliveryLetterFinalStatus.rejectionReason,
            isApproved: widget.trip.deliveryLetterFinalStatus.isApproved,
            isRejected: widget.trip.deliveryLetterFinalStatus.isRejected,
            existingImageUrls:
                widget.trip.fullDeliveryLetterUrls['final'] ?? [],
          )
        : const _ApprovedDocumentPlaceholder(title: 'Foto Surat Jalan Akhir');
  }
}

class _GudangData {
  final TextEditingController nameController = TextEditingController();
  List<File> photos = [];
  List<String> existingPhotoUrls = [];
  bool isSaved = false;
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
  final String? existingImageUrl;

  const _PhotoSection({
    required this.title,
    required this.icon,
    required this.onImageChanged,
    this.rejectionReason,
    this.isApproved = false,
    this.existingImageUrl,
  });
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
    if (_imageFile != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => _ImagePreviewScreen(imageFile: _imageFile!)));
    } else if (widget.existingImageUrl != null &&
        widget.existingImageUrl!.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              _NetworkImagePreviewScreen(imageUrl: widget.existingImageUrl!)));
    }
  }

  Widget _buildImageWidget() {
    if (_imageFile != null) {
      return Positioned.fill(child: Image.file(_imageFile!, fit: BoxFit.cover));
    }
    if (widget.existingImageUrl != null &&
        widget.existingImageUrl!.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          widget.existingImageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stack) =>
              const Center(child: Icon(Icons.error_outline, color: Colors.red)),
        ),
      );
    }
    return Center(
        child: Icon(widget.icon, size: 50, color: Colors.grey.shade600));
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade400;
    if (widget.isApproved) borderColor = Colors.green;

    final String rejectionText = widget.rejectionReason?.isNotEmpty == true
        ? widget.rejectionReason!
        : "Foto ditolak, silakan unggah ulang.";

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
            child: Text('Revisi: $rejectionText',
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
          onTap: _showPreview,
          child: Container(
              height: 150,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5)),
              child: Stack(alignment: Alignment.center, children: [
                _buildImageWidget(),
                if (_imageFile != null ||
                    (widget.existingImageUrl != null &&
                        widget.existingImageUrl!.isNotEmpty))
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 32))
              ]))),
      const SizedBox(height: 12),
      ElevatedButton.icon(
          icon: Icon(_imageFile == null &&
                  (widget.existingImageUrl == null ||
                      widget.existingImageUrl!.isEmpty)
              ? Icons.camera_alt_outlined
              : Icons.replay_outlined),
          label: Text(_imageFile == null &&
                  (widget.existingImageUrl == null ||
                      widget.existingImageUrl!.isEmpty)
              ? 'Ambil Foto'
              : 'Ambil Ulang'),
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
  final bool isRejected;
  final List<String> existingImageUrls;

  const _MultiPhotoSection(
      {required this.title,
      required this.icon,
      required this.onImagesChanged,
      this.rejectionReason,
      this.isApproved = false,
      this.isRejected = false,
      this.existingImageUrls = const []});
  @override
  State<_MultiPhotoSection> createState() => _MultiPhotoSectionState();
}

class _MultiPhotoSectionState extends State<_MultiPhotoSection> {
  final List<File> _imageFiles = [];
  List<String> _visibleExistingUrls = [];

  @override
  void initState() {
    super.initState();
    _visibleExistingUrls = List.from(widget.existingImageUrls);
  }

  @override
  void didUpdateWidget(covariant _MultiPhotoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existingImageUrls != oldWidget.existingImageUrls) {
      setState(() {
        _visibleExistingUrls = List.from(widget.existingImageUrls);
      });
    }
  }

  Future<void> _takePicture() async {
    if (widget.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data untuk gudang ini sudah disimpan/disetujui.'),
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

  void _removeNewImage(int index) {
    setState(() => _imageFiles.removeAt(index));
    widget.onImagesChanged(_imageFiles);
  }

  void _removeExistingImage(int index) {
    setState(() {
      _visibleExistingUrls.removeAt(index);
    });
  }

  void _showPreview(File imageFile) {
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => _ImagePreviewScreen(imageFile: imageFile)));
    }
  }

  void _showNetworkPreview(String imageUrl) {
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              _NetworkImagePreviewScreen(imageUrl: imageUrl)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRejected = widget.isRejected;
    Color borderColor = isRejected ? Colors.red : Colors.grey.shade300;
    if (widget.isApproved) borderColor = Colors.green;

    final String rejectionText = widget.rejectionReason?.isNotEmpty == true
        ? widget.rejectionReason!
        : "Foto ditolak, silakan unggah ulang.";

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      if (isRejected)
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Revisi: $rejectionText',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold))),
      if (widget.isApproved)
        const Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Tersimpan',
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
          child: (_imageFiles.isEmpty && _visibleExistingUrls.isEmpty)
              ? _buildImagePickerPlaceholder()
              : _buildImageGrid()),
      const SizedBox(height: 12),
      if (!widget.isApproved)
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
                        side:
                            BorderSide(color: Theme.of(context).primaryColor)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24)),
                onPressed: _takePicture)),
    ]);
  }

  Widget _buildImageGrid() {
    final int existingCount = _visibleExistingUrls.length;
    final int newCount = _imageFiles.length;
    final int totalCount = existingCount + newCount;

    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index < existingCount) {
            final imageUrl = _visibleExistingUrls[index];
            return GestureDetector(
              onTap: () => _showNetworkPreview(imageUrl),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress ==
                              null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.error_outline, color: Colors.red)),
                    ),
                  ),
                  if (widget.isRejected)
                    Positioned(
                      top: -10,
                      right: -10,
                      child: GestureDetector(
                        onTap: () => _removeExistingImage(index),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.red,
                          child:
                              Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          final fileIndex = index - existingCount;
          final imageFile = _imageFiles[fileIndex];
          return GestureDetector(
            onTap: () => _showPreview(imageFile),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300)),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(imageFile, fit: BoxFit.cover),
                ),
                if (!widget.isApproved)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: () => _removeNewImage(fileIndex),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
  }

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
  const _ImagePreviewScreen({required this.imageFile});
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

class _NetworkImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  const _NetworkImagePreviewScreen({required this.imageUrl});
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
              child: Image.network(imageUrl))),
    );
  }
}

extension PhotoStatusCheck on PhotoVerificationStatus {
  bool get isRejected => (status?.toLowerCase() == 'rejected' ||
      (rejectionReason != null && rejectionReason!.isNotEmpty));
  bool get isApproved => status?.toLowerCase() == 'approved';
}
