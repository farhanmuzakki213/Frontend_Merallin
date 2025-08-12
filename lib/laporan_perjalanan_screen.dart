import 'package:flutter/material.dart';
// Untuk ImageFilter

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
        // Aksi setelah tahap terakhir selesai
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tahapan pengiriman telah selesai.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      }
      // Reset state untuk halaman selanjutnya
      setState(() {
        _swipePosition = 0;
        _isConfirmed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan Stack untuk menempatkan background gradien di belakang semua widget
      body: Stack(
        children: [
          // 1. Latar Belakang Gradien
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
                // 2. AppBar Kustom
                _buildCustomAppBar(),

                // 3. Konten Halaman dengan PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Tidak bisa di-swipe
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
                
                // 4. Tombol Geser (Swipe Button)
                _buildSwipeButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
      // bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- WIDGET BUILDER ---

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
                      backgroundColor: index <= _currentPage ? Colors.black87 : Colors.grey.shade400,
                    ),
                    if (index < _titles.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < _currentPage ? Colors.black87 : Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        const Text('SELESAI', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildPageContent(int index) {
    // Data dummy untuk setiap halaman
    Widget content;
    switch (index) {
      case 0: // MENUJU TITIK MUAT BARANG
      case 3: // MENUJU TITIK BONGKAR
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Alamat', 'Blok D1 no. 1, Komplek permata,\nJl. Permata Raya, Tanimulya, Kec. Ngamprah, Kabupaten Bandung Barat,\nJawa Barat 40552'),
            _buildInfoRow('Kontak', 'PT.Merralin Sukses Abadi'),
            _buildInfoRow('Waktu', 'Jumat, 8 Agustus 2025, 14:27'),
          ],
        );
        break;
      case 1: // MEMUAT BARANG
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Tujuan Pengantaran', 'PT.Merralin Sukses Abadi'),
            const SizedBox(height: 16),
            const Text('Keterangan', style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 8),
            _buildBulletedText('PT.Merralin Sukses Abadi'),
            _buildBulletedText('PT.Merralin Sukses Abadi'),
          ],
        );
        break;
      case 2: // SURAT JALAN
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Foto Muat Barang', style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 60, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () { /* Logika Upload */ },
              child: const Text('Upload File Surat Jalan', style: TextStyle(color: Colors.black87)),
            ),
          ],
        );
        break;
      case 4: // BONGKAR BARANG
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Tujuan Pengantaran', 'PT.Merralin Sukses Abadi'),
            const SizedBox(height: 16),
            const Text('Tujuan Pengantaran', style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 8),
            _buildBulletedText('Bongkar Barang Dari Kendaraan'),
            _buildBulletedText('Pastikan Surat Jalan Sudah Di\nTandatangani Sebelum Di Upload'),
          ],
        );
        break;
      default:
        content = const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nomor Pengiriman',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            '00000001',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }
  
  // Widget pembantu untuk baris info (label & value)
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 16)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  // Widget pembantu untuk teks dengan bullet point
  Widget _buildBulletedText(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6.0, right: 8.0),
          child: CircleAvatar(radius: 4, backgroundColor: Colors.redAccent),
        ),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16))),
      ],
    );
  }

  Widget _buildSwipeButton() {
    return Container(
      width: _swipeAreaWidth + 70, // Lebar total button
      height: _swipeButtonHeight,
      decoration: BoxDecoration(
        color: _isConfirmed ? Colors.green : const Color(0xFFFF7043), // Deep Orange
        borderRadius: BorderRadius.circular(30),
      ),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (_isConfirmed) return;
          setState(() {
            _swipePosition += details.delta.dx;
            // Batasi posisi agar tidak keluar dari container
            _swipePosition = _swipePosition.clamp(0, _swipeAreaWidth);
          });
        },
        onHorizontalDragEnd: (details) {
          if (_swipePosition > _swipeAreaWidth * 0.75) {
            _onSwipeConfirm();
          } else {
            setState(() {
              _swipePosition = 0; // Kembali ke posisi awal
            });
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Teks di tengah yang akan hilang saat dikonfirmasi
            AnimatedOpacity(
              opacity: _isConfirmed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _currentPage == _titles.length - 1 ? 'Geser Jika Sudah Selesai' : 'Geser Jika Sudah Sampai',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Teks "Confirmed!" yang muncul
            AnimatedOpacity(
              opacity: _isConfirmed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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
            // Ikon truk yang bisa digeser
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
                    color: const Color(0xFF00838F), // Cyan
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
      currentIndex: 0,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    );
  }
}