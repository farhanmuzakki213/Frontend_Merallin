// lib/screens/detail_lembur_screen.dart

import 'dart:async';
import 'dart:io'; // Diperlukan untuk File
import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:frontend_merallin/providers/lembur_provider.dart'; // Import provider
import 'package:frontend_merallin/services/download_service.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'providers/auth_provider.dart';
import 'utils/image_absen_helper.dart';

class DetailLemburScreen extends StatefulWidget {
  final Lembur lemburAwal;

  const DetailLemburScreen({super.key, required this.lemburAwal});

  @override
  State<DetailLemburScreen> createState() => _DetailLemburScreenState();
}

class _DetailLemburScreenState extends State<DetailLemburScreen> {
  late String _currentUiStatus;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isLoading = false;
  String _loadingMessage = "";
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailsAndSetupTimer();
    });
  }

  void _fetchDetailsAndSetupTimer() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<LemburProvider>(context, listen: false);
    if (auth.token != null && widget.lemburAwal.uuid != null) {
      // Tunggu hingga data detail selesai diambil
      await provider.fetchOvertimeDetail(auth.token!, widget.lemburAwal.uuid!);
      // Setelah detail diambil, setup timer berdasarkan data terbaru dari provider
      if (mounted) {
        _setupTimer(provider.selectedLembur);
      }
    }
  }

  void _setupTimer(Lembur? lembur) {
    _timer?.cancel(); // Hentikan timer lama jika ada
    if (lembur != null && lembur.jamMulaiAktual != null && lembur.jamSelesaiAktual == null) {
      final now = DateTime.now();
      // Hitung selisih waktu dari jam mulai aktual
      final difference = now.difference(lembur.jamMulaiAktual!);
      _elapsedSeconds = difference.inSeconds;
      
      // Mulai timer baru yang berjalan setiap detik
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _downloadAndOpenFile(String url, String baseFileName) async {
    if (_isDownloading) return; // Mencegah multiple tap
    
    setState(() { _isDownloading = true; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final downloadService = DownloadService();

    try {
      showInfoSnackBar(context, 'Membuka surat lembur...');
      final fileBytes = await downloadService.fetchFileBytes(
        url: url,
        token: auth.token!,
      );

      // Membuat nama file yang lebih deskriptif
      final formattedDate = DateFormat('dd-MM-yyyy').format(widget.lemburAwal.tanggalLembur);
      final finalFileName = 'SPKL-${baseFileName.substring(0, 8)}-$formattedDate'; // Menggunakan uuid sebagai baseFileName

      // =================================================================
      // ===== PERUBAHAN UTAMA: Panggil metode saveAndOpenFile yang baru =====
      // =================================================================
      final String savedPath = await downloadService.saveAndOpenFile(
        filename: finalFileName,
        fileBytes: fileBytes,
      );

      if (mounted) {
        showInfoSnackBar(context, 'Surat lembur berhasil diunduh. Membuka file...');
      }

      // Buka file yang sudah diunduh menggunakan OpenFile
      final openResult = await OpenFilex.open(savedPath);

      if (openResult.type != ResultType.done && mounted) {
        // Tampilkan pesan jika tidak ada aplikasi PDF viewer
        showErrorSnackBar(context, 'Tidak dapat membuka file: ${openResult.message}');
      }
      
    } catch (e) {
      debugPrint('Download Lembur Error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Gagal mengunduh atau membuka file: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() { _isDownloading = false; });
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Bersihkan snackbar loading
    }
  }


  // Fungsi untuk memetakan status dari model (enum) ke status UI (string)
  String _mapModelStatusToUiStatus(StatusPersetujuan status) {
    switch (status) {
      case StatusPersetujuan.diterima:
        return 'Disetujui'; // Ini status final
      case StatusPersetujuan.ditolak:
        return 'Ditolak'; // Ini status final
      case StatusPersetujuan.menungguPersetujuan:
        return 'Pending';
      case StatusPersetujuan.menungguKonfirmasiAdmin:
        return 'Pending';
      default:
        return 'Pending';
    }
  }

  // --- LOGIKA UNTUK AMBIL FOTO & LOKASI ---
  Future<void> _takePictureAndProceed(bool isClockIn, String uuid) async {
    final provider = Provider.of<LemburProvider>(context, listen: false);
    if (provider.isActionLoading) return;

    // 2. Panggil ImageHelper untuk mengambil foto dengan timestamp & lokasi
    final imageResult = await ImageHelper.takePhotoWithLocation(context);

    // Hentikan proses jika pengguna membatalkan pengambilan foto
    if (imageResult == null) return;
    if (!mounted) return;

    // Pastikan kita mendapatkan lokasi
    if (imageResult.position == null) {
      showErrorSnackBar(context, "Gagal mendapatkan data lokasi. Mohon coba lagi.");
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    // Kirim data ke provider menggunakan hasil dari ImageHelper
    if (isClockIn) {
      success = await provider.performClockIn(
        token: auth.token!,
        uuid: uuid,
        image: imageResult.file, // <-- Gunakan imageResult.file
        position: imageResult.position!, // <-- Gunakan imageResult.position
      );
    } else {
      success = await provider.performClockOut(
        token: auth.token!,
        uuid: uuid,
        image: imageResult.file, // <-- Gunakan imageResult.file
        position: imageResult.position!, // <-- Gunakan imageResult.position
      );
    }


    // Perbarui UI berdasarkan hasil dari API
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (success) {
        showInfoSnackBar(context, provider.actionMessage ?? 'Aksi berhasil.');
        // HAPUS PANGGILAN fetchOvertimeDetail() dari sini karena provider sudah otomatis update state.
        // Cukup setup ulang timer.
        _setupTimer(provider.selectedLembur);
      } else {
        showErrorSnackBar(context, provider.actionMessage ?? 'Aksi gagal.');
      }
    }
  }


  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      showErrorSnackBar(context, 'Layanan lokasi mati. Harap aktifkan GPS Anda.');
      return null;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        showErrorSnackBar(context, 'Izin akses lokasi ditolak.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      showErrorSnackBar(context, 'Izin lokasi ditolak permanen, tidak dapat meminta izin lagi.');
      return null;
    }
    return await Geolocator.getCurrentPosition();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Lembur'),
      ),
      // Gunakan Consumer untuk mendengarkan perubahan state detail
      body: Consumer<LemburProvider>(
        builder: (context, provider, child) {
          if (provider.detailStatus == DataStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.detailStatus == DataStatus.error) {
            return Center(child: Text('Error: ${provider.detailMessage}'));
          }

          final lembur = provider.selectedLembur ?? widget.lemburAwal;

          final currentUiStatus = _mapModelStatusToUiStatus(lembur.statusLembur);
          final formattedTanggal =
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(lembur.tanggalLembur);
          final jamMulai = lembur.mulaiJamLembur.substring(0, 5);
          final jamSelesai = lembur.selesaiJamLembur.substring(0, 5);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Status Saat Ini",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black54)),
                            _buildStatusChip(lembur),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildInfoRow(Icons.calendar_today, 'Tanggal', formattedTanggal),
                        _buildInfoRow(
                            Icons.timer, 'Waktu Lembur', '$jamMulai - $jamSelesai'),
                        _buildInfoRow(
                            Icons.work, 'Pekerjaan', lembur.keteranganLembur),
                        // Tampilkan alasan jika ditolak
                        if (lembur.statusLembur == StatusPersetujuan.ditolak &&
                            lembur.alasanPenolakan != null)
                          _buildInfoRow(Icons.comment_bank_outlined, 'Alasan Penolakan', lembur.alasanPenolakan!),

                        if (lembur.jamSelesaiAktual != null)
                          _buildCompletionDetails(lembur),

                        if (lembur.statusLembur == StatusPersetujuan.diterima && lembur.fileFinalUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: OutlinedButton.icon(
                              icon: _isDownloading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.download_rounded, size: 18),
                              label: Text(_isDownloading ? 'Mengunduh...' : 'Unduh Surat Lembur'),
                              onPressed: _isDownloading
                                  ? null
                                  : () => _downloadAndOpenFile(lembur.fileFinalUrl!, lembur.uuid!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                side: BorderSide(color: Colors.blue.shade200),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildActionSection(lembur),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletionDetails(Lembur lembur) {
    final formatJam = (DateTime? time) => time != null ? DateFormat('d MMM yyyy, HH:mm:ss').format(time) : '-';
    final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Bangun waktu selesai rencana dari data lembur untuk perbandingan
    final jamSelesaiRencana = DateTime(
      lembur.tanggalLembur.year,
      lembur.tanggalLembur.month,
      lembur.tanggalLembur.day,
      int.parse(lembur.selesaiJamLembur.split(':')[0]),
      int.parse(lembur.selesaiJamLembur.split(':')[1]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        _buildInfoRow(Icons.timer_outlined, 'Waktu Mulai Lembur', formatJam(lembur.jamMulaiAktual)),
        _buildInfoRow(Icons.timer_off_outlined, 'Waktu Selesai (Aktual)', formatJam(lembur.jamSelesaiAktual)),
        _buildInfoRow(Icons.schedule, 'Waktu Selesai (Rencana)', formatJam(jamSelesaiRencana)),
        const SizedBox(height: 10),
        _buildInfoRow(
          Icons.summarize_outlined,
          'Total Durasi Dihitung',
          '${lembur.totalJam?.toStringAsFixed(2) ?? '0'} Jam'
        ),
        if (lembur.gajiLembur != null)
          _buildInfoRow(
            Icons.paid_outlined,
            'Upah Lembur',
            formatRupiah.format(lembur.gajiLembur)
          ),
      ],
    );
  }

  Widget _buildActionSection(Lembur lembur) {
    String uiStatus;
    // Cek status persetujuan dulu
    if (lembur.statusLembur != StatusPersetujuan.diterima) {
      uiStatus = _mapModelStatusToUiStatus(lembur.statusLembur);
    } 
    // Jika disetujui, cek status clock-in/out aktual
    else if (lembur.jamSelesaiAktual != null) {
      uiStatus = 'Selesai';
    } else if (lembur.jamMulaiAktual != null) {
      uiStatus = 'Berlangsung';
    } else {
      uiStatus = 'Disetujui'; // Siap untuk Clock-in
    }

    // Switch case sekarang akan menampilkan widget yang benar
    switch (uiStatus) {
      case 'Disetujui':
        final now = DateTime.now();
        // Gabungkan tanggal dan jam rencana dari data lembur
        final scheduledStart = DateTime(
          lembur.tanggalLembur.year,
          lembur.tanggalLembur.month,
          lembur.tanggalLembur.day,
          int.parse(lembur.mulaiJamLembur.split(':')[0]),
          int.parse(lembur.mulaiJamLembur.split(':')[1]),
        );

        // Cek apakah waktu sekarang sudah melewati jadwal mulai
        if (now.isBefore(scheduledStart)) {
          // Jika belum, tampilkan placeholder
          return _buildInfoCard(
            icon: Icons.hourglass_top_rounded,
            text: 'Anda bisa memulai lembur pada pukul ${DateFormat('HH:mm').format(scheduledStart)}.',
            color: Colors.blue,
          );
        } else {
          // Jika sudah, tampilkan tombol clock-in
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClockInWidget(lembur.uuid!),
            ],
          );
        }
      case 'Berlangsung':
        return _buildInProgressWidget(lembur.uuid!);
      case 'Selesai':
        return _buildInfoCard(
          icon: Icons.check_circle_outline,
          text: 'Anda telah menyelesaikan sesi lembur ini.',
          color: Colors.green,
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
          text: 'Pengajuan lembur ini masih menunggu persetujuan.',
          color: Colors.orange,
        );
    }
  }

   Widget _buildClockInWidget(String uuid) { // <-- Terima uuid
    return Center(
      child: Column(
        children: [
          // ... (teks tidak berubah)
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('MULAI LEMBUR (CLOCK-IN)'),
            // Panggil _takePictureAndProceed dengan parameter yang benar
            onPressed: () => _takePictureAndProceed(true, uuid),
            style: ElevatedButton.styleFrom(
              // ...
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildInProgressWidget(String uuid) { // <-- Terima uuid
    return Center(
      child: Column(
        children: [
          // ... (teks dan timer tidak berubah)
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('SELESAIKAN LEMBUR (CLOCK-OUT)'),
            // Panggil _takePictureAndProceed dengan parameter yang benar
            onPressed: () => _takePictureAndProceed(false, uuid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              // ...
            ),
          ),
        ],
      ),
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

  Widget _buildStatusChip(Lembur lembur) {
    Color chipColor;
    Color textColor;
    String chipText;

    // Logika ini sama persis dengan yang ada di lembur_screen.dart
    if (lembur.statusLembur != StatusPersetujuan.diterima) {
      switch (lembur.statusLembur) {
        case StatusPersetujuan.ditolak:
          chipColor = Colors.red.shade100;
          textColor = Colors.red.shade800;
          chipText = 'Ditolak';
          break;
        case StatusPersetujuan.menungguPersetujuan:
        case StatusPersetujuan.menungguKonfirmasiAdmin:
        default:
          chipColor = Colors.orange.shade100;
          textColor = Colors.orange.shade800;
          chipText = 'Pending';
          break;
      }
    } else {
      if (lembur.jamSelesaiAktual != null) {
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        chipText = 'Selesai';
      } else if (lembur.jamMulaiAktual != null) {
        chipColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        chipText = 'Berlangsung';
      } else {
        chipColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        chipText = 'Disetujui';
      }
    }
    return Chip(
      label: Text(
        chipText,
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
      ),
      backgroundColor: chipColor,
      side: BorderSide.none,
    );
  }
}