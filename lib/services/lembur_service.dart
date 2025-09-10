// lib/services/lembur_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class LemburService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  /// Fungsi untuk mengambil data riwayat lembur dari API.
  Future<List<Lembur>> getOvertimeHistory(String token) async {
    final url = Uri.parse('$_baseUrl/lembur');

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        List<dynamic> body = decoded['data'];
        return body.map((dynamic item) => Lembur.fromJson(item)).toList();
      } else {
        throw Exception(decoded['message'] ?? 'Gagal memuat riwayat lembur.');
      }
    } on SocketException {
      throw Exception(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      debugPrint('Error di getOvertimeHistory: $e');
      rethrow;
    }
  }

  /// Fungsi untuk mengirim pengajuan lembur baru ke API.
  Future<void> submitOvertimeRequest({
    required String token,
    required JenisHariLembur jenisHari,
    required DepartmentLembur department,
    required DateTime tanggalLembur,
    required String keteranganLembur,
    required String mulaiJamLembur,
    required String selesaiJamLembur,
  }) async {
    final url = Uri.parse('$_baseUrl/lembur');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jenis_hari': jenisHari.name,
          'department': department.name,
          'tanggal_lembur': tanggalLembur.toIso8601String().substring(0, 10),
          'keterangan_lembur': keteranganLembur,
          'mulai_jam_lembur': mulaiJamLembur,
          'selesai_jam_lembur': selesaiJamLembur,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Tidak perlu mengembalikan data, provider akan me-refresh
        return;
      } else if (response.statusCode == 422) {
        final errors = decoded['errors'] as Map<String, dynamic>;
        final errorMessage = errors.values.map((e) => e[0]).join('\n');
        throw Exception(errorMessage);
      } else {
        throw Exception(decoded['message'] ?? 'Gagal mengirim pengajuan lembur.');
      }
    } on SocketException {
      throw Exception(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Lembur> getOvertimeDetail(String token, String uuid) async {
    final url = Uri.parse('$_baseUrl/lembur/$uuid');
    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // API detail mengembalikan data tunggal di dalam 'data'
        return Lembur.fromJson(decoded['data']);
      } else {
        throw Exception(decoded['message'] ?? 'Gagal memuat detail lembur.');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server.');
    } catch (e) {
      debugPrint('Error di getOvertimeDetail: $e');
      rethrow;
    }
  }

  /// Mengirim data clock-in lembur ke server.
  Future<Lembur> clockIn({
    required String token,
    required String uuid,
    required File image,
    required Position position,
  }) async {
    final url = Uri.parse('$_baseUrl/lembur/$uuid/clock-in');
    var request = http.MultipartRequest('POST', url);
    
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    // Tambahkan field data
    request.fields['latitude'] = position.latitude.toString();
    request.fields['longitude'] = position.longitude.toString();

    // Tambahkan file gambar
    final mimeTypeData = lookupMimeType(image.path)?.split('/');
    request.files.add(
      await http.MultipartFile.fromPath(
        'foto_mulai', // Sesuaikan dengan nama di controller Laravel
        image.path,
        contentType: mimeTypeData != null ? MediaType(mimeTypeData[0], mimeTypeData[1]) : null,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Lembur.fromJson(decoded['data']);
    } else {
      throw Exception(decoded['message'] ?? 'Gagal melakukan clock-in.');
    }
  }

  /// Mengirim data clock-out lembur ke server.
  Future<Lembur> clockOut({
    required String token,
    required String uuid,
    required File image,
    required Position position,
  }) async {
    final url = Uri.parse('$_baseUrl/lembur/$uuid/clock-out');
    var request = http.MultipartRequest('POST', url);
    
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['latitude'] = position.latitude.toString();
    request.fields['longitude'] = position.longitude.toString();

    final mimeTypeData = lookupMimeType(image.path)?.split('/');
    request.files.add(
      await http.MultipartFile.fromPath(
        'foto_selesai', // Sesuaikan dengan nama di controller Laravel
        image.path,
        contentType: mimeTypeData != null ? MediaType(mimeTypeData[0], mimeTypeData[1]) : null,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return Lembur.fromJson(decoded['data']);
    } else {
      throw Exception(decoded['message'] ?? 'Gagal melakukan clock-out.');
    }
  }
}