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

  _TripData({
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

  _LocationData({
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
  });
}
// --- END DATA MODELS ---


class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  int _selectedDay = 6;
  final List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  // --- DUMMY DATA ---
  final List<_TripData> _tripHistory = [
    _TripData(
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
    _TripData(
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
  // --- END DUMMY DATA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Riwayat Perjalanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade800,
        elevation: 2,
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
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Agustus 2025',
            style: TextStyle(
              fontSize: 22,
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
      return const Center(child: Text("Tidak ada riwayat perjalanan.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 12.0),
          child: Text(
            '$fullDayName, $_selectedDay Agustus 2025',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: _tripHistory.length,
            itemBuilder: (context, index) {
              final trip = _tripHistory[index];
              return _ExpandableTripCard(trip: trip);
            },
          ),
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
                  color: Colors.teal.withOpacity(0.4),
                  spreadRadius: 2,
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
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

class _ExpandableTripCard extends StatefulWidget {
  final _TripData trip;

  const _ExpandableTripCard({required this.trip});

  @override
  State<_ExpandableTripCard> createState() => _ExpandableTripCardState();
}

class _ExpandableTripCardState extends State<_ExpandableTripCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trip.projectName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.person_outline, 'Driver', widget.trip.driverName),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.directions_car_outlined, 'NOPOL', widget.trip.nopol),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.teal.shade800,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            child: _isExpanded ? _buildExpandedDetails() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
      child: Column(
        children: [
          const Divider(height: 20, thickness: 1.5),
          _buildSectionTitle("Detail Proyek"),
          _buildInfoRow(Icons.route_outlined, 'KM Awal', widget.trip.kmAwal),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.route, 'KM Tiba', widget.trip.kmTiba),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.calendar_today_outlined, 'Berangkat', widget.trip.tanggalBerangkat),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.calendar_today, 'Sampai', widget.trip.tanggalSampai),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.info_outline, 'Keterangan', widget.trip.keterangan),
          const SizedBox(height: 24),

          _buildLocationSection(widget.trip.departure),
          const SizedBox(height: 24),
          _buildLocationSection(widget.trip.arrival),
        ],
      ),
    );
  }

  Widget _buildLocationSection(_LocationData locationData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(locationData.title),
        _buildInfoRow(Icons.location_on_outlined, 'Lokasi', locationData.location),
        const SizedBox(height: 10),
        _buildInfoRow(Icons.map_outlined, 'Koordinat', '${locationData.latitude}, ${locationData.longitude}'),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () { /* TODO: Implement map functionality for ${locationData.title} */ },
            icon: const Icon(Icons.map, color: Colors.white, size: 18),
            label: const Text('Lihat di Peta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 15,
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