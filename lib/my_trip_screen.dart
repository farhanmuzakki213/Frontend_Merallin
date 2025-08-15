import 'package:flutter/material.dart';

import 'laporan_perjalanan_screen.dart';

class MyTripScreen extends StatelessWidget {
  const MyTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perjalanan Saya'),
        backgroundColor: Colors.blue[700],
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Tugas Aktif Anda'),
          const SizedBox(height: 12),
          _buildTripCard(
            context,
            tripId: 'TRIP-CGK-SUB-0825-1',
            origin: 'Jakarta (CGK)',
            destination: 'Surabaya (SUB)',
            status: 'Dalam Perjalanan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LaporanDriverScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildCreateTripButton(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildTripCard(
    BuildContext context, {
    required String tripId,
    required String origin,
    required String destination,
    required String status,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tripId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.flight_takeoff_outlined,
                      color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      origin,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Icon(Icons.more_vert, color: Colors.grey, size: 16),
              ),
              Row(
                children: [
                  const Icon(Icons.flight_land_outlined,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(status),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String chipText;

    switch (status) {
      case 'Dalam Perjalanan':
        chipColor = Colors.orange.shade100;
        chipText = 'Dalam Perjalanan';
        break;
      case 'Menunggu Muatan':
        chipColor = Colors.blue.shade100;
        chipText = 'Menunggu Muatan';
        break;
      case 'Selesai':
        chipColor = Colors.green.shade100;
        chipText = 'Selesai';
        break;
      default:
        chipColor = Colors.grey.shade200;
        chipText = 'Unknown';
    }

    return Chip(
      label: Text(
        chipText,
        style: const TextStyle(
            color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildCreateTripButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      label:
          const Text('Buat Trip Baru', style: TextStyle(color: Colors.white)),
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        minimumSize: const Size(double.infinity, 50),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
