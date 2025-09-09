// lib/screens/detail_lembur_screen.dart

import 'dart:async';
import 'dart:io'; // Diperlukan untuk File
import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:frontend_merallin/providers/lembur_provider.dart'; // Import provider
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import provider

class DetailLemburScreen extends StatefulWidget {
  final Lembur lembur;

  const DetailLemburScreen({super.key, required this.lembur});

  @override
  State<DetailLemburScreen> createState() => _DetailLemburScreenState();
}

class _DetailLemburScreenState extends State<DetailLemburScreen> {
  late String _currentUiStatus;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isLoading = false;
  String _loadingMessage = "";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Inisialisasi status UI dari data model yang diterima
    _currentUiStatus = _mapModelStatusToUiStatus(widget.lembur.statusLembur);
  }

  // Fungsi untuk memetakan status dari model (enum) ke status UI (string)
  String _mapModelStatusToUiStatus(StatusPersetujuan status) {
    switch (status) {
      case StatusPersetujuan.diterima:
        // Status ini memungkinkan user untuk clock-in
        return 'Disetujui'; 
      case StatusPersetujuan.ditolak:
        return 'Ditolak';
      case StatusPersetujuan.menungguPersetujuan:
      default:
        return 'Pending';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIKA UNTUK AMBIL FOTO & LOKASI ---
  Future<void> _takePictureAndProceed(bool isClockIn) async {
    // 1. Ambil Gambar
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Mendapatkan lokasi...";
    });

    // 2. Ambil Lokasi
    final DateTime timestamp = DateTime.now();
    final Position? position = await _getCurrentLocation();

    if (position == null) {
      setState(() { _isLoading = false; });
      return;
    }

    setState(() { _loadingMessage = "Mengunggah bukti absen..."; });

    // --- INTEGRASI DENGAN PROVIDER (MASA DEPAN) ---
    // TODO: Panggil method dari LemburProvider di sini untuk mengirim data ke API.
    // Anda perlu membuat method baru di service dan provider, contohnya:
    //
    // final provider = Provider.of<LemburProvider>(context, listen: false);
    // try {
    //   if (isClockIn) {
    //     await provider.performClockIn(
    //       token: 'YOUR_TOKEN',
    //       lemburId: widget.lembur.id,
    //       image: File(image.path),
    //       position: position,
    //     );
    //     _performClockIn(); // Jika sukses, update UI
    //   } else {
    //     await provider.performClockOut(
    //       token: 'YOUR_TOKEN',
    //       lemburId: widget.lembur.id,
    //       image: File(image.path),
    //       position: position,
    //     );
    //     _performClockOut(); // Jika sukses, update UI
    //   }
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
    //   );
    // }
    // --- AKHIR INTEGRASI ---
    
    // Untuk sekarang, kita lanjutkan dengan simulasi
    print("Absen Terekam: ${timestamp.toIso8601String()} di Lat: ${position.latitude}, Lon: ${position.longitude}");
    await Future.delayed(const Duration(seconds: 2));

    if (isClockIn) {
      _performClockIn();
    } else {
      _performClockOut();
    }

    setState(() { _isLoading = false; });
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Layanan lokasi mati. Harap aktifkan GPS Anda.'),
          backgroundColor: Colors.red));
      return null;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izin akses lokasi ditolak.'),
            backgroundColor: Colors.red));
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Izin lokasi ditolak permanen, tidak dapat meminta izin lagi.'),
          backgroundColor: Colors.red));
      return null;
    }
    return await Geolocator.getCurrentPosition();
  }

  void _performClockIn() {
    setState(() {
      _currentUiStatus = 'Berlangsung';
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() { _elapsedSeconds++; });
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Absen mulai lembur berhasil!'),
          backgroundColor: Colors.green),
    );
  }

  void _performClockOut() {
    _timer?.cancel();
    setState(() {
      _currentUiStatus = 'Selesai';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Lembur telah diselesaikan. Menunggu verifikasi atasan.'),
          backgroundColor: Colors.blue),
    );
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final lembur = widget.lembur;
    final formattedTanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(lembur.tanggalLembur);
    final jamMulai = lembur.mulaiJamLembur.substring(0, 5);
    final jamSelesai = lembur.selesaiJamLembur.substring(0, 5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Lembur'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            _buildStatusChip(_currentUiStatus),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildInfoRow(Icons.calendar_today, 'Tanggal', formattedTanggal),
                        _buildInfoRow(Icons.timer, 'Rencana Waktu', '$jamMulai - $jamSelesai'),
                        _buildInfoRow(Icons.work, 'Pekerjaan', lembur.keteranganLembur),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildActionSection(),
              ],
            ),
          ),
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

  Widget _buildActionSection() {
    switch (_currentUiStatus) {
      case 'Disetujui':
        return _buildClockInWidget();
      case 'Berlangsung':
        return _buildInProgressWidget();
      case 'Selesai':
        return _buildInfoCard(
          icon: Icons.check_circle_outline,
          text: 'Lembur telah selesai dan sedang menunggu verifikasi dari atasan Anda.',
          color: Colors.blue,
        );
      case 'Ditolak':
        return _buildInfoCard(
          icon: Icons.cancel_outlined,
          text: 'Pengajuan lembur ini ditolak.',
          color: Colors.red,
        );
      case 'Pending':
      default:
        return _buildInfoCard(
          icon: Icons.pending_actions_outlined,
          text: 'Pengajuan lembur ini masih menunggu persetujuan dari atasan Anda.',
          color: Colors.orange,
        );
    }
  }

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
            onPressed: () => _takePictureAndProceed(true),
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
          onPressed: () => _takePictureAndProceed(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;
    switch (status) {
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
      case 'Selesai':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'Pending':
      default:
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
    }
    return Chip(
      label: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
      backgroundColor: chipColor,
      side: BorderSide.none,
    );
  }
}