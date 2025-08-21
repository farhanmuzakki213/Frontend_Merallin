// lib/utils/image_helper.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

class ImageHelper {
  // ================== FUNGSI INTI (PRIVATE) UNTUK MENGGAMBAR TIMESTAMP ==================
  static Future<File?> _processAndStampImage(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // 1. Dapatkan Lokasi & Alamat (dijalankan untuk setiap gambar)
      Position? position;
      String addressText = "Alamat tidak ditemukan";
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high, 
            timeLimit: const Duration(seconds: 10));
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addressText =
              "${p.street}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea}";
        }
      } catch (e) {
        debugPrint("Gagal mendapatkan lokasi/alamat: $e");
      }

      // 2. Decode & Siapkan Canvas
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      // 3. Gambar Foto Asli
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          image: image,
          fit: BoxFit.cover);

      // 4. Siapkan Teks dan Style
      final now = DateTime.now();
      final jam = DateFormat('HH:mm:ss').format(now);
      final tanggal = DateFormat('dd/MM/yyyy').format(now);
      final hari = DateFormat('EEEE', 'id_ID').format(now);

      const double margin = 40.0;
      const shadow = [
        Shadow(color: Colors.black87, offset: Offset(2, 2), blurRadius: 4.0)
      ];
      const timeStyle = TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 150, color: Colors.white, shadows: shadow);
      const dateStyle = TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 100, color: Colors.white, shadows: shadow);
      const addressStyle = TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.normal, fontSize: 80, color: Colors.white, shadows: shadow);

      TextPainter createTextPainter(String text, TextStyle style) {
        return TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: image.width - (margin * 2));
      }

      final jamPainter = createTextPainter(jam, timeStyle);
      final tanggalPainter = createTextPainter(tanggal, dateStyle);
      final hariPainter = createTextPainter(hari, dateStyle);
      final addressPainter = createTextPainter(addressText, addressStyle);

      // 5. Gambar Teks di Canvas
      final double addressY = image.height - margin - addressPainter.height;
      final double hariY = addressY - 10 - hariPainter.height;
      final double tanggalY = hariY - 10 - tanggalPainter.height;
      final double jamY = tanggalY - 15 - jamPainter.height;

      jamPainter.paint(canvas, Offset(margin, jamY));
      tanggalPainter.paint(canvas, Offset(margin, tanggalY));
      hariPainter.paint(canvas, Offset(margin, hariY));
      addressPainter.paint(canvas, Offset(margin, addressY));

      // 6. Simpan Hasil ke File Baru
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);
      final pngBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes == null) throw Exception("Gagal mengonversi gambar ke PNG");

      final jpegBytes = await FlutterImageCompress.compressWithList(
        pngBytes.buffer.asUint8List(),
        minWidth: 1080,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, "stamped_${DateTime.now().millisecondsSinceEpoch}.jpg");
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

  // ================== FUNGSI PUBLIK YANG DIPERBARUI & BARU ==================

  /// Mengambil satu foto dari kamera dan menambahkan timestamp.
  static Future<File?> takePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (pickedFile == null || !context.mounted) return null;

    // Kompres dulu sebelum di-stamp untuk efisiensi
    var compressedBytes = await FlutterImageCompress.compressWithFile(
      pickedFile.path,
      minWidth: 1080,
      minHeight: 1920,
      quality: 80,
    );

    if (compressedBytes == null) return null;

    return await _processAndStampImage(context, compressedBytes);
  }

  /// Memilih banyak gambar dari galeri dan menambahkan timestamp ke semuanya.
  static Future<List<File>> pickMultipleImages(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);
    if (pickedFiles.isEmpty || !context.mounted) return [];

    List<File> processedFiles = [];
    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Memproses gambar..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      for (var file in pickedFiles) {
        var compressedBytes = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 1080,
          minHeight: 1920,
          quality: 80,
        );
        if (compressedBytes != null) {
          final processedFile = await _processAndStampImage(context, compressedBytes);
          if (processedFile != null) {
            processedFiles.add(processedFile);
          }
        }
      }
    } finally {
      Navigator.of(context).pop(); // Tutup dialog loading
    }

    return processedFiles;
  }

  // Fungsi lama diganti untuk menggunakan helper baru, agar konsisten
  static Future<File?> takeGeotaggedPhoto(BuildContext context) async {
    return takePhoto(context);
  }
}
