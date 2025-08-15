// lib/utils/image_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  // Fungsi ini sekarang bersifat statis agar bisa dipanggil langsung dari mana saja
  // tanpa perlu membuat instance dari ImageHelper.
  // Contoh pemanggilan: await ImageHelper.takeGeotaggedPhoto(context);
  static Future<File?> takeGeotaggedPhoto(BuildContext context) async {
    // 1. Meminta Izin Lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Izin lokasi ditolak.'),
              backgroundColor: Colors.red));
        }
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.'),
            backgroundColor: Colors.red));
      }
      return null;
    }

    // 2. Mengambil Foto dari Kamera
    final imagePicker = ImagePicker();
    final XFile? imageFile =
        await imagePicker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (imageFile == null) return null;

    try {
      // 3. Mendapatkan Data Real-time
      final now = DateTime.now();
      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final formattedDate =
          DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(now);
      final coords =
          'Lat: ${position.latitude.toStringAsFixed(6)}, Lon: ${position.longitude.toStringAsFixed(6)}';

      // 4. Memproses Gambar
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      img.fillRect(originalImage,
          x1: 0,
          y1: originalImage.height - 65,
          x2: originalImage.width,
          y2: originalImage.height,
          color: img.ColorRgba8(0, 0, 0, 150));
      img.drawString(originalImage, '$formattedDate\n$coords',
          font: img.arial24,
          x: 10,
          y: originalImage.height - 60,
          color: img.ColorRgb8(255, 255, 255));

      // 5. Kompresi Otomatis
      int quality = 85;
      List<int> compressedBytes = img.encodeJpg(originalImage, quality: quality);
      while (compressedBytes.length > 2048 * 1024 && quality > 10) {
        quality -= 5;
        compressedBytes = img.encodeJpg(originalImage, quality: quality);
      }
      
      // 6. Menyimpan ke File Sementara dan Mengembalikannya
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath)..writeAsBytesSync(compressedBytes);

      return tempFile;

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses foto: $e')),
        );
      }
      return null;
    }
  }
}