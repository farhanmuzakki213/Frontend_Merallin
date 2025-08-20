// lib/laporan_perjalanan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/trip_service.dart'; // Contains ApiException
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../utils/image_helper.dart';

//==============================================================================
// Main Screen Widget
//==============================================================================
class LaporanDriverScreen extends StatefulWidget {
  final Trip trip;
  const LaporanDriverScreen({super.key, required this.trip});

  @override
  State<LaporanDriverScreen> createState() => _LaporanDriverScreenState();
}

class _LaporanDriverScreenState extends State<LaporanDriverScreen> {
  late PageController _pageController;
  late int _initialPage;
  int _currentPage = 0;

  final GlobalKey<_StartTripPageState> _startTripKey = GlobalKey();
  final GlobalKey<_SuratJalanPageState> _suratJalanKey = GlobalKey();
  final GlobalKey<_BuktiAkhirPageState> _buktiAkhirKey = GlobalKey();

  // State for swipe button
  double _swipePosition = 0.0;
  bool _isConfirmed = false;
  final double _swipeButtonHeight = 60.0;
  final double _swipeAreaWidth = 280.0;

  bool _isSendingData = false;

  final List<String> _titles = [
    'MULAI PERJALANAN',
    'MENUJU TITIK MUAT BARANG',
    'MEMUAT BARANG',
    'SURAT JALAN',
    'MENUJU TITIK BONGKAR',
    'BONGKAR BARANG',
    'BUKTI AKHIR',
  ];

  @override
  void initState() {
    super.initState();
    _initialPage = _determineInitialPage(widget.trip);
    _currentPage = _initialPage;
    _pageController = PageController(initialPage: _initialPage);
  }

  int _determineInitialPage(Trip trip) {
    if (trip.statusTrip == 'selesai') return 6;
    if (trip.statusMuatan == 'selesai bongkar') return 6;
    if (trip.statusLokasi == 'di lokasi bongkar') return 5;
    if (trip.statusMuatan == 'termuat' ||
        trip.statusLokasi == 'menuju lokasi bongkar') return 4;
    if (trip.statusMuatan == 'selesai muat') return 3;
    if (trip.statusLokasi == 'di lokasi muat') return 2;
    if (trip.statusLokasi == 'menuju lokasi muat') return 1;
    return 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _handleNextPage() async {
    if (_isSendingData) return false;

    bool canProceed = false;
    setState(() => _isSendingData = true);

    try {
      switch (_currentPage) {
        case 0:
          canProceed =
              await _startTripKey.currentState?.validateAndSubmit() ?? false;
          break;
        case 1:
          canProceed = await _callAPI(() => TripService().updateToLoadingPoint(
              token: context.read<AuthProvider>().token!,
              tripId: widget.trip.id));
          break;
        case 2:
          canProceed = await _callAPI(() => TripService().finishLoading(
              token: context.read<AuthProvider>().token!,
              tripId: widget.trip.id));
          break;
        case 3:
          canProceed =
              await _suratJalanKey.currentState?.validateAndSubmit() ?? false;
          break;
        case 4:
          canProceed = await _callAPI(() => TripService().updateToUnloadingPoint(
              token: context.read<AuthProvider>().token!,
              tripId: widget.trip.id));
          break;
        case 5:
          canProceed = await _callAPI(() => TripService().finishUnloading(
              token: context.read<AuthProvider>().token!,
              tripId: widget.trip.id));
          break;
        case 6:
          canProceed =
              await _buktiAkhirKey.currentState?.validateAndSubmit() ?? false;
          if (canProceed && mounted) {
            Navigator.pop(context, true);
          }
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingData = false);
      }
    }

    if (canProceed && _currentPage < _titles.length - 1) {
      _pageController.animateToPage(_currentPage + 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
    return canProceed;
  }

  Future<bool> _callAPI(Future<void> Function() apiCall) async {
    try {
      await apiCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Status berhasil diperbarui!'),
            backgroundColor: Colors.green));
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Terjadi kesalahan tidak terduga: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return false;
    }
  }

  void _onSwipeConfirm() async {
    if (_isSendingData) return;

    final bool success = await _handleNextPage();

    if (mounted) {
      if (success) {
        setState(() => _isConfirmed = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _swipePosition = 0;
              _isConfirmed = false;
            });
          }
        });
      } else {
        setState(() {
          _swipePosition = 0;
        });
      }
    }
  }

  Future<void> _showExitConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Keluar'),
          content: const Text(
              'Progres Anda sudah tersimpan di server. Apakah Anda yakin ingin keluar dari halaman ini?'),
          actions: <Widget>[
            TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Keluar'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _showExitConfirmationDialog();
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
                    end: Alignment.bottomCenter),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildCustomAppBar(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _titles.length,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        return _PageCardWrapper(
                          child: _getPageSpecificContent(index),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _currentPage == 0
                        ? _buildStartTripButton()
                        : _buildSwipeButton(),
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

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed:
                    _isSendingData ? null : _showExitConfirmationDialog,
              ),
              Text(_titles[_currentPage],
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(width: 48), // Placeholder
            ],
          ),
          const SizedBox(height: 10),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        const Text('MULAI', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_titles.length, (index) {
              return Expanded(
                child: Row(
                  children: [
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
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        const Text('SELESAI',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _getPageSpecificContent(int index) {
    switch (index) {
      case 0:
        return _StartTripPage(key: _startTripKey, trip: widget.trip);
      case 1:
      case 4:
        return _InfoDisplayPage(trip: widget.trip, isUnloading: index == 4);
      case 2:
        return _InfoDisplayPage(
            trip: widget.trip,
            isUnloading: false,
            keterangan: 'Muat semua barang sesuai surat jalan.');
      case 3:
        return _SuratJalanPage(key: _suratJalanKey, trip: widget.trip);
      case 5:
        return _InfoDisplayPage(
            trip: widget.trip,
            isUnloading: true,
            keterangan:
                'Bongkar semua barang dan pastikan surat jalan ditandatangani.');
      case 6:
        return _BuktiAkhirPage(key: _buktiAkhirKey, trip: widget.trip);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStartTripButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00838F), Color(0xFF00ACC1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSendingData ? null : _handleNextPage,
          borderRadius: BorderRadius.circular(30),
          child: const Center(
              child: Text('MULAI PERJALANAN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildSwipeButton() {
    return Container(
      width: _swipeAreaWidth + 70,
      height: _swipeButtonHeight,
      decoration: BoxDecoration(
          color: _isConfirmed ? Colors.green : const Color(0xFFFF7043),
          borderRadius: BorderRadius.circular(30)),
      child: GestureDetector(
        onHorizontalDragUpdate: _isSendingData
            ? null
            : (details) {
                if (_isConfirmed) return;
                setState(() {
                  _swipePosition += details.delta.dx;
                  _swipePosition = _swipePosition.clamp(0, _swipeAreaWidth);
                });
              },
        onHorizontalDragEnd: _isSendingData
            ? null
            : (details) {
                if (_swipePosition > _swipeAreaWidth * 0.75) {
                  _onSwipeConfirm();
                } else {
                  setState(() => _swipePosition = 0);
                }
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: _isConfirmed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                  _currentPage == _titles.length - 1
                      ? 'Geser Jika Sudah Selesai'
                      : 'Geser Jika Sudah Sampai',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            AnimatedOpacity(
              opacity: _isConfirmed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Confirmed!',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    SizedBox(width: 8),
                    CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check,
                            color: Colors.green, size: 16))
                  ]),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              left: _swipePosition,
              child: AnimatedOpacity(
                opacity: _isConfirmed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: 70,
                  height: _swipeButtonHeight,
                  decoration: BoxDecoration(
                      color: const Color(0xFF00838F),
                      borderRadius: BorderRadius.circular(30)),
                  child: const Icon(Icons.local_shipping,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//==============================================================================
// Wrapper Widget for consistent page layout
//==============================================================================
class _PageCardWrapper extends StatelessWidget {
  final Widget child;
  const _PageCardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: child,
        ),
      ),
    );
  }
}

//==============================================================================
// Page Content Widgets
//==============================================================================

class _InfoDisplayPage extends StatelessWidget {
  final Trip trip;
  final bool isUnloading;
  final String? keterangan;

  const _InfoDisplayPage(
      {required this.trip, required this.isUnloading, this.keterangan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Nomor Pengiriman',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 4),
        Text('0000000${trip.id}',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),
        _buildInfoRow('Alamat', isUnloading ? trip.destination : trip.origin),
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
          Text(value,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final double height;
  final String? errorMessage;
  final ValueChanged<File?> onImageChanged;

  const _PhotoSection({
    required this.title,
    required this.icon,
    this.height = 200,
    this.errorMessage,
    required this.onImageChanged,
  });

  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  File? _imageFile;

  Future<void> _takePicture() async {
    final newImage = await ImageHelper.takeGeotaggedPhoto(context);
    if (newImage != null) {
      setState(() => _imageFile = newImage);
      widget.onImageChanged(_imageFile);
    }
  }

  void _showPreview() {
    if (_imageFile == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewScreen(imageFile: _imageFile!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _imageFile == null ? _takePicture : _showPreview,
          child: Container(
            height: widget.height,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: widget.errorMessage != null
                      ? Colors.red
                      : Colors.grey.shade400,
                  width: 1.5),
            ),
            child: _imageFile == null
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.icon, size: 50, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          const Text('Ketuk untuk mengambil foto',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ]),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                      Container(color: Colors.black.withOpacity(0.20)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in,
                            color: Colors.white, size: 32),
                      ),
                    ],
                  ),
          ),
        ),
        if (widget.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(widget.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: Icon(
              _imageFile == null ? Icons.camera_alt_outlined : Icons.replay_outlined),
          label: Text(_imageFile == null ? 'Ambil Foto' : 'Ambil Ulang Foto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).primaryColor)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
          onPressed: _takePicture,
        ),
      ],
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
  Map<String, String> _errors = {};

  Future<bool> validateAndSubmit() async {
    setState(() => _errors = {}); // Clear previous errors

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isImagePresent = _kmAwalImageFile != null;

    if (!isImagePresent) {
      setState(() => _errors['start_km_photo'] = 'Foto KM Awal tidak boleh kosong');
    }

    if (isFormValid && isImagePresent) {
      try {
        await TripService().updateStartTrip(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          licensePlate: _licensePlateController.text,
          startKm: _startKmController.text,
          startKmPhoto: _kmAwalImageFile!,
        );
        return true;
      } on ApiException catch (e) {
        if (mounted) {
          if (e.errors != null) {
            setState(() {
              _errors = e.errors!.map((key, value) => MapEntry(key, value.join(' ')));
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
            );
          }
        }
        return false;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Terjadi kesalahan: ${e.toString()}'),
              backgroundColor: Colors.red));
        }
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
          TextFormField(
            controller: _licensePlateController,
            decoration: InputDecoration(
              labelText: 'Nomor Plat Kendaraan',
              hintText: 'Contoh: D 1234 ABC',
              prefixIcon: const Icon(Icons.directions_car_outlined),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              errorText: _errors['license_plate'],
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Nomor plat tidak boleh kosong' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _startKmController,
            decoration: InputDecoration(
              labelText: 'KM Awal Kendaraan',
              hintText: 'Contoh: 150000',
              prefixIcon: const Icon(Icons.speed_outlined),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              errorText: _errors['start_km'],
            ),
            keyboardType: TextInputType.number,
            validator: (value) =>
                (value == null || value.isEmpty) ? 'KM Awal tidak boleh kosong' : null,
          ),
          const SizedBox(height: 24),
          _PhotoSection(
            title: 'Foto KM Awal',
            icon: Icons.camera_alt_outlined,
            height: 150,
            errorMessage: _errors['start_km_photo'],
            onImageChanged: (file) => setState(() {
              _kmAwalImageFile = file;
              if (file != null) _errors.remove('start_km_photo');
            }),
          ),
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
  File? _suratJalanImage;
  File? _muatBarangImage;
  Map<String, String> _errors = {};

  Future<bool> validateAndSubmit() async {
    setState(() => _errors = {}); // Clear previous errors

    bool isSuratJalanPresent = _suratJalanImage != null;
    bool isMuatBarangPresent = _muatBarangImage != null;

    if (!isSuratJalanPresent) {
      _errors['delivery_letter'] = 'Foto Surat Jalan tidak boleh kosong';
    }
    if (!isMuatBarangPresent) {
      _errors['muat_photo'] = 'Foto Memuat Barang tidak boleh kosong';
    }

    if (_errors.isNotEmpty) {
      setState(() {});
      return false;
    }

    try {
      await TripService().updateAfterLoading(
        token: context.read<AuthProvider>().token!,
        tripId: widget.trip.id,
        deliveryLetter: _suratJalanImage!,
        muatPhoto: _muatBarangImage!,
      );
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        if (e.errors != null) {
          setState(() {
            _errors = e.errors!.map((key, value) => MapEntry(key, value.join(' ')));
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal mengunggah foto: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Nomor Pengiriman',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 4),
        Text('0000000${widget.trip.id}',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),
        _PhotoSection(
          title: 'Foto Surat Jalan',
          icon: Icons.document_scanner_outlined,
          errorMessage: _errors['delivery_letter'],
          onImageChanged: (file) => setState(() {
            _suratJalanImage = file;
            if (file != null) _errors.remove('delivery_letter');
          }),
        ),
        const SizedBox(height: 24),
        _PhotoSection(
          title: 'Foto Saat Memuat Barang',
          icon: Icons.inventory_2_outlined,
          errorMessage: _errors['muat_photo'],
          onImageChanged: (file) => setState(() {
            _muatBarangImage = file;
            if (file != null) _errors.remove('muat_photo');
          }),
        ),
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
  File? _bongkarBarangImage;
  File? _suratJalanAkhirImage;
  File? _kmAkhirImage;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _endKmController.dispose();
    super.dispose();
  }

  Future<bool> validateAndSubmit() async {
    setState(() => _errors = {}); // Clear previous errors

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isKmAkhirPresent = _kmAkhirImage != null;
    final isBongkarPresent = _bongkarBarangImage != null;
    final isSuratJalanPresent = _suratJalanAkhirImage != null;

    if (!isKmAkhirPresent) _errors['end_km_photo'] = 'Foto KM Akhir tidak boleh kosong';
    if (!isBongkarPresent) _errors['bongkar_photo'] = 'Foto Bongkar Barang tidak boleh kosong';
    if (!isSuratJalanPresent) _errors['delivery_letter'] = 'Foto Surat Jalan Akhir tidak boleh kosong';

    debugPrint('validateAndSubmit: isFormValid = $isFormValid, _errors.isNotEmpty = ${_errors.isNotEmpty}');
    if (!isFormValid || _errors.isNotEmpty) {
      setState(() {}); // Update UI to show error messages
      return false;
    }

    try {
      await TripService().updateFinishTrip(
        token: context.read<AuthProvider>().token!,
        tripId: widget.trip.id,
        endKm: _endKmController.text,
        endKmPhoto: _kmAkhirImage!,
        bongkarPhoto: _bongkarBarangImage!,
        deliveryLetter: _suratJalanAkhirImage!,
      );
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        if (e.errors != null) {
          setState(() {
            _errors = e.errors!.map((key, value) => MapEntry(key, value.join(' ')));
          });
        } else {
          // Show a general error message in a SnackBar for non-field-specific errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal menyelesaikan perjalanan: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nomor Pengiriman',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('0000000${widget.trip.id}',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          TextFormField(
            controller: _endKmController,
            decoration: InputDecoration(
              labelText: 'KM Akhir Kendaraan',
              hintText: 'Contoh: 150200',
              prefixIcon: const Icon(Icons.speed_outlined),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              errorText: _errors['end_km'],
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'KM Akhir tidak boleh kosong';
              }
              final int? endKm = int.tryParse(value);
              if (endKm == null) {
                return 'KM Akhir harus berupa angka';
              }
              // Ensure startKm is available for comparison
              final int? startKm = widget.trip.startKm;
              if (startKm == null) {
                return 'Data KM Awal tidak tersedia. Mohon muat ulang halaman.';
              }
              if (endKm < startKm) {
                return 'KM Akhir tidak boleh lebih kecil dari KM Awal ($startKm)';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _PhotoSection(
            title: 'Foto KM Akhir',
            icon: Icons.camera_alt_outlined,
            height: 180,
            errorMessage: _errors['end_km_photo'],
            onImageChanged: (file) => setState(() {
              _kmAkhirImage = file;
              if (file != null) _errors.remove('end_km_photo');
            }),
          ),
          const SizedBox(height: 24),
          _PhotoSection(
            title: 'Foto Bongkar Barang',
            icon: Icons.inventory_outlined,
            height: 180,
            errorMessage: _errors['bongkar_photo'],
            onImageChanged: (file) => setState(() {
              _bongkarBarangImage = file;
              if (file != null) _errors.remove('bongkar_photo');
            }),
          ),
          const SizedBox(height: 24),
          _PhotoSection(
            title: 'Foto Surat Jalan Akhir',
            icon: Icons.document_scanner_outlined,
            height: 180,
            errorMessage: _errors['delivery_letter'],
            onImageChanged: (file) => setState(() {
              _suratJalanAkhirImage = file;
              if (file != null) _errors.remove('delivery_letter');
            }),
          ),
        ],
      ),
    );
  }
}