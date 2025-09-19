// lib/screens/vehicle_location_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/trip_model.dart';
import 'package:frontend_merallin/models/vehicle_location_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/vehicle_location_provider.dart';
import 'package:frontend_merallin/models/vehicle_model.dart';
import 'package:frontend_merallin/vehicle_location_progress_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class VehicleLocationListScreen extends StatefulWidget {
  const VehicleLocationListScreen({super.key});

  @override
  State<VehicleLocationListScreen> createState() =>
      _VehicleLocationListScreenState();
}

class _VehicleLocationListScreenState extends State<VehicleLocationListScreen> {
  bool _dataWasChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
    });
  }

  Future<void> _reloadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token != null) {
      await context.read<VehicleLocationProvider>().fetchHistory(
            context: context,
            token: authProvider.token!,
          );
    }
  }

  Future<void> _showCreateDialog() async {
    final locationProvider = context.read<VehicleLocationProvider>();
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    await locationProvider.fetchAvailableVehicles(
      context: context,
      token: authProvider.token!,
    );
    if (mounted) Navigator.of(context).pop();

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    Vehicle? selectedVehicle;
    String? keterangan;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.add_road_rounded,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 10),
              const Text('Mulai Trip Geser Baru'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Vehicle>(
                    decoration: InputDecoration(
                      labelText: 'Pilih Kendaraan',
                      prefixIcon: const Icon(Icons.directions_car),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: locationProvider.vehicles.map((Vehicle vehicle) {
                      return DropdownMenuItem<Vehicle>(
                        value: vehicle,
                        child: Text(vehicle.licensePlate),
                      );
                    }).toList(),
                    onChanged: (Vehicle? newValue) {
                      selectedVehicle = newValue;
                    },
                    validator: (value) =>
                        value == null ? 'Kendaraan harus dipilih' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Keterangan',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      hintText: 'Contoh: Mengantar barang ke klien X',
                    ),
                    onSaved: (value) => keterangan = value,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Keterangan tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mulai'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  // ===== PERUBAHAN DI SINI =====
                  final newLocation = await locationProvider.create(
                    context: context,
                    token: authProvider.token!,
                    vehicleId: selectedVehicle!.id,
                    keterangan: keterangan!,
                  );

                  if (mounted) Navigator.of(context).pop();

                  if (newLocation != null && mounted) {
                    Navigator.of(context).pop();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleLocationProgressScreen(
                          locationId: newLocation.id,
                        ),
                      ),
                    );
                    if (result == true) {
                      setState(() {
                        _dataWasChanged = true;
                      });
                      _reloadData();
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
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
          title: const Text('Tugas Trip Geser'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataWasChanged),
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reloadData,
                tooltip: 'Muat Ulang')
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          label: const Text('Mulai Baru'),
          icon: const Icon(Icons.add),
        ),
        body: Consumer<VehicleLocationProvider>(
          builder: (context, locationProvider, child) {
            if (locationProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (locationProvider.errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${locationProvider.errorMessage}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _reloadData,
                          child: const Text('Coba Lagi'))
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
                onRefresh: _reloadData,
                child: _buildLocationList(locationProvider));
          },
        ),
      ),
    );
  }

  Widget _buildLocationList(VehicleLocationProvider provider) {
    final activeLocations = provider.history
        .where((loc) => loc.statusVehicleLocation != 'selesai')
        .toList();

    if (activeLocations.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Saat ini tidak ada tugas Trip Geser yang aktif.',
                  style: TextStyle(fontSize: 16))));
    }

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Padding for FAB
      children: [
        const Text('Tugas Aktif',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...activeLocations.map((loc) => _buildLocationCard(loc)),
      ],
    );
  }

  Widget _buildLocationCard(VehicleLocation location) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (location.derivedStatus) {
      case TripDerivedStatus.proses:
      case TripDerivedStatus.verifikasiGambar:
        statusText = 'Dalam Proses';
        statusColor = Colors.orange;
        statusIcon = Icons.alt_route;
        break;
      case TripDerivedStatus.revisiGambar:
        statusText = 'Butuh Revisi';
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
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
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      VehicleLocationProgressScreen(locationId: location.id)));
          if (result == true) {
            setState(() {
              _dataWasChanged = true;
            });
            _reloadData();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(location.keterangan ?? 'Tanpa Keterangan',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.directions_car, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(location.vehicle?.licensePlate ?? 'N/A'))
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Dibuat pada: ${DateFormat('d MMM yyyy, HH:mm').format(location.createdAt)}'))
              ]),
              const SizedBox(height: 16),
              if (location.derivedStatus == TripDerivedStatus.revisiGambar &&
                  location.allRejectionReasons != null) ...[
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
                      Text(location.allRejectionReasons!,
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
