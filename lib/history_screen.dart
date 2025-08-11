import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Menyimpan tanggal yang dipilih, defaultnya tanggal 6
  int _selectedDay = 6;

  // Placeholder untuk nama hari
  final List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
        elevation: 0, // Dibuat flat agar menyatu dengan body
        automaticallyImplyLeading: false, // Menghilangkan tombol kembali
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 20),
              children: [
                _buildHistoryDetails(),
              ],
            ),
          ),
        ],
      ),
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
          const Text(
            'Agustus 2025',
            style: TextStyle(
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
                // Menggunakan _selectedDay untuk menentukan tanggal terpilih
                final isSelected = day == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    // Memperbarui state saat tanggal lain dipilih
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: _DateCard(
                    day: day.toString(),
                    // Menggunakan placeholder nama hari secara berulang
                    dayName: _dayNames[index % 7],
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

  Widget _buildHistoryDetails() {
    // Mendapatkan nama hari berdasarkan tanggal yang dipilih
    final dayName = _dayNames[(_selectedDay - 1) % 7];
    final fullDayName = {'Sen': 'Senin', 'Sel': 'Selasa', 'Rab': 'Rabu', 'Kam': 'Kamis', 'Jum': 'Jumat', 'Sab': 'Sabtu', 'Min': 'Minggu'}[dayName];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Judul tanggal diperbarui sesuai _selectedDay
            '$fullDayName, $_selectedDay Agustus 2025',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          // Data di bawah ini masih statis, namun bisa diubah
          // untuk mengambil data sesuai _selectedDay
          const _HistoryCard(
            title: 'Absensi Datang',
            time: '08:05:12',
            icon: Icons.login,
            iconColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          _LocationDetailsCard(
            location: 'Kantor Pusat, Jl. Merdeka No. 10',
            latitude: '-6.200000',
            longitude: '106.816666',
            status: 'Tepat Waktu',
            statusColor: Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          const _HistoryCard(
            title: 'Absensi Pulang',
            time: '17:30:45',
            icon: Icons.logout,
            iconColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          _LocationDetailsCard(
            location: 'Kantor Pusat, Jl. Merdeka No. 10',
            latitude: '-6.200000',
            longitude: '106.816666',
            status: 'Sesuai Jadwal',
            statusColor: Colors.green.shade700,
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
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.blue.shade700,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade800 : Colors.white70,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
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

class _HistoryCard extends StatelessWidget {
  final String title;
  final String time;
  final String? location;
  final String? status;
  final Color? statusColor;
  final IconData icon;
  final Color iconColor;

  const _HistoryCard({
    required this.title,
    required this.time,
    this.location,
    this.status,
    this.statusColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
            Row(
              children: [
                // Kolom 1 & 2: Jam dan Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.access_time_filled, 'Jam', time),
                      if (status != null && statusColor != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.check_circle, 'Status', status!, valueColor: statusColor),
                      ],
                    ],
                  ),
                ),
                // Kolom 3 & 4: Lokasi
                if (location != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildInfoRow(Icons.location_on, 'Lokasi', location!),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationDetailsCard extends StatelessWidget {
  final String location;
  final String latitude;
  final String longitude;
  final String status;
  final Color statusColor;

  const _LocationDetailsCard({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.check_circle, 'Status', status, valueColor: statusColor),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, 'Lokasi', location),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.map, 'Latitude', latitude),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.map_outlined, 'Longitude', longitude),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement map functionality
                },
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('Lihat di Peta', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
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

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}