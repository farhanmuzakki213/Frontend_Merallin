import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/history_provider.dart';
import 'package:frontend_merallin/models/attendance_history_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Gunakan objek DateTime untuk manajemen tanggal yang lebih fleksibel
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Panggil data untuk pertama kali saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoryForSelectedDate();
    });
  }

  /// Mengambil data riwayat dari API berdasarkan tanggal yang dipilih.
  void _fetchHistoryForSelectedDate() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      // Menggunakan HistoryProvider yang benar untuk mengambil data
      Provider.of<HistoryProvider>(context, listen: false)
          .getHistory(authProvider.token!, _selectedDate);
    }
  }

  /// Fungsi yang dipanggil saat pengguna memilih tanggal baru.
  void _onDateSelected(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    // Ambil data baru dari API setiap kali tanggal diganti
    _fetchHistoryForSelectedDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: Consumer<HistoryProvider>(
              builder: (context, provider, child) {
                // Menangani berbagai status dari provider
                if (provider.status == DataStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.status == DataStatus.error) {
                  return Center(child: Text('Error: ${provider.message}'));
                }
                if (provider.historyList.isEmpty) {
                  return Center(child: Text('Tidak ada riwayat untuk tanggal ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate)}.'));
                }
                // Jika sukses, tampilkan detail riwayat
                return _buildDetailedHistoryView(provider.historyList);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Membangun UI untuk memilih tanggal (date selector).
  Widget _buildDateSelector() {
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(color: Colors.blue.shade800, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2))
      ]),
      child: Column(
        children: [
          Text(monthName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final date = DateTime(_selectedDate.year, _selectedDate.month, day);
                final isSelected = day == _selectedDate.day;
                final dayName = DateFormat('E', 'id_ID').format(date);

                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: _DateCard(
                    day: day.toString(),
                    dayName: dayName,
                    isSelected: isSelected,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Membangun tampilan detail riwayat (kartu absen datang & pulang).
  Widget _buildDetailedHistoryView(List<AttendanceHistory> history) {
    final fullDayName = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate);

    final clockIn = history.firstWhere((h) => h.tipeAbsensi == 'datang', orElse: () => history.first);
    final clockOut = history.firstWhere((h) => h.tipeAbsensi == 'pulang', orElse: () => history.last);
    final hasClockOut = history.any((h) => h.tipeAbsensi == 'pulang');

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            fullDayName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
        ),
        _HistoryDetailCard(
          title: 'Absensi Datang',
          time: DateFormat('HH:mm:ss').format(clockIn.createdAt.toLocal()),
          status: clockIn.statusAbsensi,
          latitude: clockIn.latitude,
          longitude: clockIn.longitude,
        ),
        const SizedBox(height: 12),
        if (hasClockOut)
          _HistoryDetailCard(
            title: 'Absensi Pulang',
            time: DateFormat('HH:mm:ss').format(clockOut.createdAt.toLocal()),
            status: clockOut.statusAbsensi,
            latitude: clockOut.latitude,
            longitude: clockOut.longitude,
          ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  final String day;
  final String dayName;
  final bool isSelected;

  const _DateCard({
    required this.day,
    required this.dayName,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.blue.shade700,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade800 : Colors.white70,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isSelected ? Colors.blue.shade800 : Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: TextStyle(
              color: isSelected ? Colors.blue.shade900 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailCard extends StatelessWidget {
  final String title;
  final String time;
  final String status;
  final double latitude;
  final double longitude;

  const _HistoryDetailCard({
    required this.title,
    required this.time,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  /// Fungsi untuk membuka URL Google Maps dengan koordinat yang benar.
  Future<void> _launchMap() async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      debugPrint('Tidak bisa membuka peta untuk $latitude,$longitude');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'Terlambat' ? Colors.red.shade700 : Colors.green.shade700;

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.access_time_filled, 'Jam', time),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.check_circle, 'Status', status, valueColor: statusColor),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.map_outlined, 'Koordinat', '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _launchMap,
                icon: const Icon(Icons.map, color: Colors.white, size: 18),
                label: const Text('Lihat di Peta', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget helper untuk membuat baris info (ikon + label + nilai).
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}