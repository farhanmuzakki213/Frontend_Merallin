// lib/bbm_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/bbm_progress_screen.dart';
import 'package:frontend_merallin/models/bbm_model.dart';
import 'package:frontend_merallin/models/vehicle_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/bbm_provider.dart';
import 'package:frontend_merallin/services/vehicle_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BbmListScreen extends StatefulWidget {
  const BbmListScreen({super.key});

  @override
  State<BbmListScreen> createState() => _BbmListScreenState();
}

class _BbmListScreenState extends State<BbmListScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
    });
  }

  Future<void> _reloadData() async {
    // Gunakan context provider di luar async gap jika memungkinkan
    final provider = context.read<BbmProvider>();
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      await provider.fetchBbmRequests(token);
    }
  }

  void _showVehicleSelectionDialog() async {
    // 1. Pindahkan semua yang butuh context ke atas sebelum await
    final authProvider = context.read<AuthProvider>();
    final bbmProvider = context.read<BbmProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // --- FITUR BARU: Cek jika ada proses yang sedang berjalan ---
    final bool hasOngoing = bbmProvider.bbmRequests.any((bbm) => bbm.derivedStatus != BbmStatus.selesai);
    if (hasOngoing) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuat permintaan baru. Masih ada proses BBM yang sedang berjalan.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final vehicleService = VehicleService();
      final vehicles = await vehicleService.getVehicles(authProvider.token!);
      navigator.pop(); // Tutup dialog loading

      // Jangan gunakan context setelah await tanpa cek `mounted`
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Kendaraan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                if (vehicles.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Tidak ada kendaraan tersedia.')))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final Vehicle vehicle = vehicles[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(Icons.directions_car_filled, color: Theme.of(context).primaryColor, size: 36),
                            title: Text(vehicle.licensePlate, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${vehicle.model ?? "-"} - ${vehicle.type ?? "-"}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () async {
                              // 2. Gunakan variabel yang sudah disimpan sebelumnya
                              final sheetNavigator = Navigator.of(context);
                              sheetNavigator.pop(); // Tutup bottom sheet

                              final newRequest = await bbmProvider.createBbmRequest(authProvider.token!, vehicle.id);
                              
                              if (newRequest != null) {
                                // Gunakan navigator yang aman
                                final result = await navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => BbmProgressScreen(bbmId: newRequest.id),
                                  ),
                                );
                                if (result == true) {
                                  _reloadData();
                                }
                              } else {
                                messenger.showSnackBar(SnackBar(
                                  content: Text(bbmProvider.errorMessage ?? 'Gagal membuat permintaan BBM.'),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      // Gunakan navigator yang aman
      navigator.pop(); // Tutup dialog loading jika error
      messenger.showSnackBar(SnackBar(
        content: Text('Gagal memuat kendaraan: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Isi BBM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadData,
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: Consumer<BbmProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.bbmRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }
          if (provider.bbmRequests.isEmpty) {
            return const Center(child: Text('Belum ada riwayat pengisian BBM.'));
          }
          // Panggil widget baru untuk membangun list
          return RefreshIndicator(
            onRefresh: _reloadData,
            child: _buildBbmListView(provider.bbmRequests),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showVehicleSelectionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Isi BBM Baru'),
      ),
    );
  }

  // --- WIDGET BARU: Untuk memisahkan list ---
  Widget _buildBbmListView(List<BbmKendaraan> requests) {
    final ongoing = requests.where((r) => r.derivedStatus != BbmStatus.selesai).toList();
    final finished = requests.where((r) => r.derivedStatus == BbmStatus.selesai).toList();

    return ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        if (ongoing.isNotEmpty)
          ..._buildSection('Proses Pengerjaan', ongoing),
        
        if (finished.isNotEmpty)
          ..._buildSection('Riwayat Selesai', finished),
      ],
    );
  }

  List<Widget> _buildSection(String title, List<BbmKendaraan> requests) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
      ...requests.map((bbm) => _buildBbmCard(bbm)),
    ];
  }

  Widget _buildBbmCard(BbmKendaraan bbm) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (bbm.derivedStatus) {
      case BbmStatus.proses:
        statusText = 'Proses Pengisian';
        statusColor = Colors.orange;
        statusIcon = Icons.local_gas_station;
        break;
      case BbmStatus.verifikasiGambar:
        statusText = 'Menunggu Verifikasi';
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_top;
        break;
      case BbmStatus.selesai:
        statusText = 'Selesai';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case BbmStatus.ditolak:
        statusText = 'Ditolak/Revisi';
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BbmProgressScreen(bbmId: bbm.id),
            ),
          ).then((value) {
            // Reload data jika ada kemungkinan perubahan dari layar progress
            _reloadData();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bbm.vehicle?.licensePlate ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(bbm.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 18),
                  label: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
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