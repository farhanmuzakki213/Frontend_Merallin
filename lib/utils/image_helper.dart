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
  /// Compresses the given image bytes until the size is below the target size.
  /// This function will loop and reduce quality until the target is met.
  static Future<Uint8List> _compressImageEfficiently(
    Uint8List imageBytes, {
    int targetSizeInBytes = 3 * 1024, // 3 MB
    int initialQuality = 90,
  }) async {
    // Jika ukuran gambar sudah di bawah 3 MB, tidak perlu kompresi
    if (imageBytes.lengthInBytes <= targetSizeInBytes) {
      // Kita tetap mengonversinya ke JPEG dengan kualitas tinggi jika format asli bukan JPEG.
      if (imageBytes.lengthInBytes < 2 || !(imageBytes[0] == 0xFF && imageBytes[1] == 0xD8)) {
        return await FlutterImageCompress.compressWithList(
          imageBytes,
          quality: initialQuality,
          format: CompressFormat.jpeg,
        );
      }
      return imageBytes;
    }

    // Jika ukuran gambar melebihi 3 MB, lakukan kompresi
    int quality = initialQuality;
    Uint8List result = imageBytes;
    int size = result.lengthInBytes;

    // Lakukan kompresi awal untuk mendapatkan baseline.
    result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 1080,
      minHeight: 1920,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    size = result.lengthInBytes;

    // Sesuaikan kualitas secara cerdas, bukan dengan loop ekstrem.
    if (size > targetSizeInBytes) {
      double compressionFactor = targetSizeInBytes / size;
      int newQuality = (quality * compressionFactor).round();
      
      if (newQuality < 20) {
        newQuality = 20;
      }
      
      debugPrint("Initial compression is too large. New estimated quality: $newQuality");
      
      result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1080,
        minHeight: 1920,
        quality: newQuality,
        format: CompressFormat.jpeg,
      );
    }

    debugPrint(
        "Final compressed size: ${result.lengthInBytes / 1024 / 1024} MB");
    return result;
  }

  // ================== FUNGSI INTI (PRIVATE) UNTUK MENGGAMBAR TIMESTAMP ==================
  static Future<File?> _processAndStampImage(
    BuildContext context,
    Uint8List compressedImageBytes,
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
      final ui.Codec codec = await ui.instantiateImageCodec(compressedImageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      // 3. Gambar Foto Asli
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(
              0, 0, image.width.toDouble(), image.height.toDouble()),
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
      const timeStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 150,
          color: Colors.white,
          shadows: shadow);
      const dateStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: 100,
          color: Colors.white,
          shadows: shadow);
      const addressStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.normal,
          fontSize: 80,
          color: Colors.white,
          shadows: shadow);

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
        quality: 90,
      );

      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
          dir.path, "stamped_${DateTime.now().millisecondsSinceEpoch}.jpg");
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
    // Ambil gambar dengan kualitas setinggi mungkin untuk diolah
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (pickedFile == null || !context.mounted) return null;

    // Langsung baca bytes dari file asli dan serahkan ke prosesor
    final imageBytes = await pickedFile.readAsBytes();

    final compressedBytes = await _compressImageEfficiently(imageBytes);

    // Lalu, serahkan bytes yang sudah dikompresi ke prosesor
    return await _processAndStampImage(context, compressedBytes);
  }

  /// Memilih banyak gambar dari galeri dan menambahkan timestamp ke semuanya.
  static Future<List<File>> pickMultipleImages(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 100);
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
        final imageBytes = await file.readAsBytes();
        final compressedBytes = await _compressImageEfficiently(imageBytes);
        
        final processedFile = await _processAndStampImage(context, compressedBytes);
        if (processedFile != null) {
          processedFiles.add(processedFile);
        }
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      } // Tutup dialog loading
    }

    return processedFiles;
  }

  // Fungsi lama diganti untuk menggunakan helper baru, agar konsisten
  static Future<File?> takeGeotaggedPhoto(BuildContext context) async {
    return takePhoto(context);
  }
}
