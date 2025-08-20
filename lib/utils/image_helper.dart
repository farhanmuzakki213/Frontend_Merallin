// lib/utils/image_helper.dart

import 'dart:io';
import 'dart:ui' as ui; // Import penting untuk Canvas dan gambar
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

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
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (pickedFile == null) return null;

      File imageFile = File(pickedFile.path);

      // 3. Kompres Gambar sebelum diproses lebih lanjut
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");

      var compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 1080,
        minHeight: 1920,
        quality: 80,
      );
      
      if (compressedBytes == null) {
        throw Exception("Gagal mengkompres gambar");
      }

      final imageBytes = compressedBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // 4. Siapkan Canvas untuk Menggambar
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      // 5. Gambar Foto Asli sebagai Latar Belakang
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          image: image,
          fit: BoxFit.cover);

      // 6. Siapkan Teks dan Style dengan ukuran dari referensi
      final now = DateTime.now();
      final jam = DateFormat('HH:mm').format(now);
      final tanggal = DateFormat('dd/MM/yyyy').format(now);
      final hari = DateFormat('EEEE', 'id_ID').format(now);
      
      const double margin = 40.0;
      const shadow = [
        Shadow(color: Colors.black87, offset: Offset(2, 2), blurRadius: 4.0)
      ];

      // Menggunakan ukuran font HARDCODED dari referensi
      const timeStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 200,
          color: Colors.white,
          shadows: shadow);

      const dateStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 120,
          color: Colors.white,
          shadows: shadow);

      const addressStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.normal,
          fontSize: 100,
          color: Colors.white,
          shadows: shadow);

      // Helper untuk menggambar teks
      TextPainter createTextPainter(String text, TextStyle style) {
        final textSpan = TextSpan(text: text, style: style);
        return TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: image.width - (margin * 2));
      }

      final jamPainter = createTextPainter(jam, timeStyle);
      final tanggalPainter = createTextPainter(tanggal, dateStyle);
      final hariPainter = createTextPainter(hari, dateStyle);
      final addressPainter = createTextPainter(addressText, addressStyle);

      // 7. Gambar Teks di atas Canvas (POSISI DI BAGIAN BAWAH - dinamis)
      final double addressY = image.height - margin - addressPainter.height;
      final double hariY = addressY - 10 - hariPainter.height;
      final double tanggalY = hariY - 10 - tanggalPainter.height;
      final double jamY = tanggalY - 15 - jamPainter.height;

      jamPainter.paint(canvas, Offset(margin, jamY));
      tanggalPainter.paint(canvas, Offset(margin, tanggalY));
      hariPainter.paint(canvas, Offset(margin, hariY));
      addressPainter.paint(canvas, Offset(margin, addressY));

      // 8. Simpan Hasil Canvas ke File Baru
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);
      final pngBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes == null) {
        throw Exception("Gagal mengonversi gambar ke PNG");
      }

      // Kompresi dari PNG bytes ke JPEG bytes
      final jpegBytes = await FlutterImageCompress.compressWithList(
        pngBytes.buffer.asUint8List(),
        minWidth: 1080,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final outputFile = File(targetPath);
      await outputFile.writeAsBytes(jpegBytes);

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