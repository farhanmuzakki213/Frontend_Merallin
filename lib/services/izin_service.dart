// lib/services/izin_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class IzinService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  /// Fungsi untuk mengambil data riwayat izin dari API.
  Future<List<Izin>> getLeaveHistory(String token) async {
    // FIX: URL disesuaikan agar tidak ada duplikasi '/api'
    final url = Uri.parse('$_baseUrl/izin'); 
    
    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        List<dynamic> body = decoded['data'];
        return body.map((dynamic item) => Izin.fromJson(item)).toList();
      } else {
        throw Exception(decoded['message'] ?? 'Gagal memuat riwayat izin.');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      debugPrint('Error di getLeaveHistory: $e');
      rethrow;
    }
  }

  /// Fungsi untuk mengirim pengajuan izin baru ke API.
  Future<Izin> submitLeaveRequest({
    required String token,
    required LeaveType jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    String? alasan,
    File? fileBukti, 
  }) async {
    // FIX: URL disesuaikan agar tidak ada duplikasi '/api'
    final url = Uri.parse('$_baseUrl/izin');
    
    try {
      var request = http.MultipartRequest('POST', url);
      
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['jenis_izin'] = jenisIzin.name;
      request.fields['tanggal_mulai'] = tanggalMulai.toIso8601String();
      request.fields['tanggal_selesai'] = tanggalSelesai.toIso8601String();
      if (alasan != null && alasan.isNotEmpty) {
        request.fields['alasan'] = alasan;
      }
      
      if (fileBukti != null) {
        final mimeTypeData = lookupMimeType(fileBukti.path)?.split('/');
        request.files.add(
          await http.MultipartFile.fromPath(
            'bukti', // Nama field sudah sesuai
            fileBukti.path,
            contentType: mimeTypeData != null
                ? MediaType(mimeTypeData[0], mimeTypeData[1])
                : null,
          ),
        );
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 201) { // Status 201 untuk 'Created'
        return Izin.fromJson(decoded['data']);
      } else if (response.statusCode == 422) {
        final errors = decoded['errors'] as Map<String, dynamic>;
        final errorMessage = errors.values.map((e) => e[0]).join('\n');
        throw Exception(errorMessage);
      } else {
        throw Exception(decoded['message'] ?? 'Gagal mengirim pengajuan izin.');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }
}