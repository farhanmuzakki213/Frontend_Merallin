import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Main screen widget
class LaporanDriverScreen extends StatefulWidget {
  const LaporanDriverScreen({super.key});

  @override
  State<LaporanDriverScreen> createState() => _LaporanDriverScreenState();
}

class _LaporanDriverScreenState extends State<LaporanDriverScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // State untuk animasi swipe button
  double _swipePosition = 0.0;
  bool _isConfirmed = false;
  final double _swipeButtonHeight = 60.0;
  final double _swipeAreaWidth = 280.0; // Perkiraan lebar area geser

  final List<String> _titles = [
    'MULAI PERJALANAN',
    'MENUJU TITIK MUAT BARANG',
    'MEMUAT BARANG',
    'SURAT JALAN',
    'MENUJU TITIK BONGKAR',
    'BONGKAR BARANG',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changePage(int newPage) {
    if (newPage >= 0 && newPage < _titles.length) {
      _pageController.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSwipeConfirm() {
    setState(() => _isConfirmed = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_currentPage < _titles.length - 1) {
        _changePage(_currentPage + 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tahapan pengiriman telah selesai.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
      setState(() {
        _swipePosition = 0;
        _isConfirmed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _titles.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPageContent(index);
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
        ],
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
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
                onPressed: () {
                  if (_currentPage == 0) {
                    Navigator.of(context).pop();
                  } else {
                    _changePage(_currentPage - 1);
                  }
                },
              ),
              Text(
                _titles[_currentPage],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _currentPage == _titles.length - 1
                      ? Colors.grey.withOpacity(0.5)
                      : Colors.black54,
                ),
                onPressed: _currentPage == _titles.length - 1
                    ? null
                    : () => _changePage(_currentPage + 1),
              ),
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
                          : Colors.grey.shade400,
                    ),
                    if (index < _titles.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < _currentPage
                              ? Colors.black87
                              : Colors.grey.shade400,
                        ),
                      ),
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

  Widget _buildPageContent(int index) {
    Widget pageSpecificContent;
    switch (index) {
      case 0:
        return _StartTripPage(
          onStartTrip: () {
            _changePage(1);
          },
        );
      case 1: // MENUJU TITIK MUAT BARANG
      case 4: // MENUJU TITIK BONGKAR
        pageSpecificContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Alamat',
                'Blok D1 no. 1, Komplek permata,\nJl. Permata Raya, Tanimulya, Kec. Ngamprah, Kabupaten Bandung Barat,\nJawa Barat 40552'),
            _buildInfoRow('Kontak', 'PT.Merralin Sukses Abadi'),
            _buildInfoRow('Waktu', 'Jumat, 8 Agustus 2025, 14:27'),
          ],
        );
        break;
      case 2: // MEMUAT BARANG
        pageSpecificContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Tujuan Pengantaran', 'PT.Merralin Sukses Abadi'),
            const SizedBox(height: 16),
            const Text('Keterangan',
                style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 8),
            _buildBulletedText('PT.Merralin Sukses Abadi'),
            _buildBulletedText('PT.Merralin Sukses Abadi'),
          ],
        );
        break;
      case 3: // SURAT JALAN
        pageSpecificContent = const _SuratJalanPage();
        break;
      case 5: // BONGKAR BARANG
        pageSpecificContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Tujuan Pengantaran', 'PT.Merralin Sukses Abadi'),
            const SizedBox(height: 16),
            const Text('Tujuan Pengantaran',
                style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 8),
            _buildBulletedText('Bongkar Barang Dari Kendaraan'),
            _buildBulletedText(
                'Pastikan Surat Jalan Sudah Di\nTandatangani Sebelum Di Upload'),
          ],
        );
        break;
      default:
        pageSpecificContent = const SizedBox.shrink();
    }

    // Common card layout for pages 1 and onwards
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nomor Pengiriman',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                '00000001',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              pageSpecificContent, // Page-specific content is injected here
            ],
          ),
        ),
      ),
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

  Widget _buildBulletedText(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6.0, right: 8.0),
          child: CircleAvatar(radius: 4, backgroundColor: Colors.redAccent),
        ),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16))),
      ],
    );
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
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _changePage(1);
          },
          borderRadius: BorderRadius.circular(30),
          child: const Center(
            child: Text(
              'MULAI PERJALANAN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
        borderRadius: BorderRadius.circular(30),
      ),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (_isConfirmed) return;
          setState(() {
            _swipePosition += details.delta.dx;
            _swipePosition = _swipePosition.clamp(0, _swipeAreaWidth);
          });
        },
        onHorizontalDragEnd: (details) {
          if (_swipePosition > _swipeAreaWidth * 0.75) {
            _onSwipeConfirm();
          } else {
            setState(() {
              _swipePosition = 0;
            });
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
                  fontSize: 16,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _isConfirmed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Confirmed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.check, color: Colors.green, size: 16),
                  )
                ],
              ),
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
                    borderRadius: BorderRadius.circular(30),
                  ),
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

class _StartTripPage extends StatefulWidget {
  final VoidCallback onStartTrip;
  const _StartTripPage({super.key, required this.onStartTrip});

  @override
  State<_StartTripPage> createState() => _StartTripPageState();
}

class _StartTripPageState extends State<_StartTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _startKmController = TextEditingController();
  File? _imageFile;

  Future<void> _takePicture() async {
    final imageFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 600,
    );

    if (imageFile != null) {
      setState(() {
        _imageFile = File(imageFile.path);
      });
    }
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    _startKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Lengkapi Data Awal Perjalanan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
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
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nomor plat tidak boleh kosong';
                    }
                    return null;
                  },
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
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'KM Awal tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Foto KM Awal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 150,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade400, width: 1.5),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 50,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Ketuk untuk mengambil foto',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: Icon(_imageFile == null
                          ? Icons.camera_alt_outlined
                          : Icons.replay_outlined),
                      label: Text(_imageFile == null
                          ? 'Ambil Foto Surat Jalan'
                          : 'Ambil Ulang Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _takePicture,
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

class _SuratJalanPage extends StatefulWidget {
  const _SuratJalanPage({super.key});

  @override
  State<_SuratJalanPage> createState() => _SuratJalanPageState();
}

class _SuratJalanPageState extends State<_SuratJalanPage> {
  File? _imageFile;

  Future<void> _takePicture() async {
    final imageFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 800, // Higher resolution for documents
    );

    if (imageFile != null) {
      setState(() {
        _imageFile = File(imageFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Foto Surat Jalan',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _takePicture,
          child: Container(
            height: 250, // Taller for documents
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit
                          .contain, // Use contain to see the whole document
                    )
                  : null,
            ),
            child: _imageFile == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          size: 60,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ketuk untuk memindai surat jalan',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: Icon(_imageFile == null
              ? Icons.camera_alt_outlined
              : Icons.replay_outlined),
          label: Text(_imageFile == null
              ? 'Ambil Foto Surat Jalan'
              : 'Ambil Ulang Foto'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Theme.of(context).primaryColor),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _takePicture,
        ),
      ],
    );
  }
}
