// lib/services/download_service.dart

import 'dart:io';
import 'dart:typed_data';
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
    try {
      String? downloadsPath;
      if (Platform.isAndroid) {
        downloadsPath = (await getExternalStorageDirectory())?.path;
      } else if (Platform.isIOS) {
        downloadsPath = (await getApplicationDocumentsDirectory()).path;
      } else {
        throw UnsupportedError('Platform tidak didukung untuk "Download Cepat"');
      }

      if (downloadsPath == null) {
        throw Exception('Direktori Downloads tidak ditemukan.');
      }

      final savePath = p.join(downloadsPath, '$filename.pdf');
      final file = File(savePath);
      await file.writeAsBytes(fileBytes);
      return savePath;
    } catch (e) {
      throw Exception('Gagal menyimpan file: $e');
    }
  }

  // Metode 2: Untuk "Pilih Folder"
  Future<String> saveToCustomDirectory({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      throw Exception('Pemilihan folder dibatalkan.');
    }
    final savePath = p.join(selectedDirectory, '$filename.pdf');
    final file = File(savePath);
    await file.writeAsBytes(fileBytes);
    return savePath;
  }

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