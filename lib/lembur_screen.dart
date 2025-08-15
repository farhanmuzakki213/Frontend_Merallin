import 'package:flutter/material.dart';
import 'package:frontend_merallin/ajukan_lembur_screen.dart';
import 'package:frontend_merallin/detail_lembur_screen.dart';

import 'models/lembur_model.dart';


class LemburScreen extends StatefulWidget {
  const LemburScreen({super.key});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen> {
  // --- DATA DUMMY DIPERBARUI DENGAN ID ---
  final List<LemburRequest> _riwayatLembur = [
    LemburRequest(
      id: '1',
      tanggal: '13 Agustus 2025',
      jamMulai: '17:00',
      jamSelesai: '19:00',
      durasi: '2 Jam',
      pekerjaan: 'Deployment fitur baru ke server production.',
      status: 'Pending',
    ),
    LemburRequest(
      id: '2',
      tanggal: '12 Agustus 2025',
      jamMulai: '17:30',
      jamSelesai: '19:30',
      durasi: '2 Jam',
      pekerjaan: 'Menyelesaikan revisi laporan penjualan bulanan.',
      status: 'Terverifikasi',
    ),
    LemburRequest(
      id: '3',
      tanggal: '11 Agustus 2025',
      jamMulai: '17:00',
      jamSelesai: '18:00',
      durasi: '1 Jam',
      pekerjaan: 'Membantu persiapan event internal besok.',
      status: 'Disetujui',
    ),
    LemburRequest(
      id: '4',
      tanggal: '10 Agustus 2025',
      jamMulai: '18:00',
      jamSelesai: '20:00',
      durasi: '2 Jam',
      pekerjaan: 'Perbaikan bug mendesak pada sistem CRM.',
      status: 'Ditolak',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Lembur Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: _riwayatLembur.isEmpty ? _buildEmptyState() : _buildLemburList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AjukanLemburScreen()),
          );
        },
        label: const Text('Ajukan Lembur'),
        icon: const Icon(Icons.add_alarm),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildLemburList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _riwayatLembur.length,
      itemBuilder: (context, index) {
        final lembur = _riwayatLembur[index];
        return _buildLemburCard(lembur);
      },
    );
  }

  Widget _buildLemburCard(LemburRequest lembur) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLemburScreen(lemburRequest: lembur),
          ),
        );
      },
      borderRadius:
          BorderRadius.circular(12), // Agar efek riak sesuai bentuk kartu
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
                    lembur.tanggal,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  _buildStatusChip(lembur.status),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow(Icons.timer_outlined, 'Durasi',
                  '${lembur.durasi} (${lembur.jamMulai} - ${lembur.jamSelesai})'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.work_outline, 'Pekerjaan', lembur.pekerjaan),
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;
    String chipText = status;

    switch (status) {
      case 'Terverifikasi':
      case 'Selesai':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'Disetujui':
        chipColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'Ditolak':
        chipColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'Pending':
      default: // Default case akan dianggap Pending
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        chipText = 'Pending';
        break;
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
            Icon(
              Icons.history_toggle_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Riwayat Lembur Kosong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda belum pernah mengajukan lembur. Ketuk tombol \'+\' di bawah untuk membuat pengajuan baru.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}