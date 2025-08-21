// lib/laporan_perjalanan_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/trip_service.dart';
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

  late Trip _currentTrip;

  final GlobalKey<_StartTripPageState> _startTripKey = GlobalKey();
  final GlobalKey<_SuratJalanPageState> _suratJalanKey = GlobalKey();
  final GlobalKey<_BuktiAkhirPageState> _buktiAkhirKey = GlobalKey();

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

  String get _swipeText {
    switch (_currentPage) {
      case 1: case 4: return 'Geser Jika Sudah Sampai';
      case 2: return 'Geser Jika Selesai Muat';
      case 3: return 'Geser Jika Foto Dikirim Semua';
      case 5: return 'Geser Jika Selesai Bongkar';
      case 6: return 'Geser Untuk Menyelesaikan';
      default: return 'Geser';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _initialPage = _determineInitialPage(_currentTrip);
    _currentPage = _initialPage;
    _pageController = PageController(initialPage: _initialPage);
  }

  int _determineInitialPage(Trip trip) {
    if (trip.statusTrip == 'selesai') return 6;
    if (trip.statusMuatan == 'selesai bongkar') return 6;
    if (trip.statusLokasi == 'di lokasi bongkar') return 5;
    if (trip.statusMuatan == 'termuat' || trip.statusLokasi == 'menuju lokasi bongkar') return 4;
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

  Future<void> _handleNextPage() async {
    if (_isSendingData) return;

    setState(() => _isSendingData = true);
    Trip? updatedTrip;

    try {
      switch (_currentPage) {
        case 0:
          updatedTrip = await _startTripKey.currentState?.validateAndSubmit();
          break;
        case 1:
          updatedTrip = await _callAPIAndGetTrip(() => TripService().updateToLoadingPoint(
              token: context.read<AuthProvider>().token!,
              tripId: _currentTrip.id));
          break;
        case 2:
          updatedTrip = await _callAPIAndGetTrip(() => TripService().finishLoading(
              token: context.read<AuthProvider>().token!,
              tripId: _currentTrip.id));
          break;
        case 3:
          updatedTrip = await _suratJalanKey.currentState?.validateAndSubmit();
          break;
        case 4:
          updatedTrip = await _callAPIAndGetTrip(() => TripService().updateToUnloadingPoint(
              token: context.read<AuthProvider>().token!,
              tripId: _currentTrip.id));
          break;
        case 5:
          updatedTrip = await _callAPIAndGetTrip(() => TripService().finishUnloading(
              token: context.read<AuthProvider>().token!,
              tripId: _currentTrip.id));
          break;
        case 6:
          updatedTrip = await _buktiAkhirKey.currentState?.validateAndSubmit();
          if (updatedTrip != null && mounted) {
            Navigator.pop(context, true);
          }
          break;
      }

      if (updatedTrip != null) {
        setState(() {
          _currentTrip = updatedTrip!;
        });
        if (_currentPage < _titles.length - 1) {
          _pageController.animateToPage(_currentPage + 1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingData = false);
      }
    }
  }

  Future<Trip?> _callAPIAndGetTrip(Future<Trip> Function() apiCall) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red));
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Terjadi kesalahan tidak terduga: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return null;
    }
  }

  void _onSwipeConfirm() async {
    if (_isSendingData) return;
    await _handleNextPage();
    if (mounted) {
      setState(() {
        _swipePosition = 0;
        _isConfirmed = false;
      });
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
        return _StartTripPage(key: _startTripKey, trip: _currentTrip);
      case 1:
      case 4:
        return _InfoDisplayPage(trip: _currentTrip, isUnloading: index == 4);
      case 2:
        return _InfoDisplayPage(
            trip: _currentTrip,
            isUnloading: false,
            keterangan: 'Muat semua barang sesuai surat jalan.');
      case 3:
        return _SuratJalanPage(key: _suratJalanKey, trip: _currentTrip);
      case 5:
        return _InfoDisplayPage(
            trip: _currentTrip,
            isUnloading: true,
            keterangan:
                'Bongkar semua barang dan pastikan surat jalan ditandatangani.');
      case 6:
        return _BuktiAkhirPage(key: _buktiAkhirKey, trip: _currentTrip);
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
              child: Text(_swipeText,
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

class _MultiPhotoSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? errorMessage;
  final ValueChanged<List<File>> onImagesChanged;

  const _MultiPhotoSection({
    required this.title,
    required this.icon,
    this.errorMessage,
    required this.onImagesChanged,
  });

  @override
  State<_MultiPhotoSection> createState() => _MultiPhotoSectionState();
}

class _MultiPhotoSectionState extends State<_MultiPhotoSection> {
  final List<File> _imageFiles = [];

  Future<void> _takePicture() async {
    // Menggunakan helper untuk mengambil & memproses foto dari kamera
    final File? newImage = await ImageHelper.takePhoto(context);
    if (newImage != null) {
      setState(() {
        _imageFiles.add(newImage);
      });
      widget.onImagesChanged(_imageFiles);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
    widget.onImagesChanged(_imageFiles);
  }

  void _showPreview(File imageFile) {
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewScreen(imageFile: imageFile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Style tombol disamakan dengan _PhotoSection
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).primaryColor)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.errorMessage != null
                    ? Colors.red
                    : Colors.grey.shade300,
                width: 1),
          ),
          child: _imageFiles.isEmpty
              ? _buildImagePickerPlaceholder()
              : _buildImageGrid(),
        ),
        if (widget.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child: Text(widget.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('Kamera'),
                style: buttonStyle, // Terapkan style
                onPressed: _takePicture,
              ),
            ),
          ],
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showPreview(_imageFiles[index]),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  _imageFiles[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
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
      },
    );
  }

  Widget _buildImagePickerPlaceholder() {
    return GestureDetector(
      onTap: _takePicture, // Default action
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
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
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

  Future<Trip?> validateAndSubmit() async {
    setState(() => _errors = {});

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isImagePresent = _kmAwalImageFile != null;

    if (!isImagePresent) {
      setState(() => _errors['start_km_photo'] = 'Foto KM Awal tidak boleh kosong');
    }

    if (isFormValid && isImagePresent) {
      try {
        final updatedTrip = await TripService().updateStartTrip(
          token: context.read<AuthProvider>().token!,
          tripId: widget.trip.id,
          licensePlate: _licensePlateController.text,
          startKm: _startKmController.text,
          startKmPhoto: _kmAwalImageFile!,
        );
        return updatedTrip;
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
        return null;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Terjadi kesalahan: ${e.toString()}'),
              backgroundColor: Colors.red));
        }
        return null;
      }
    }
    return null;
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
  List<File> _suratJalanImages = [];
  File? _muatBarangImage;
  Map<String, String> _errors = {};

  Future<Trip?> validateAndSubmit() async {
    setState(() => _errors = {});

    bool isSuratJalanPresent = _suratJalanImages.isNotEmpty;
    bool isMuatBarangPresent = _muatBarangImage != null;

    if (!isSuratJalanPresent) {
      _errors['delivery_letters'] = 'Foto Surat Jalan tidak boleh kosong';
    }
    if (!isMuatBarangPresent) {
      _errors['muat_photo'] = 'Foto Memuat Barang tidak boleh kosong';
    }

    if (_errors.isNotEmpty) {
      setState(() {});
      return null;
    }

    try {
      final updatedTrip = await TripService().updateAfterLoading(
        token: context.read<AuthProvider>().token!,
        tripId: widget.trip.id,
        deliveryLetters: _suratJalanImages,
        muatPhoto: _muatBarangImage!,
      );
      return updatedTrip;
    } on ApiException catch (e) {
      if (mounted) {
        if (e.errors != null) {
          setState(() {
            _errors = e.errors!.map((key, value) => MapEntry(key.replaceAll('.0', ''), value.join(' ')));
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal mengunggah foto: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return null;
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
        _MultiPhotoSection(
          title: 'Foto Surat Jalan',
          icon: Icons.document_scanner_outlined,
          errorMessage: _errors['delivery_letters'],
          onImagesChanged: (files) => setState(() {
            _suratJalanImages = files;
            if (files.isNotEmpty) _errors.remove('delivery_letters');
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
  List<File> _suratJalanAkhirImages = [];
  File? _kmAkhirImage;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _endKmController.dispose();
    super.dispose();
  }

  Future<Trip?> validateAndSubmit() async {
    setState(() => _errors = {});

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isKmAkhirPresent = _kmAkhirImage != null;
    final isBongkarPresent = _bongkarBarangImage != null;
    final isSuratJalanPresent = _suratJalanAkhirImages.isNotEmpty;

    if (!isKmAkhirPresent) _errors['end_km_photo'] = 'Foto KM Akhir tidak boleh kosong';
    if (!isBongkarPresent) _errors['bongkar_photo'] = 'Foto Bongkar Barang tidak boleh kosong';
    if (!isSuratJalanPresent) _errors['delivery_letters'] = 'Foto Surat Jalan Akhir tidak boleh kosong';

    if (!isFormValid || _errors.isNotEmpty) {
      setState(() {});
      return null;
    }

    try {
      final updatedTrip = await TripService().updateFinishTrip(
        token: context.read<AuthProvider>().token!,
        tripId: widget.trip.id,
        endKm: _endKmController.text,
        endKmPhoto: _kmAkhirImage!,
        bongkarPhoto: _bongkarBarangImage!,
        deliveryLetters: _suratJalanAkhirImages,
      );
      return updatedTrip;
    } on ApiException catch (e) {
      if (mounted) {
        if (e.errors != null) {
          setState(() {
            _errors = e.errors!.map((key, value) => MapEntry(key.replaceAll('.0', ''), value.join(' ')));
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal menyelesaikan perjalanan: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return null;
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
              final int? startKm = widget.trip.startKm;
              if (startKm == null) {
                return 'Data KM Awal tidak sinkron. Coba lagi.';
              }
              if (endKm <= startKm) {
                return 'KM Akhir harus lebih besar dari KM Awal ($startKm)';
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
          _MultiPhotoSection(
            title: 'Foto Surat Jalan Akhir',
            icon: Icons.document_scanner_outlined,
            errorMessage: _errors['delivery_letters'],
            onImagesChanged: (files) => setState(() {
              _suratJalanAkhirImages = files;
              if (files.isNotEmpty) _errors.remove('delivery_letters');
            }),
          ),
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