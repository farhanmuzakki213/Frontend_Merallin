// driver_history_screen.dart

import 'package:flutter/material.dart';

// --- DATA MODELS ---
class _TripData {
  final String projectName;
  final String nopol;
  final String driverName;
  final String kmAwal;
  final String kmTiba;
  final String tanggalBerangkat;
  final String tanggalSampai;
  final String keterangan;
  final _LocationData departure;
  final _LocationData arrival;

  // OPTIMISASI: Constructor dibuat const
  const _TripData({
    required this.projectName,
    required this.nopol,
    required this.driverName,
    required this.kmAwal,
    required this.kmTiba,
    required this.tanggalBerangkat,
    required this.tanggalSampai,
    required this.keterangan,
    required this.departure,
    required this.arrival,
  });
}

class _LocationData {
  final String title;
  final String location;
  final String latitude;
  final String longitude;

  // OPTIMISASI: Constructor dibuat const
  const _LocationData({
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
  });
}
// --- AKHIR DATA MODELS ---

class DriverHistoryScreen extends StatefulWidget {
  // OPTIMISASI: Constructor dibuat const
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  int _selectedDay = 6;
  final List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  // --- DUMMY DATA ---
  // OPTIMISASI: List dibuat final dan data dibuat const
  final List<_TripData> _tripHistory = [
    const _TripData(
      projectName: 'Proyek Pengiriman A',
      nopol: 'B 1234 XYZ',
      driverName: 'Budi Santoso',
      kmAwal: '150,000 KM',
      kmTiba: '150,500 KM',
      tanggalBerangkat: '06 Agustus 2025, 08:00',
      tanggalSampai: '06 Agustus 2025, 17:30',
      keterangan: '1 Trip',
      departure: _LocationData(
        title: 'Lokasi Keberangkatan',
        location: 'Gudang A, Jakarta',
        latitude: '-6.175110',
        longitude: '106.865036',
      ),
      arrival: _LocationData(
        title: 'Lokasi Tiba',
        location: 'Gudang B, Bandung',
        latitude: '-6.917464',
        longitude: '107.619125',
      ),
    ),
    const _TripData(
      projectName: 'Proyek Pengiriman B',
      nopol: 'B 5678 ABC',
      driverName: 'Budi Santoso',
      kmAwal: '210,000 KM',
      kmTiba: '210,800 KM',
      tanggalBerangkat: '06 Agustus 2025, 09:00',
      tanggalSampai: '06 Agustus 2025, 18:30',
      keterangan: '1 Trip',
      departure: _LocationData(
        title: 'Lokasi Keberangkatan',
        location: 'Gudang C, Surabaya',
        latitude: '-7.257472',
        longitude: '112.752090',
      ),
      arrival: _LocationData(
        title: 'Lokasi Tiba',
        location: 'Gudang D, Semarang',
        latitude: '-6.966667',
        longitude: '110.416664',
      ),
    ),
  ];
  // --- AKHIR DUMMY DATA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // OPTIMISASI: Widget dibuat const
        title: const Text('Riwayat Perjalanan Driver', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade800,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: _buildHistoryDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.teal.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          )
        ],
      ),
      // OPTIMISASI: Column dibuat const
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
                final isSelected = day == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: _DateCard(
                    day: day.toString(),
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
    final dayName = _dayNames[(_selectedDay - 1) % 7];
    final fullDayName = {'Sen': 'Senin', 'Sel': 'Selasa', 'Rab': 'Rabu', 'Kam': 'Kamis', 'Jum': 'Jumat', 'Sab': 'Sabtu', 'Min': 'Minggu'}[dayName];

    if (_tripHistory.isEmpty) {
      return const Center(child: Text("Tidak ada riwayat perjalanan."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
          child: Text(
            '$fullDayName, $_selectedDay Agustus 2025',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: _tripHistory.length,
            itemBuilder: (context, index) {
              final trip = _tripHistory[index];
              return _TripDetailsGroup(trip: trip);
            },
            separatorBuilder: (context, index) {
              // OPTIMISASI: Widget dibuat const
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(
                  color: Colors.black.withOpacity(0.5),
                  thickness: 2.5,
                  indent: 2,
                  endIndent: 2,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TripDetailsGroup extends StatelessWidget {
  final _TripData trip;
  // OPTIMISASI: Constructor dibuat const
  const _TripDetailsGroup({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DriverHistoryCard(
          projectName: trip.projectName,
          nopol: trip.nopol,
          driverName: trip.driverName,
          kmAwal: trip.kmAwal,
          kmTiba: trip.kmTiba,
          tanggalBerangkat: trip.tanggalBerangkat,
          tanggalSampai: trip.tanggalSampai,
          keterangan: trip.keterangan,
        ),
        // OPTIMISASI: Widget dibuat const
        const SizedBox(height: 12),
        _LocationDetailsCard(
          title: trip.departure.title,
          location: trip.departure.location,
          latitude: trip.departure.latitude,
          longitude: trip.departure.longitude,
        ),
        // OPTIMISASI: Widget dibuat const
        const SizedBox(height: 12),
        _LocationDetailsCard(
          title: trip.arrival.title,
          location: trip.arrival.location,
          latitude: trip.arrival.latitude,
          longitude: trip.arrival.longitude,
        ),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  final String day;
  final String dayName;
  final bool isSelected;
  // OPTIMISASI: Constructor dibuat const
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
        color: isSelected ? Colors.white : Colors.teal.shade700,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.teal.shade800 : Colors.white70,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      // OPTIMISASI: Column dibuat const
      child: Column(
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isSelected ? Colors.teal.shade800 : Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: TextStyle(
              color: isSelected ? Colors.teal.shade900 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHistoryCard extends StatefulWidget {
  final String projectName;
  final String nopol;
  final String driverName;
  final String kmAwal;
  final String kmTiba;
  final String tanggalBerangkat;
  final String tanggalSampai;
  final String keterangan;
  // OPTIMISASI: Constructor dibuat const
  const _DriverHistoryCard({
    required this.projectName,
    required this.nopol,
    required this.driverName,
    required this.kmAwal,
    required this.kmTiba,
    required this.tanggalBerangkat,
    required this.tanggalSampai,
    required this.keterangan,
  });

  @override
  State<_DriverHistoryCard> createState() => _DriverHistoryCardState();
}

class _DriverHistoryCardState extends State<_DriverHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.projectName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
            ),
            const Divider(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                children: _isExpanded
                    ? [
                        _buildInfoRow(Icons.person, 'Driver', widget.driverName),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.directions_car, 'NOPOL', widget.nopol),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.route, 'KM Awal', widget.kmAwal),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.route_outlined, 'KM Tiba', widget.kmTiba),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.calendar_today, 'Berangkat', widget.tanggalBerangkat),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.calendar_today_outlined, 'Sampai', widget.tanggalSampai),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.info, 'Keterangan', widget.keterangan),
                        const SizedBox(height: 16),
                      ]
                    : [
                        _buildInfoRow(Icons.directions_car, 'NOPOL', widget.nopol),
                        const SizedBox(height: 8),
                         _buildInfoRow(Icons.person, 'Driver', widget.driverName),
                      ],
              ),
            ),
            
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.teal.shade800,
                ),
                label: Text(
                  _isExpanded ? 'Tampilkan Lebih Sedikit' : 'Lihat Detail Lengkap',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
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

class _LocationDetailsCard extends StatelessWidget {
  final String title;
  final String location;
  final String latitude;
  final String longitude;

  // OPTIMISASI: Constructor dibuat const
  const _LocationDetailsCard({
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
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
                color: Colors.teal.shade900,
              ),
            ),
            const Divider(height: 20),
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
                },
                // OPTIMISASI: Icon dan Text dibuat const
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('Lihat di Peta', 
                style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
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