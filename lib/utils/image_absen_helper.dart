// lib/utils/image_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:frontend_merallin/camera_screen.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// Data class to hold the stamped image file and its location data.
class GeotaggedImageResult {
  final File file;
  final Position? position;

  GeotaggedImageResult({required this.file, this.position});
}

class ImageHelper {
  // ================== FUNGSI INTI (PRIVATE) UNTUK MENGGAMBAR TIMESTAMP ==================
  static Future<GeotaggedImageResult?> _processAndStampImage(
    BuildContext context,
    Uint8List imageBytes, {
    bool getLocation = true,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Position? position;

    try {
      if (getLocation) {
        var status = await Permission.location.status;
        if (status.isDenied) {
          status = await Permission.location.request();
        }

        // 2. Jika Izin Diberikan, Baru Ambil Lokasi
        if (status.isGranted) {
          try {
            position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10));
          } catch (e) {
            debugPrint("Gagal mendapatkan lokasi: $e");
            // Tidak melempar error, lanjutkan dengan posisi null
          }
        } else {
          debugPrint("Izin lokasi ditolak oleh pengguna.");
        }
      }

      String addressText = "Alamat tidak ditemukan";
      if (position != null) {
        try {
          // Panggil API web untuk mendapatkan alamat dari koordinat
          final lat = position.latitude;
          final lon = position.longitude;
          final url = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon');

          final response =
              await http.get(url, headers: {'User-Agent': 'MerallinApp/1.0'});

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            // Ambil nama alamat lengkap dari respons API
            addressText = data['display_name'] ?? 'Alamat tidak dapat diurai';
          } else {
            addressText = 'Gagal memuat alamat';
          }
        } catch (e) {
          debugPrint("Gagal mendapatkan alamat via API: $e");
          // Biarkan addressText tetap default jika ada error
        }
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
          rect: Rect.fromLTWH(
              0, 0, image.width.toDouble(), image.height.toDouble()),
          image: image,
          fit: BoxFit.cover);

      // 4. Siapkan Teks dan Style
      final now = DateTime.now();
      final jam = DateFormat('HH:mm:ss').format(now);
      final tanggal = DateFormat('dd/MM/yyyy').format(now);
      final hari = DateFormat('EEEE', 'id_ID').format(now);

      // Tentukan ukuran font relatif terhadap lebar gambar agar lebih responsif
      final double baseFontSize = image.width / 25.0;

      const double margin = 20.0; // Margin dari tepi
      const shadow = [
        Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 3.0)
      ];

      // Definisikan style font dengan ukuran yang lebih proporsional
      final timeStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.bold,
          fontSize: baseFontSize * 1.5, // Jam sedikit lebih besar
          color: Colors.white,
          shadows: shadow);
      final dateStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.normal,
          fontSize: baseFontSize * 0.9, // Tanggal & Hari lebih kecil
          color: Colors.white,
          shadows: shadow);
      final addressStyle = TextStyle(
          fontFamily: 'Arial',
          fontWeight: FontWeight.normal,
          fontSize: baseFontSize * 0.8, // Alamat paling kecil
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
      TextPainter? addressPainter;
      if (position != null) {
        addressPainter = createTextPainter(addressText, addressStyle);
      }

      // 5. Gambar Teks di Canvas (Tata Letak Baru di Pojok Kiri Bawah)
      double nextY = image.height.toDouble() - margin; // Mulai dari bawah

      // Gambar Alamat (paling bawah)
      if (addressPainter != null) {
        nextY -= addressPainter.height;
        addressPainter.paint(canvas, Offset(margin, nextY));
      }

      // Gambar Hari
      nextY -= (hariPainter.height + 5); // Beri sedikit spasi
      hariPainter.paint(canvas, Offset(margin, nextY));

      // Gambar Tanggal
      nextY -= (tanggalPainter.height + 5);
      tanggalPainter.paint(canvas, Offset(margin, nextY));

      // Gambar Jam (paling atas di antara teks lainnya)
      nextY -= (jamPainter.height + 10); // Beri spasi lebih besar
      jamPainter.paint(canvas, Offset(margin, nextY));

      // 6. Simpan Hasil ke File Baru
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception("Gagal mengonversi gambar ke PNG");

      Uint8List finalBytes = byteData.buffer.asUint8List();

      if (!kIsWeb &&
          !Platform.isWindows &&
          !Platform.isLinux &&
          !Platform.isMacOS) {
        finalBytes = await FlutterImageCompress.compressWithList(
          finalBytes,
          minWidth: 1080,
          minHeight: 1920,
          quality: 85,
          format: CompressFormat.jpeg,
        );
      }

      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
          dir.path, "stamped_${DateTime.now().millisecondsSinceEpoch}.jpg");
      final outputFile = File(targetPath);
      await outputFile.writeAsBytes(finalBytes);

      return GeotaggedImageResult(file: outputFile, position: position);
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

  /// [TIDAK BERUBAH] Mengambil satu foto dari kamera dan menambahkan timestamp.
  /// Hanya mengembalikan File.
  static Future<File?> takePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (pickedFile == null || !context.mounted) return null;

    var compressedBytes = await FlutterImageCompress.compressWithFile(
      pickedFile.path,
      minWidth: 1080,
      minHeight: 1920,
      quality: 80,
    );

    if (compressedBytes == null) return null;

    // Panggil _processAndStampImage tanpa mengharapkan lokasi kembali
    final result = await _processAndStampImage(context, compressedBytes,
        getLocation: false);
    return result?.file;
  }

  /// [BARU] Mengambil foto, memberi timestamp, DAN mengembalikan data lokasi.
  /// Mengembalikan [GeotaggedImageResult] yang berisi file dan data lokasi.
  static Future<GeotaggedImageResult?> takePhotoWithLocation(
      BuildContext context) async {
    XFile? pickedFile;

    bool shouldGetLocation = !kIsWeb;

    if (!kIsWeb &&
        (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      // Gunakan package camera untuk desktop
      pickedFile = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      final picker = ImagePicker();
      pickedFile =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    }
    if (pickedFile == null || !context.mounted) return null;
    Uint8List imageBytes = await pickedFile.readAsBytes();

    if (!kIsWeb &&
        !io.Platform.isWindows &&
        !io.Platform.isLinux &&
        !io.Platform.isMacOS) {
      try {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          imageBytes,
          minWidth: 1080,
          minHeight: 1920,
          quality: 80,
        );
        imageBytes = compressedBytes;
      } catch (e) {
        debugPrint("Gagal melakukan kompresi: $e");
        // Lanjutkan dengan gambar asli jika kompresi gagal
      }
    }

    // Panggil _processAndStampImage dan harapkan lokasi kembali
    return await _processAndStampImage(context, imageBytes,
        getLocation: shouldGetLocation);
  }

  /// [TIDAK BERUBAH] Memilih banyak gambar dari galeri dan menambahkan timestamp ke semuanya.
  static Future<List<File>> pickMultipleImages(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);
    if (pickedFiles.isEmpty || !context.mounted) return [];

    List<File> processedFiles = [];
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
          final processedResult = await _processAndStampImage(
              context, compressedBytes,
              getLocation: false);
          if (processedResult != null) {
            processedFiles.add(processedResult.file);
          }
        }
      }
    } finally {
      Navigator.of(context).pop(); // Tutup dialog loading
    }

    return processedFiles;
  }

  /// [TIDAK BERUBAH] Fungsi lama diganti untuk menggunakan helper baru, agar konsisten
  static Future<File?> takeGeotaggedPhoto(BuildContext context) async {
    return takePhoto(context);
  }
}
