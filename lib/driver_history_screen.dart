import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../services/trip_service.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  // --- STATE MANAGEMENT ---
  late final TripService _tripService;
  bool _isLoading = true;
  String? _errorMessage;

  Map<DateTime, List<Trip>> _allCompletedTripsByDate = {};
  
  // PERBAIKAN: Tambahkan ScrollController untuk date selector
  late ScrollController _dateScrollController;
  final double _dateCardWidth = 72.0; // Perkiraan lebar satu item tanggal + margin

  DateTime _selectedDate = DateTime.now();
  DateTime _currentDisplayMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tripService = TripService();
    _dateScrollController = ScrollController(); // Inisialisasi controller

    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentDisplayMonth = DateTime(now.year, now.month, 1);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _fetchAndProcessHistory(authProvider.token);

    // PERBAIKAN: Panggil fungsi scroll setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(animate: false); // Langsung lompat tanpa animasi saat awal
    });
  }

  // PERBAIKAN: Tambahkan dispose untuk controller
  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndProcessHistory(String? token) async {
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allTrips = await _tripService.getTrips(token);
      final completedTrips = allTrips.where((trip) => trip.statusTrip == 'selesai').toList();

      final Map<DateTime, List<Trip>> tempGrouped = {};
      for (var trip in completedTrips) {
        if (trip.updatedAt == null) continue;
        final dateKey = DateTime(trip.updatedAt!.year, trip.updatedAt!.month, trip.updatedAt!.day);
        if (tempGrouped[dateKey] == null) {
          tempGrouped[dateKey] = [];
        }
        tempGrouped[dateKey]!.add(trip);
      }
      
      setState(() {
        _allCompletedTripsByDate = tempGrouped;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat riwayat: ${e.toString()}';
      });
    } finally {
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // PERBAIKAN: Buat fungsi untuk menggerakkan scroll ke tanggal yang dipilih
  void _scrollToSelectedDate({bool animate = true}) {
    if (!_dateScrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final selectedDayIndex = _selectedDate.day - 1;

    // Hitung posisi target agar item berada di tengah
    double targetOffset = (selectedDayIndex * _dateCardWidth) - (screenWidth / 2) + (_dateCardWidth / 2);

    // Pastikan offset tidak kurang dari 0 atau melebihi batas scroll maksimum
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

  // --- UI BUILD METHODS ---
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
            child: _buildHistoryList(),
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
            // PERBAIKAN: Hubungkan controller ke SingleChildScrollView
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
                    // PERBAIKAN: Panggil fungsi scroll saat tanggal ditekan
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

  Widget _buildHistoryList() {
    // ... (Tidak ada perubahan di method ini)
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final tripsOnSelectedDate = _allCompletedTripsByDate[_selectedDate] ?? [];

    if (tripsOnSelectedDate.isEmpty) {
      return const Center(child: Text("Tidak ada riwayat pada tanggal ini.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: tripsOnSelectedDate.length,
      itemBuilder: (context, index) {
        final trip = tripsOnSelectedDate[index];
        return _ExpandableTripCard(trip: trip);
      },
    );
  }
}

// --- WIDGETS PENDUKUNG ---

class _DateCard extends StatelessWidget {
  // ... (Tidak ada perubahan di widget ini)
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
      width: 64, // PERBAIKAN: Beri lebar eksplisit agar perhitungan lebih konsisten
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

// ... Sisa kode untuk _ExpandableTripCard tidak perlu diubah ...
class _ExpandableTripCard extends StatefulWidget {
  final Trip trip;
  const _ExpandableTripCard({required this.trip});
  @override
  State<_ExpandableTripCard> createState() => _ExpandableTripCardState();
}

class _ExpandableTripCardState extends State<_ExpandableTripCard> {
  bool _isExpanded = false;

  String _buildFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final String sanitizedBaseUrl = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    return '$sanitizedBaseUrl/storage/$relativePath';
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
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.person_outline, 'Driver',
                            widget.trip.user?.name ?? 'Tidak diketahui'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.directions_car_outlined, 'NOPOL',
                            widget.trip.licensePlate ?? 'N/A'),
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
    final List<String> initialImagePaths = [];
    final List<String> finalImagePaths = [];

    if (widget.trip.startKmPhotoPath != null) {
      initialImagePaths.add(widget.trip.startKmPhotoPath!);
    }
    if (widget.trip.muatPhotoPath != null) {
      initialImagePaths.add(widget.trip.muatPhotoPath!);
    }
    if (widget.trip.endKmPhotoPath != null) {
      finalImagePaths.add(widget.trip.endKmPhotoPath!);
    }
    if (widget.trip.bongkarPhotoPath != null) {
      finalImagePaths.add(widget.trip.bongkarPhotoPath!);
    }

    final deliveryData = widget.trip.deliveryLetterPath;

    if (deliveryData is Map) {
      final dynamic initialLetters = deliveryData['initial_letters'];
      if (initialLetters != null && initialLetters is List) {
        initialImagePaths.addAll(initialLetters.whereType<String>());
      }

      final dynamic finalLetters = deliveryData['final_letters'];
      if (finalLetters != null && finalLetters is List) {
        finalImagePaths.addAll(finalLetters.whereType<String>());
      }
    } else if (deliveryData is List) {
      initialImagePaths.addAll(deliveryData.whereType<String>());
    } else if (deliveryData is String && deliveryData.isNotEmpty) {
      initialImagePaths.add(deliveryData);
    }

    final initialImageUrls =
        initialImagePaths.map((path) => _buildFullImageUrl(path)).toList();
    final finalImageUrls =
        finalImagePaths.map((path) => _buildFullImageUrl(path)).toList();

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
      child: Column(
        children: [
          const Divider(height: 20, thickness: 1.5),
          _buildSectionTitle("Detail Trip"),
          _buildInfoRow(
              Icons.location_on_outlined, 'Origin', widget.trip.origin),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.flag_outlined, 'Destination', widget.trip.destination),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.route_outlined, 'KM Awal',
              widget.trip.startKm?.toString() ?? 'N/A'),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.route, 'KM Tiba', widget.trip.endKm?.toString() ?? 'N/A'),
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
          _buildPhotoSection("Bukti Foto Awal", initialImageUrls),
          _buildPhotoSection("Bukti Foto Akhir", finalImageUrls),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(String title, List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.only(right: 10.0),
                child: Image.network(
                  imageUrls[index],
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
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
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