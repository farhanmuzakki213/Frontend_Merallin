import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/models/attendance_history_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedDay = DateTime.now().day;
  final String _monthName = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<AttendanceProvider>(context, listen: false).fetchHistory(token);
      }
    });
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
            child: Consumer<AttendanceProvider>(
              builder: (context, provider, child) {
                if (provider.historyStatus == DataStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.historyStatus == DataStatus.error) {
                  return Center(child: Text('Error: ${provider.historyMessage}'));
                }
                if (provider.historyList.isEmpty) {
                  return const Center(child: Text('Tidak ada riwayat absensi.'));
                }

                final allHistoryForDay = provider.historyList.where((item) {
                  return item.createdAt.day == _selectedDay;
                }).toList();
                allHistoryForDay.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                final clockIn = allHistoryForDay.isNotEmpty ? allHistoryForDay.first : null;
                final clockOut = allHistoryForDay.length > 1 ? allHistoryForDay.last : null;

                if (clockIn == null) {
                   return Center(child: Text('Tidak ada riwayat untuk tanggal $_selectedDay $_monthName.'));
                }

                return _buildDetailedHistoryView(clockIn, clockOut);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedHistoryView(AttendanceHistory clockIn, AttendanceHistory? clockOut) {
    final fullDayName = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(clockIn.createdAt.toLocal());
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            fullDayName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        _HistoryDetailCard(
          title: 'Absensi Datang',
          time: DateFormat('HH:mm:ss').format(clockIn.createdAt.toLocal()),
          status: 'Tepat Waktu',
          statusColor: Colors.green.shade700,
          locationName: 'Lokasi Tercatat',
          latitude: clockIn.latitude,
          longitude: clockIn.longitude,
        ),
        const SizedBox(height: 12),
        if (clockOut != null)
          _HistoryDetailCard(
            title: 'Absensi Pulang',
            time: DateFormat('HH:mm:ss').format(clockOut.createdAt.toLocal()),
            status: 'Sesuai Jadwal',
            statusColor: Colors.green.shade700,
            locationName: 'Lokasi Tercatat',
            latitude: clockOut.latitude,
            longitude: clockOut.longitude,
          ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Column(
        children: [
          Text(
            _monthName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: List.generate(31, (index) {
                final day = index + 1;
                final isSelected = day == _selectedDay;
                final dateForDayName = DateTime(DateTime.now().year, DateTime.now().month, day);
                final dayName = DateFormat('E', 'id_ID').format(dateForDayName);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
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
  final Color statusColor;
  final String locationName;
  final double latitude;
  final double longitude;

  const _HistoryDetailCard({
    required this.title,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  // Fungsi untuk membuka URL Google Maps
  Future<void> _launchMap() async {
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      // Sebaiknya tampilkan pesan error kepada pengguna jika gagal
      debugPrint('Tidak bisa membuka peta untuk $latitude,$longitude');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.access_time_filled, 'Jam', time),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.check_circle, 'Status', status, valueColor: statusColor),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Lokasi', locationName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.map_outlined, 'Koordinat', '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _launchMap, // Panggil fungsi saat tombol ditekan
                icon: const Icon(Icons.map, color: Colors.white, size: 18),
                label: const Text('Lihat di Peta', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk membuat baris info (ikon + label + nilai)
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