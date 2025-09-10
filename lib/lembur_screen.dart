// lib/screens/lembur_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/lembur_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'ajukan_lembur_screen.dart'; // Pastikan import ini ada
import 'detail_lembur_screen.dart';
import '../models/lembur_model.dart';

class LemburScreen extends StatefulWidget {
  const LemburScreen({super.key});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      Provider.of<LemburProvider>(context, listen: false)
          .fetchOvertimeHistory(authProvider.token!);
    } else {
      print("Token tidak ditemukan, user belum login.");
    }
  }

  // --- FUNGSI HELPER YANG DIPERBAIKI ---

  String _formatTime(String timeStr) {
    try {
      final time = TimeOfDay(
        hour: int.parse(timeStr.split(':')[0]),
        minute: int.parse(timeStr.split(':')[1]),
      );
      return time.format(context);
    } catch (e) {
      if (timeStr.length >= 5) {
        return timeStr.substring(0, 5);
      }
      return timeStr;
    }
  }

  // --- PERBAIKAN DI SINI: FUNGSI PERHITUNGAN DURASI DISESUAIKAN ---
  /// Mengkalkulasi durasi antara jam mulai dan selesai, sesuai dengan logika di halaman pengajuan.
  String _calculateDuration(String startTimeStr, String endTimeStr) {
    try {
      final now = DateTime.now();

      // Parsing string "HH:mm:ss" atau "HH:mm" menjadi DateTime
      final startHour = int.parse(startTimeStr.split(':')[0]);
      final startMinute = int.parse(startTimeStr.split(':')[1]);
      var startDateTime =
          DateTime(now.year, now.month, now.day, startHour, startMinute);

      final endHour = int.parse(endTimeStr.split(':')[0]);
      final endMinute = int.parse(endTimeStr.split(':')[1]);
      var endDateTime =
          DateTime(now.year, now.month, now.day, endHour, endMinute);

      // Jika jam selesai lebih awal dari jam mulai, berarti melewati tengah malam.
      // Tambahkan 1 hari ke waktu selesai.
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      final difference = endDateTime.difference(startDateTime);
      if (difference.isNegative) {
        return 'Jam tidak valid';
      }

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      return '$hours Jam $minutes Menit';
    } catch (e) {
      debugPrint("Error calculating duration: $e");
      return '-- Jam -- Menit';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lemburProvider = context.watch<LemburProvider>();
    
    // Cek apakah ada lembur yang sedang berlangsung
    final bool hasOngoingLembur = lemburProvider.overtimeHistory.any((lembur) {
      // Kondisi untuk "Berlangsung": status Diterima TAPI belum clock-out
      return lembur.statusLembur == StatusPersetujuan.diterima &&
             lembur.jamMulaiAktual != null &&
             lembur.jamSelesaiAktual == null;
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Lembur Saya'),
        // backgroundColor: Colors.blue,
        // foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Consumer<LemburProvider>(
        builder: (context, provider, child) {
          if (provider.historyStatus == DataStatus.loading &&
              provider.overtimeHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.historyStatus == DataStatus.error) {
            return Center(
              child: Text(
                'Gagal memuat data:\n${provider.historyMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (provider.overtimeHistory.isEmpty) {
            return _buildEmptyState();
          }
          // Tambahkan RefreshIndicator untuk fitur pull-to-refresh
          return RefreshIndicator(
              onRefresh: () async => _loadInitialData(),
              child: _buildLemburList(provider.overtimeHistory));
        },
      ),
      // Tombol ini sekarang akan bernavigasi ke AjukanLemburScreen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Jika ada lembur yang sedang berlangsung
          if (hasOngoingLembur) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Anda tidak bisa mengajukan lembur baru saat sesi lain sedang berlangsung.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Jika tidak ada, navigasi ke halaman pengajuan
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AjukanLemburScreen()),
            );
          }
        },
        label: const Text('Ajukan Lembur'),
        icon: const Icon(Icons.add_alarm),
        // Ubah warna tombol menjadi abu-abu jika disabled
        backgroundColor: hasOngoingLembur ? Colors.grey : Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildLemburList(List<Lembur> riwayatLembur) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: riwayatLembur.length,
      itemBuilder: (context, index) {
        final lembur = riwayatLembur[index];
        return _buildLemburCard(lembur);
      },
    );
  }

  Widget _buildLemburCard(Lembur lembur) {
    final formattedTanggal =
        DateFormat('d MMMM yyyy', 'id_ID').format(lembur.tanggalLembur);
    // Menggunakan fungsi format yang baru
    final jamMulai = _formatTime(lembur.mulaiJamLembur);
    final jamSelesai = _formatTime(lembur.selesaiJamLembur);
    // Menggunakan fungsi kalkulasi durasi yang baru
    final durasi =
        _calculateDuration(lembur.mulaiJamLembur, lembur.selesaiJamLembur);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLemburScreen(lemburAwal: lembur),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedTanggal,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  _buildStatusChip(lembur),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(Icons.timer_outlined, 'Durasi',
                  '$durasi ($jamMulai - $jamSelesai)'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  Icons.work_outline, 'Pekerjaan', lembur.keteranganLembur),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(Lembur lembur) {
    Color chipColor;
    Color textColor;
    String chipText;

    if (lembur.statusLembur != StatusPersetujuan.diterima) {
      // Jika belum disetujui, gunakan status persetujuan (Pending/Ditolak)
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
      // Jika sudah disetujui, cek status clock-in/out
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            const Text(
              'Riwayat Lembur Kosong',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda belum pernah mengajukan lembur. Ketuk tombol di bawah untuk membuat pengajuan baru.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
