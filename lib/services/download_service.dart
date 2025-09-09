// lib/services/download_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;

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
}