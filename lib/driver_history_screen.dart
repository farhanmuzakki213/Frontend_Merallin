import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../services/trip_service.dart';
import '../providers/trip_provider.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  late ScrollController _dateScrollController;
  final double _dateCardWidth = 72.0;

  DateTime _selectedDate = DateTime.now();
  DateTime _currentDisplayMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();

    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentDisplayMonth = DateTime(now.year, now.month, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
      _scrollToSelectedDate(animate: false);
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token != null) {
      await context.read<TripProvider>().fetchTrips(authProvider.token!);
    }
  }

  Map<DateTime, List<Trip>> _getGroupedCompletedTrips(TripProvider provider) {
      final completedTrips = provider.allTrips.where((trip) => trip.statusTrip == 'selesai').toList();
      final Map<DateTime, List<Trip>> tempGrouped = {};
      for (var trip in completedTrips) {
        if (trip.updatedAt == null) continue;
        final dateKey = DateTime(trip.updatedAt!.year, trip.updatedAt!.month, trip.updatedAt!.day);
        if (tempGrouped[dateKey] == null) {
          tempGrouped[dateKey] = [];
        }
        tempGrouped[dateKey]!.add(trip);
      }
      return tempGrouped;
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!_dateScrollController.hasClients || !mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final selectedDayIndex = _selectedDate.day - 1;

    double targetOffset = (selectedDayIndex * _dateCardWidth) - (screenWidth / 2) + (_dateCardWidth / 2);

    targetOffset = targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent);
    
    if (animate) {
      _dateScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _dateScrollController.jumpTo(targetOffset);
    }
  }

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
            // <-- PERBAIKAN: Gunakan Consumer untuk listen ke perubahan state
            child: Consumer<TripProvider>(
              builder: (context, tripProvider, child) {
                if (tripProvider.isLoading && tripProvider.allTrips.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tripProvider.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(tripProvider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                
                final groupedTrips = _getGroupedCompletedTrips(tripProvider);
                final tripsOnSelectedDate = groupedTrips[_selectedDate] ?? [];

                if (tripsOnSelectedDate.isEmpty) {
                  return const Center(child: Text("Tidak ada riwayat pada tanggal ini.", style: TextStyle(fontSize: 16, color: Colors.grey)));
                }

                return RefreshIndicator(
                  onRefresh: _reloadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: tripsOnSelectedDate.length,
                    itemBuilder: (context, index) {
                      final trip = tripsOnSelectedDate[index];
                      return _ExpandableTripCard(trip: trip);
                    },
                  ),
                );
              },
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _currentDisplayMonth = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_currentDisplayMonth),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () {
                    setState(() {
                       _currentDisplayMonth = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            controller: _dateScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: List.generate(DateUtils.getDaysInMonth(_currentDisplayMonth.year, _currentDisplayMonth.month), (index) {
                final day = index + 1;
                final date = DateTime(_currentDisplayMonth.year, _currentDisplayMonth.month, day);
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _scrollToSelectedDate();
                  },
                  child: _DateCard(
                    day: day.toString(),
                    dayName: DateFormat('E', 'id_ID').format(date),
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
      width: 64,
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
        mainAxisAlignment: MainAxisAlignment.center,
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
  final Trip trip;
  const _ExpandableTripCard({required this.trip});
  @override
  State<_ExpandableTripCard> createState() => _ExpandableTripCardState();
}

class _ExpandableTripCardState extends State<_ExpandableTripCard> {
  bool _isExpanded = false;

  String _capitalizeWords(String text) {
    if (text.trim().isEmpty) return text;
    return text.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
  }

  void _showNetworkImagePreview(String imageUrl) {
    if (!mounted || imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _NetworkImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

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
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.person_outline, 'Driver',
                            widget.trip.user?.name ?? 'Tidak diketahui'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.directions_car_outlined, 'NOPOL',
                            widget.trip.vehicle?.licensePlate ?? 'N/A'),
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
            child:
                _isExpanded ? _buildExpandedDetails() : const SizedBox.shrink(),
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
          _buildSectionTitle("Detail Trip"),
          _buildInfoRow(
              Icons.local_shipping_outlined, 'Tipe Trip', _capitalizeWords(widget.trip.jenisTrip ?? 'Tidak Diketahui')),
          const SizedBox(height: 10),
          // <-- PERBAIKAN: Gunakan originAddress dan destinationAddress
          _buildInfoRow(
              Icons.location_on_outlined, 'Origin', widget.trip.originAddress),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.flag_outlined, 'Destination', widget.trip.destinationAddress),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.route_outlined, 'KM Awal',
              widget.trip.startKm?.toString() ?? 'N/A'),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.route, 'KM Akhir', widget.trip.endKm?.toString() ?? 'N/A'),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.calendar_today_outlined,
              'Berangkat',
              widget.trip.createdAt != null
                  ? DateFormat('d MMM yyyy, HH:mm', 'id_ID')
                      .format(widget.trip.createdAt!)
                  : 'N/A'),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.calendar_today,
              'Selesai',
              widget.trip.updatedAt != null
                  ? DateFormat('d MMM yyyy, HH:mm', 'id_ID')
                      .format(widget.trip.updatedAt!)
                  : 'N/A'),
          const SizedBox(height: 24),
          // <-- PERBAIKAN: Tampilkan semua foto dalam satu galeri
          _buildPhotoSection("Semua Bukti Foto", widget.trip.allDocuments),
        ],
      ),
    );
  }


  Widget _buildPhotoSection(String title, List<DocumentInfo> documents) {
    final allImageUrls = documents.expand((doc) => doc.urls).toList();
    if (allImageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allImageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = allImageUrls[index];
              return GestureDetector(
                onTap: () => _showNetworkImagePreview(imageUrl),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.only(right: 10.0),
                  child: Image.network(
                    imageUrl, // Langsung gunakan URL dari model
                    fit: BoxFit.cover,
                    width: 120,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 120,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
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
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
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

class _NetworkImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const _NetworkImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}