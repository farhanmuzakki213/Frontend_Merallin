// lib/my_trip_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';
import '../services/trip_service.dart';
import '../providers/auth_provider.dart';
import 'laporan_perjalanan_screen.dart';

class MyTripScreen extends StatefulWidget {
  const MyTripScreen({super.key});

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  final TripService _tripService = TripService();

  bool _isLoading = true;
  String? _error;
  List<Trip> _trips = [];
  bool _dataWasChanged = false; // Flag to track data changes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
    });
  }

  Future<void> _reloadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final User? currentUser = authProvider.user;

    if (authProvider.token == null || currentUser == null) {
      if (mounted) setState(() { _error = 'Sesi tidak valid. Silakan login kembali.'; _isLoading = false; });
      return;
    }

    try {
      final allTrips = await _tripService.getTrips(authProvider.token!);
      if (mounted) {
        final myTrips = allTrips.where((trip) => trip.userId == currentUser.id).toList();
        setState(() { 
          _trips = myTrips; 
          _isLoading = false; 
          _dataWasChanged = true; // Mark data as potentially changed
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = 'Gagal memuat data: ${e.toString()}'; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Terjadi kesalahan tidak terduga: ${e.toString()}'; _isLoading = false; });
    }
  }

  void _showStartTripConfirmation(Trip trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Memulai Tugas'),
          content: Text('Anda akan memulai perjalanan ke ${trip.destination}. Lanjutkan?'),
          actions: <Widget>[
            TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(context).pop()),
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

  Future<void> _handleStartTrip(int tripId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memulai tugas...')));
    try {
      await _tripService.acceptTrip(authProvider.token!, tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas berhasil dimulai!'), backgroundColor: Colors.green));
        _reloadData();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memulai tugas: ${e.toString()}'), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan tidak terduga: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataWasChanged);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tugas Perjalanan Saya'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataWasChanged),
          ),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reloadData, tooltip: 'Muat Ulang')],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _reloadData, child: const Text('Coba Lagi'))
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: _reloadData, child: _buildTripList());
  }

  Widget _buildTripList() {
    final activeTrips = _trips.where((trip) => trip.derivedStatus != TripDerivedStatus.selesai && trip.derivedStatus != TripDerivedStatus.tersedia).toList();
    final availableTrips = _trips.where((trip) => trip.derivedStatus == TripDerivedStatus.tersedia).toList();
    
    if (activeTrips.isEmpty && availableTrips.isEmpty) {
       return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Saat ini tidak ada tugas untuk Anda.', style: TextStyle(fontSize: 16))));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (activeTrips.isNotEmpty) ...[
          const Text('Tugas Aktif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...activeTrips.map((trip) => _buildTripCard(trip)),
          const SizedBox(height: 24),
        ],
        if (availableTrips.isNotEmpty) ...[
          const Text('Tugas Tersedia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...availableTrips.map((trip) => _buildTripCard(trip)),
        ],
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
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
          if (derivedStatus == TripDerivedStatus.tersedia) {
            bool hasActiveTrip = _trips.any((t) => t.derivedStatus != TripDerivedStatus.selesai && t.derivedStatus != TripDerivedStatus.tersedia);
            if (hasActiveTrip) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda sudah memiliki tugas aktif. Selesaikan terlebih dahulu.'), backgroundColor: Colors.orange));
            } else {
              _showStartTripConfirmation(trip);
            }
          } else if (derivedStatus == TripDerivedStatus.proses ||
                     derivedStatus == TripDerivedStatus.revisiGambar ||
                     derivedStatus == TripDerivedStatus.verifikasiGambar) {
              
              // Hapus pengiriman parameter initialPage
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => LaporanDriverScreen(tripId: trip.id)));
              if(result == true) {
                _reloadData();
              }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [const Icon(Icons.my_location, color: Colors.blue, size: 20), const SizedBox(width: 8), Expanded(child: Text(trip.origin))]),
              const Padding(padding: EdgeInsets.only(left: 10.0), child: SizedBox(height: 15, child: VerticalDivider(thickness: 1))),
              Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(trip.destination))]),
              const SizedBox(height: 16),
              if (derivedStatus == TripDerivedStatus.revisiGambar && trip.allRejectionReasons != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.info_outline, color: Colors.red.shade700, size: 18), const SizedBox(width: 8), Text('Catatan Revisi dari Admin:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800))]),
                      const SizedBox(height: 8),
                      Text(trip.allRejectionReasons!, style: TextStyle(color: Colors.red.shade900)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 18),
                  label: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
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