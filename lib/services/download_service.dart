// lib/services/download_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
      throw Exception('Gagal mengambil data file. Status: ${response.statusCode}');
    }
  }

  // Metode 1: Untuk "Download Cepat"
  Future<String> saveToDownloads({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    try {
      String savedPath = await FileSaver().saveFile(
        filename,
        fileBytes,
        "pdf",
      );
      return savedPath;
    } catch (e) {
      throw Exception('Gagal menyimpan file: $e');
    }
  }

  // Metode 2: Untuk "Pilih Folder"
  Future<String> saveToCustomDirectory({
    required String directoryPath,
    required String filename,
    required Uint8List fileBytes,
  }) async {
    final savePath = '$directoryPath/$filename.pdf';
    final file = File(savePath);
    await file.writeAsBytes(fileBytes);
    return savePath;
  }

  Future<String> saveAndOpenFile({
    required String filename,
    required Uint8List fileBytes,
  }) async {
    try {
      // 1. Dapatkan direktori sementara aplikasi
      final directory = await getTemporaryDirectory();
      
      // 2. Buat path lengkap untuk file (dengan ekstensi .pdf)
      final filePath = p.join(directory.path, '$filename.pdf');
      
      // 3. Tulis data byte ke file
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // 4. Kembalikan path file yang sudah disimpan
      return filePath;

    } catch (e) {
      throw Exception('Gagal menyimpan file sementara: $e');
    }
  }
}