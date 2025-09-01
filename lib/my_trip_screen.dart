// lib/my_trip_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../providers/auth_provider.dart';
import 'laporan_perjalanan_screen.dart';

class MyTripScreen extends StatefulWidget {
  const MyTripScreen({super.key});

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
    });
  }

  // <-- Muat ulang data sekarang hanya memanggil provider -->
  Future<void> _reloadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token != null) {
      // Panggil method fetch dari TripProvider
      await context.read<TripProvider>().fetchTrips(authProvider.token!);
    }
  }

  // <-- Logika accept trip dipindahkan ke provider, UI hanya memanggilnya -->
  Future<void> _handleStartTrip(int tripId) async {
    final authProvider = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();

    if (authProvider.token == null) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Memulai tugas...')));

    final success = await tripProvider.acceptTrip(authProvider.token!, tripId);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tugas berhasil dimulai!'),
          backgroundColor: Colors.green));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tripProvider.errorMessage ?? 'Gagal memulai tugas'),
          backgroundColor: Colors.red));
    }
  }

  void _showStartTripConfirmation(Trip trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Memulai Tugas'),
          content: Text(
              'Anda akan memulai perjalanan ke ${trip.destinationAddress}. Lanjutkan?'),
          actions: <Widget>[
            TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: const Text('Ya, Mulai Tugas'),
              onPressed: () {
                Navigator.of(context).pop();
                _handleStartTrip(trip.id);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Perjalanan Saya'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadData,
              tooltip: 'Muat Ulang')
        ],
      ),
      // <-- Gunakan Consumer untuk listen ke perubahan di TripProvider -->
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tripProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${tripProvider.errorMessage}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _reloadData, child: const Text('Coba Lagi'))
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
              onRefresh: _reloadData, child: _buildTripList(tripProvider));
        },
      ),
    );
  }

  Widget _buildTripList(TripProvider tripProvider) {
    // <-- Ambil data langsung dari getter provider -->
    final activeTrips = tripProvider.activeTrips;
    final availableTrips = tripProvider.availableTrips;

    if (activeTrips.isEmpty && availableTrips.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Saat ini tidak ada tugas untuk Anda.',
                  style: TextStyle(fontSize: 16))));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (activeTrips.isNotEmpty) ...[
          const Text('Tugas Aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...activeTrips
              .map((trip) => _buildTripCard(trip, true)), // true = isActive
          const SizedBox(height: 24),
        ],
        if (availableTrips.isNotEmpty) ...[
          const Text('Tugas Tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...availableTrips.map(
              (trip) => _buildTripCard(trip, false)), // false = isAvailable
        ],
      ],
    );
  }

  Widget _buildTripCard(Trip trip, bool isActive) {
    final derivedStatus = trip.derivedStatus;
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (derivedStatus) {
      case TripDerivedStatus.tersedia:
        statusText = 'Siap Dimulai';
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle_outline;
        break;
      case TripDerivedStatus.proses:
      case TripDerivedStatus.verifikasiGambar:
      case TripDerivedStatus.revisiGambar:
        statusText = 'Dalam Perjalanan';
        statusColor = Colors.orange;
        statusIcon = Icons.local_shipping_outlined;
        break;
      case TripDerivedStatus.selesai:
        statusText = 'Selesai';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusText = 'Status Tidak Dikenali';
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (!isActive) {
            // Jika trip tersedia
            final tripProvider = context.read<TripProvider>();
            bool hasActiveTrip = tripProvider.activeTrips.isNotEmpty;
            if (hasActiveTrip) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Anda sudah memiliki tugas aktif. Selesaikan terlebih dahulu.'),
                  backgroundColor: Colors.orange));
            } else {
              _showStartTripConfirmation(trip);
            }
          } else {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        LaporanDriverScreen(tripId: trip.id)));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.projectName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.my_location, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.originAddress))
              ]),
              const Padding(
                  padding: EdgeInsets.only(left: 10.0),
                  child: SizedBox(
                      height: 15, child: VerticalDivider(thickness: 1))),
              Row(children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.destinationAddress))
              ]),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Slot Time
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_outlined,
                            color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(trip.slotTime ?? 'N/A')),
                      ],
                    ),
                  ),
                  // Jenis Berat
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.scale_outlined,
                            color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(trip.jenisBerat ?? 'N/A')),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              if (derivedStatus == TripDerivedStatus.revisiGambar &&
                  trip.allRejectionReasons != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Catatan Revisi dari Admin:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800))
                      ]),
                      const SizedBox(height: 8),
                      Text(trip.allRejectionReasons!,
                          style: TextStyle(color: Colors.red.shade900)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 18),
                  label: Text(statusText,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.bold)),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor.withOpacity(0.3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
