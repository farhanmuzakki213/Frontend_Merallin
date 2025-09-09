// lib/services/permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// ===== MULAI KODE TAMBAHAN =====
// Impor package geolocator untuk mengecek status layanan GPS
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
// ===== AKHIR KODE TAMBAHAN =====

// ===== MULAI KODE TAMBAHAN =====
// Enum untuk mengelola status gerbang dengan lebih bersih
enum GateStatus {
  checking,
  permissionsNeeded,
  gpsServiceNeeded,
  allClear,
}
// ===== AKHIR KODE TAMBAHAN =====

class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({
    super.key,
    required this.child,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  // Menggunakan Enum untuk status
  GateStatus _gateStatus = GateStatus.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPrerequisites();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cek ulang setiap kali pengguna kembali ke aplikasi
      _checkPrerequisites();
    }
  }

  /// Fungsi utama untuk mengecek semua prasyarat: Izin & Layanan GPS
  Future<void> _checkPrerequisites() async {
    print("======================================");
    print("MEMERIKSA IZIN PADA PERANGKAT...");

    // Izin yang umum untuk semua versi
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.location.status;

    // Izin penyimpanan yang bergantung pada versi Android
    PermissionStatus storageStatus;
    if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        // Android 13 (SDK 33) atau lebih baru
        if (androidInfo.version.sdkInt >= 33) {
            // Meminta izin media (foto/video), bukan storage umum
            storageStatus = await Permission.photos.status; 
            print("Mengecek izin Foto (Android 13+)...");
        } else {
            storageStatus = await Permission.storage.status;
            print("Mengecek izin Storage (Android 12 ke bawah)...");
        }
    } else {
        // Untuk iOS atau platform lain
        storageStatus = await Permission.storage.status;
    }

    print("Status Izin Kamera: $cameraStatus");
    print("Status Izin Lokasi: $locationStatus");
    print("Status Izin Penyimpanan/Foto: $storageStatus");
    print("--------------------------------------");

    if (!cameraStatus.isGranted || !locationStatus.isGranted || !storageStatus.isGranted) {
        if (mounted) {
            print("-> KESIMPULAN: Izin tidak lengkap. Menampilkan halaman permintaan izin.");
            setState(() => _gateStatus = GateStatus.permissionsNeeded);
        }
        return;
    }

    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    print("Status Layanan GPS Aktif: $isGpsEnabled");
    if (!isGpsEnabled) {
        if (mounted) {
            print("-> KESIMPULAN: GPS mati. Menampilkan halaman permintaan GPS.");
            setState(() => _gateStatus = GateStatus.gpsServiceNeeded);
        }
        return;
    }

    if (mounted) {
        print("-> KESIMPULAN: Semua izin dan GPS aktif. Lanjut ke HomeScreen.");
        setState(() => _gateStatus = GateStatus.allClear);
    }
    print("======================================");
}

  @override
  Widget build(BuildContext context) {
    switch (_gateStatus) {
      case GateStatus.checking:
        return _buildLoadingScreen();
      case GateStatus.permissionsNeeded:
        return _buildPermissionRequestScreen();
      case GateStatus.gpsServiceNeeded:
        return _buildGpsRequestScreen(); // Tampilan baru untuk minta GPS
      case GateStatus.allClear:
        return widget.child;
    }
  }

  // Tampilan loading (tidak berubah)
  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memeriksa Izin & GPS...'),
          ],
        ),
      ),
    );
  }

  // Tampilan minta izin aplikasi (tidak berubah)
  Widget _buildPermissionRequestScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.blue[700]),
              const SizedBox(height: 20),
              const Text('Izin Aplikasi Dibutuhkan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Aplikasi ini membutuhkan izin Kamera, Lokasi, dan Penyimpanan. Mohon aktifkan di pengaturan.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Buka Pengaturan Aplikasi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => openAppSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== MULAI KODE TAMBAHAN =====
  // Widget baru untuk menampilkan layar permintaan mengaktifkan GPS
  Widget _buildGpsRequestScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 80, color: Colors.red[700]),
              const SizedBox(height: 20),
              const Text('Aktifkan GPS / Lokasi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Layanan lokasi (GPS) Anda sedang tidak aktif. Mohon aktifkan untuk melanjutkan.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Buka Pengaturan Lokasi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ===== AKHIR KODE TAMBAHAN =====
}
