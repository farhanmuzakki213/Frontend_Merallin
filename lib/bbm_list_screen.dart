// lib/screens/bbm_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/bbm_progress_screen.dart';
import 'package:frontend_merallin/models/bbm_model.dart';
import 'package:frontend_merallin/models/vehicle_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/bbm_provider.dart';
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
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token != null) {
      await context.read<BbmProvider>().fetchBbmRequests(authProvider.token!);
    }
  }

  void _showVehicleSelectionDialog() {
    final bbmProvider = context.read<BbmProvider>();
    
    final bool hasOngoing = bbmProvider.bbmRequests.any((bbm) => bbm.derivedStatus != BbmStatus.selesai);
    if (hasOngoing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuat permintaan baru. Masih ada proses BBM yang sedang berjalan.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<BbmProvider>(
          builder: (context, provider, child) {
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
                  if (provider.vehicles.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Tidak ada kendaraan tersedia.')))
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: provider.vehicles.length,
                        itemBuilder: (context, index) {
                          final Vehicle vehicle = provider.vehicles[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Icon(Icons.directions_car_filled, color: Theme.of(context).primaryColor, size: 36),
                              title: Text(vehicle.licensePlate, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${vehicle.model} - ${vehicle.type}'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              onTap: () {
                                Navigator.pop(context);
                                _handleCreateRequest(vehicle.id); 
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
      },
    );
  }

  Future<void> _handleCreateRequest(int vehicleId) async {
    final bbmProvider = context.read<BbmProvider>();
    final authProvider = context.read<AuthProvider>();

    final newRequest = await bbmProvider.createBbmRequest(authProvider.token!, vehicleId);

    if (mounted && newRequest != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BbmProgressScreen(bbmId: newRequest.id),
        ),
      );
      if (result == true) {
        _reloadData();
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bbmProvider.errorMessage ?? 'Gagal membuat permintaan BBM.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bbmProvider = context.watch<BbmProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Isi BBM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: bbmProvider.isLoading || bbmProvider.isCreating ? null : _reloadData,
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (bbmProvider.isLoading && bbmProvider.bbmRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (bbmProvider.errorMessage != null && bbmProvider.bbmRequests.isEmpty) {
            return Center(child: Text(bbmProvider.errorMessage!));
          }
          if (bbmProvider.bbmRequests.isEmpty) {
            return RefreshIndicator(
                onRefresh: _reloadData,
                child: Stack(
                  children: [
                    Center(child: Text('Belum ada riwayat pengisian BBM.')),
                    ListView(),
                  ],
                ));
          }
          return RefreshIndicator(
            onRefresh: _reloadData,
            child: _buildBbmListView(bbmProvider.bbmRequests),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: bbmProvider.isCreating ? null : _showVehicleSelectionDialog,
        icon: bbmProvider.isCreating 
            ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
            : const Icon(Icons.add),
        label: Text(bbmProvider.isCreating ? 'Memproses...' : 'Isi BBM Baru'),
      ),
    );
  }

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
      ...requests.map((bbm) {
        if (bbm.derivedStatus == BbmStatus.selesai) {
          return _ExpandableBbmCard(bbm: bbm);
        } else {
          return _buildBbmCard(bbm);
        }
      }),
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
      case BbmStatus.revisiGambar:
        statusText = 'Ditolak/Revisi';
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default: // Selesai or other cases
        statusText = 'Selesai';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
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
              builder: (_) => BbmProgressScreen(bbmId: bbm.id),
            ),
          );
          if (result == true) {
            _reloadData();
          }
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
              if (bbm.derivedStatus == BbmStatus.revisiGambar && bbm.allRejectionReasons != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    "Catatan Revisi:\n${bbm.allRejectionReasons!}",
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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


class _ExpandableBbmCard extends StatefulWidget {
  final BbmKendaraan bbm;
  const _ExpandableBbmCard({required this.bbm});

  @override
  State<_ExpandableBbmCard> createState() => _ExpandableBbmCardState();
}

class _ExpandableBbmCardState extends State<_ExpandableBbmCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                          widget.bbm.vehicle?.licensePlate ?? 'N/A',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(widget.bbm.createdAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.teal.shade800,
                    size: 30,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),
          const Text(
            "Bukti Foto",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoItem('KM Awal', widget.bbm.fullStartKmPhotoUrl),
              const SizedBox(width: 8),
              _buildPhotoItem('KM Akhir', widget.bbm.fullEndKmPhotoUrl),
              const SizedBox(width: 8),
              _buildPhotoItem('Nota', widget.bbm.fullNotaPengisianPhotoUrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(String title, String? imageUrl) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Stack(
                      children: [
                        InteractiveViewer(child: Image.network(imageUrl)),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.error, color: Colors.red),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }
}
