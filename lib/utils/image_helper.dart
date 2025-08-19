// lib/utils/image_helper.dart

import 'dart:io';
import 'dart:ui' as ui; // Import penting untuk Canvas dan gambar
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<File?> takeGeotaggedPhoto(BuildContext context) async {
    if (!context.mounted) return null;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 1. Izin Lokasi & Ambil Koordinat
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text("Izin lokasi diperlukan.")));
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text("Izin lokasi ditolak permanen.")));
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String addressText = "Alamat tidak ditemukan";
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addressText =
              "${p.street}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea}, ${p.postalCode}";
        }
      } catch (e) {
        debugPrint("Gagal dapat alamat: $e");
      }

      // 2. Ambil Foto dari Kamera
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (pickedFile == null) return null;

      final imageBytes = await pickedFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // 3. Siapkan Canvas untuk Menggambar
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      // 4. Gambar Foto Asli sebagai Latar Belakang
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          image: image,
          fit: BoxFit.cover);

      // 5. Siapkan Teks dan Style
      final now = DateTime.now();
      final jam = DateFormat('HH:mm').format(now);
      final tanggal = DateFormat('dd/MM/yyyy').format(now);
      final hari = DateFormat('EEEE', 'id_ID').format(now);
      
      
      const double margin = 100.0; // Margin dari tepi kiri
      const shadow = [
        Shadow(color: Colors.black87, offset: Offset(8, 8), blurRadius: 10.0)
      ];

      // Definisikan semua style di sini dengan UKURAN SANGAT BESAR
      const timeStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 300, // DIUBAH: Ukuran font lebih besar lagi
          color: Colors.white,
          shadows: shadow);

      const dateStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 160, // DIUBAH: Ukuran font lebih besar lagi
          color: Colors.white,
          shadows: shadow);

      const addressStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.normal,
          fontSize: 120, // DIUBAH: Ukuran font lebih besar lagi
          color: Colors.white,
          shadows: shadow);

      // Helper untuk menggambar teks dengan posisi spesifik
      void paintText(String text, Offset offset, TextStyle style) {
        final textSpan = TextSpan(text: text, style: style);
        final textPainter =
            TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr)
              ..layout(maxWidth: image.width - (margin * 2)); // Beri batas lebar
        textPainter.paint(canvas, offset);
      }
      
      // 6. Gambar Teks di atas Canvas (POSISI DI BAGIAN BAWAH)
      // Jarak antar baris disesuaikan dengan ukuran font baru
      final double jamY = image.height - 1100;
      final double tanggalY = jamY + 330;
      final double hariY = tanggalY + 190;
      final double addressY = hariY + 190;

      paintText(jam, Offset(margin, jamY), timeStyle);
      paintText(tanggal, Offset(margin, tanggalY), dateStyle);
      paintText(hari, Offset(margin, hariY), dateStyle);
      paintText(addressText, Offset(margin, addressY), addressStyle);

      // 7. Simpan Hasil Canvas ke File Baru
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final outputFile = File("${dir.path}/geotagged_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await outputFile.writeAsBytes(buffer);

      return outputFile;

    } catch (e) {
      debugPrint("Error saat memproses foto: $e");
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Gagal memproses foto: $e")),
        );
      }
      return null;
    }
  }
}