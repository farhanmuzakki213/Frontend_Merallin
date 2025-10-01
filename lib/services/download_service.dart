// lib/services/download_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

class DownloadService {
  // Fungsi untuk mengambil data file dari server
  Future<Uint8List> fetchFileBytes({
    required String url,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(
          'Gagal mengambil data file. Status: ${response.statusCode}');
    }
  }

  // Metode 1: Untuk "Download Cepat" (Simpan ke folder Downloads)
   Future<String> saveToDownloads({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    // --- Logika untuk Desktop (Windows, macOS, Linux) ---
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Anda',
        fileName: '$filename.pdf', // Nama file default yang akan muncul di dialog
      );

      if (outputFile != null) {
        // Jika pengguna memilih lokasi dan menekan Simpan
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes);
        return file.path;
      } else {
        // Jika pengguna menekan Batal
        throw Exception('Penyimpanan file dibatalkan.');
      }
    }
    // --- Logika untuk Mobile (Android/iOS) ---
    else {
      try {
        final directory = await DownloadsPathProvider.downloadsDirectory;
        if (directory == null) {
          throw Exception('Tidak dapat menemukan folder Downloads.');
        }
        final savePath = p.join(directory.path, '$filename.pdf');
        final file = File(savePath);
        await file.writeAsBytes(fileBytes);
        return savePath;
      } catch (e) {
        throw Exception('Gagal menyimpan file: $e');
      }
    }
  }

  // Fungsi ini sudah benar, tidak perlu diubah.
  Future<String> saveToCustomDirectory({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      throw Exception('Pemilihan folder dibatalkan.');
    }
    final savePath = p.join(selectedDirectory, '$filename.pdf');
    final file = File(savePath);
    await file.writeAsBytes(fileBytes);
    return savePath;
  }

  // Fungsi ini sudah benar, tidak perlu diubah.
  Future<String> saveAndOpenFile({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = p.join(directory.path, '$filename.pdf');
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    } catch (e) {
      throw Exception('Gagal menyimpan file sementara: $e');
    }
  }
}