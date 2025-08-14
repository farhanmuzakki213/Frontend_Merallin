import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'models/lembur_model.dart';



class DetailLemburScreen extends StatefulWidget {
  // Menerima data lembur dari halaman sebelumnya
  final LemburRequest lemburRequest;

  const DetailLemburScreen({super.key, required this.lemburRequest});

  @override
  State<DetailLemburScreen> createState() => _DetailLemburScreenState();
}

class _DetailLemburScreenState extends State<DetailLemburScreen> {
  late String _currentStatus;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isLoading = false;
  String _loadingMessage = "";
  final ImagePicker _picker = ImagePicker();


  @override
  void initState() {
    super.initState();
    // Inisialisasi status dari data yang diterima
    _currentStatus = widget.lemburRequest.status;
  }

  @override
  void dispose() {
    // Pastikan timer dihentikan saat halaman ditutup untuk menghindari memory leak
    _timer?.cancel();
    super.dispose();
  }

  // Fungsi untuk mengambil gambar dan melanjutkan aksi (clock-in/out)
  Future<void> _takePictureAndProceed(bool isClockIn) async {
    // 1. Buka kamera untuk mengambil foto
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front, // Utamakan kamera depan
      imageQuality: 80, // Kompresi gambar agar tidak terlalu besar
    );

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengambilan gambar dibatalkan.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 2. Dapatkan timestamp dan lokasi setelah foto diambil
    setState(() {
      _isLoading = true;
      _loadingMessage = "Mendapatkan lokasi...";
    });

    final DateTime timestamp = DateTime.now();
    final Position? position = await _getCurrentLocation();

    if (position == null) {
      // Jika lokasi tidak didapat, hentikan proses dan beri tahu pengguna
      setState(() {
        _isLoading = false;
      });
      return; // Pesan error sudah ditampilkan di dalam _getCurrentLocation
    }

    // 3. Tampilkan loading dan simulasikan proses upload
    setState(() {
      _loadingMessage = "Mengunggah bukti absen...";
    });

    // --- SIMULASI UPLOAD KE BACKEND ---
    // TODO: Ganti bagian ini dengan kode untuk mengirim data ke API Laravel.
    // Data yang harus dikirim:
    // 1. image (file foto)
    // 2. timestamp (waktu absen)
    // 3. position (koordinat: position.latitude dan position.longitude)
    print("Absen Terekam: ${timestamp.toIso8601String()} di Lat: ${position.latitude}, Lon: ${position.longitude}");
    await Future.delayed(const Duration(seconds: 2)); 
    // --- AKHIR SIMULASI ---

    // 4. Lanjutkan proses clock-in atau clock-out setelah 'upload' berhasil
    if (isClockIn) {
      _performClockIn();
    } else {
      _performClockOut();
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Fungsi untuk mendapatkan lokasi terkini
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Layanan lokasi mati. Harap aktifkan GPS Anda.'), backgroundColor: Colors.red));
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izin akses lokasi ditolak.'), backgroundColor: Colors.red));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Izin lokasi ditolak permanen, tidak dapat meminta izin lagi.'), backgroundColor: Colors.red));
      return null;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }


  void _performClockIn() {
    // Aksi setelah clock-in berhasil
    setState(() {
      _currentStatus = 'Berlangsung';
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
      });
    });
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Absen mulai lembur berhasil!'), backgroundColor: Colors.green),
    );
  }

  void _performClockOut() {
    // Aksi setelah clock-out berhasil
    _timer?.cancel();
    setState(() {
      _currentStatus = 'Selesai / Menunggu Verifikasi';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lembur telah diselesaikan. Menunggu verifikasi atasan.'), backgroundColor: Colors.blue),
    );
  }

  // Format durasi dari detik menjadi HH:mm:ss
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Lembur'),
      ),
      // Gunakan Stack untuk menumpuk loading indicator di atas konten
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- KARTU INFORMASI UTAMA ---
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Status Saat Ini", style: TextStyle(fontSize: 16, color: Colors.black54)),
                            _buildStatusChip(_currentStatus),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildInfoRow(Icons.calendar_today, 'Tanggal', widget.lemburRequest.tanggal),
                        _buildInfoRow(Icons.timer, 'Rencana', '${widget.lemburRequest.jamMulai} - ${widget.lemburRequest.jamSelesai} (${widget.lemburRequest.durasi})'),
                        _buildInfoRow(Icons.work, 'Pekerjaan', widget.lemburRequest.pekerjaan),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- AREA AKSI DINAMIS ---
                _buildActionSection(),
              ],
            ),
          ),
          // --- LOADING INDICATOR ---
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(_loadingMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan bagian Aksi sesuai status
  Widget _buildActionSection() {
    switch (_currentStatus) {
      case 'Disetujui':
        return _buildClockInWidget();
      case 'Berlangsung':
        return _buildInProgressWidget();
      case 'Selesai / Menunggu Verifikasi':
        return _buildInfoCard(
          icon: Icons.check_circle_outline,
          text: 'Lembur telah selesai dan sedang menunggu verifikasi dari atasan Anda.',
          color: Colors.blue,
        );
      case 'Terverifikasi':
        return _buildInfoCard(
          icon: Icons.verified_user_outlined,
          text: 'Lembur telah diverifikasi dan akan diproses untuk pembayaran.',
          color: Colors.green,
        );
      case 'Ditolak':
        return _buildInfoCard(
          icon: Icons.cancel_outlined,
          text: 'Pengajuan lembur ini ditolak.',
          color: Colors.red,
        );
      case 'Pending':
         return _buildInfoCard(
          icon: Icons.pending_actions_outlined,
          text: 'Pengajuan lembur ini masih menunggu persetujuan dari atasan Anda.',
          color: Colors.orange,
        );
      default:
        return const SizedBox.shrink();
    }
  }
  
  // Widget untuk tombol Clock-in
  Widget _buildClockInWidget() {
    return Center(
      child: Column(
        children: [
          const Text("Anda sudah diizinkan untuk lembur.", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Silakan ambil foto selfie untuk memulai.", style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('MULAI LEMBUR (CLOCK-IN)'),
            onPressed: () => _takePictureAndProceed(true), // Panggil fungsi baru
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Widget saat lembur sedang berlangsung
  Widget _buildInProgressWidget() {
    return Column(
      children: [
        const Text("LEMBUR SEDANG BERLANGSUNG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        Text(
          _formatDuration(_elapsedSeconds),
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('SELESAIKAN LEMBUR (CLOCK-OUT)'),
          onPressed: () => _takePictureAndProceed(false), // Panggil fungsi baru
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // Widget info untuk status final (Ditolak, Selesai, dll)
  Widget _buildInfoCard({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: color.darken(0.2), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // Widget pembantu untuk baris info di kartu
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget pembantu untuk chip status
  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;
    String chipText = status;

    switch (status) {
      case 'Terverifikasi':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'Berlangsung':
         chipColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        break;
      case 'Disetujui':
        chipColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'Ditolak':
        chipColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'Selesai / Menunggu Verifikasi':
        chipColor = Colors.blueGrey.shade100;
        textColor = Colors.blueGrey.shade800;
        break;
      case 'Pending':
      default:
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        chipText = 'Pending';
        break;
    }
    return Chip(
      label: Text(chipText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
      backgroundColor: chipColor,
      side: BorderSide.none,
    );
  }
}

// Ekstensi untuk menggelapkan warna
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
