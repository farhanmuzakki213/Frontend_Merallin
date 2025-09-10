import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Enum untuk status yang akan kita pantau secara global
enum GlobalPermissionStatus {
  checking, // Sedang memeriksa
  permissionsNeeded, // Izin aplikasi (kamera/lokasi/storage) tidak ada
  gpsServiceNeeded, // Layanan GPS mati
  allClear, // Semua prasyarat terpenuhi
}

class PermissionProvider with ChangeNotifier, WidgetsBindingObserver {
  GlobalPermissionStatus _status = GlobalPermissionStatus.checking;
  GlobalPermissionStatus get status => _status;

  PermissionProvider() {
    // Daftarkan observer dan langsung jalankan pengecekan pertama
    WidgetsBinding.instance.addObserver(this);
    _checkPrerequisites();
  }

  // Override dispose untuk membersihkan observer
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ini adalah fungsi yang akan dipanggil setiap kali app lifecycle berubah
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jika pengguna kembali ke aplikasi, cek ulang semuanya
    if (state == AppLifecycleState.resumed) {
      print("Aplikasi kembali aktif (resumed), memeriksa ulang izin dan GPS...");
      _checkPrerequisites();
    }
  }

  /// Fungsi utama untuk mengecek semua prasyarat: Izin Aplikasi & Layanan GPS.
  /// Fungsi ini akan memperbarui status provider dan memberitahu UI.
  Future<void> _checkPrerequisites() async {
    // Izin umum
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.location.status;

    // Izin penyimpanan yang bergantung pada versi Android
    PermissionStatus storageStatus;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // Android 13 (SDK 33) atau lebih baru
      if (androidInfo.version.sdkInt >= 33) {
        storageStatus = await Permission.photos.status;
      } else {
        storageStatus = await Permission.storage.status;
      }
    } else {
      // Untuk iOS atau platform lain
      storageStatus = await Permission.storage.status;
    }

    // Jika salah satu izin aplikasi tidak diberikan
    if (!cameraStatus.isGranted || !locationStatus.isGranted || !storageStatus.isGranted) {
      _updateStatus(GlobalPermissionStatus.permissionsNeeded);
      return;
    }

    // Cek layanan GPS setelah semua izin aplikasi aman
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      _updateStatus(GlobalPermissionStatus.gpsServiceNeeded);
      return;
    }

    // Jika semua pengecekan lolos
    _updateStatus(GlobalPermissionStatus.allClear);
  }

  /// Helper untuk memperbarui status dan memberitahu listener
  void _updateStatus(GlobalPermissionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
}