import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionProvider with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;
  bool _isRequesting = false;

  PermissionProvider({required this.navigatorKey}) {
    WidgetsBinding.instance.addObserver(this);
    checkAndRequestPermissions();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("Aplikasi kembali aktif, memeriksa ulang semua izin...");
      checkAndRequestPermissions();
    }
  }

  // ===== PERBAIKAN 1: Kembalikan return type menjadi Future<bool> =====
  /// Memeriksa dan meminta semua izin.
  /// Mengembalikan `true` jika semua prasyarat terpenuhi, `false` jika tidak.
  Future<bool> checkAndRequestPermissions() async {
    if (_isRequesting) return false;
    _isRequesting = true;

    try {
      final statuses = await _requestCorePermissions();
      await _handlePermanentlyDenied(statuses);
      await _checkAndRequestGpsService();

      // Kembalikan status akhir setelah semua dialog selesai
      return await _arePrerequisitesMet();

    } finally {
      _isRequesting = false;
    }
  }

  // ===== PERBAIKAN 2: Kembalikan fungsi pengecekan kondisi akhir =====
  /// Mengecek apakah semua izin yang dibutuhkan dan GPS sudah aktif.
  Future<bool> _arePrerequisitesMet() async {
    final locationStatus = await Permission.location.status;
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;
    final audioStatus = await Permission.audio.status;

    PermissionStatus storageStatus;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        storageStatus = await Permission.photos.status;
      } else {
        storageStatus = await Permission.storage.status;
      }
    } else {
      storageStatus = await Permission.storage.status;
    }
    
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();

    // Kembalikan true hanya jika SEMUANYA isGranted dan GPS aktif
    return locationStatus.isGranted &&
           cameraStatus.isGranted &&
           notificationStatus.isGranted &&
           audioStatus.isGranted &&
           storageStatus.isGranted &&
           isGpsEnabled;
  }
  // ===================================================================

  Future<Map<Permission, PermissionStatus>> _requestCorePermissions() async {
    List<Permission> permissionsToRequest = [
      Permission.camera,
      Permission.location,
      Permission.notification,
      Permission.audio,
    ];

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        permissionsToRequest.add(Permission.photos);
      } else {
        permissionsToRequest.add(Permission.storage);
      }
    } else {
       permissionsToRequest.add(Permission.storage);
    }
    
    return await permissionsToRequest.request();
  }

  Future<void> _handlePermanentlyDenied(Map<Permission, PermissionStatus> statuses) async {
    final isPermanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);
    if (isPermanentlyDenied) {
      await _showFallbackDialog(
        title: 'Izin Diblokir',
        content: 'Beberapa izin aplikasi telah Anda tolak secara permanen. Agar aplikasi dapat berfungsi, mohon aktifkan izin tersebut secara manual melalui pengaturan aplikasi.',
        buttonLabel: 'Buka Pengaturan',
        onPressed: () => openAppSettings(),
      );
    }
  }

  Future<void> _checkAndRequestGpsService() async {
    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      try {
        await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 1), 
        );
      } catch (e) {
        print("Error tidak terduga saat meminta GPS: $e");
      }
    }
  }

  Future<void> _showFallbackDialog({
      required String title,
      required String content,
      required String buttonLabel,
      required VoidCallback onPressed,
  }) async {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: const Text('Nanti'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(buttonLabel),
              onPressed: () {
                onPressed();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      );
    }
  }
}