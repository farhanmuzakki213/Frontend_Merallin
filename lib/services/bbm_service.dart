// lib/services/bbm_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/bbm_model.dart';

class ApiException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.message, [this.errors]);

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return errors!.entries.map((entry) {
        final field = entry.key;
        final message = entry.value is List ? entry.value.join(' ') : entry.value;
        return '$field: $message';
      }).join('\n');
    }
    return message;
  }
}


class BbmService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic>? errorBody;
    try {
      errorBody = json.decode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      throw ApiException(
          'Gagal memproses respons server. Status: ${response.statusCode}');
    }
    if (errorBody == null) throw ApiException('Terjadi kesalahan tidak diketahui.');
    if (response.statusCode == 422 && errorBody.containsKey('errors')) {
      throw ApiException(errorBody['message'] ?? 'Data tidak valid.',
          errorBody['errors'] as Map<String, dynamic>);
    }
    throw ApiException(
        errorBody['message'] ?? 'Terjadi kesalahan pada server.');
  }

  Future<http.Response> _multipartPostRequest(
      http.MultipartRequest request) async {
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _handleResponse(response);
      return response;
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }
  
  // Mengambil daftar riwayat pengisian BBM
  Future<List<BbmKendaraan>> getBbmRequests(String token) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token', 'Accept': 'application/json'
    });
    _handleResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => BbmKendaraan.fromJson(json)).toList();
  }

  Future<BbmKendaraan?> getActiveBbmRequest(String token) async {
    try {
      final allRequests = await getBbmRequests(token);
      return allRequests.firstWhere((req) => req.derivedStatus != BbmStatus.selesai);
    } catch (e) {
      return null; // Tidak ada yang aktif
    }
  }

  // Mengambil detail satu entri BBM
  Future<BbmKendaraan> getBbmDetails(String token, int bbmId) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan/$bbmId');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token', 'Accept': 'application/json'
    });
    _handleResponse(response);
    return BbmKendaraan.fromJson(json.decode(response.body));
  }
  
  // Membuat permintaan BBM baru
  Future<BbmKendaraan> createBbmRequest(String token, int vehicleId) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan');
    final response = await http.post(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }, body: json.encode({'vehicle_id': vehicleId}));
    _handleResponse(response);
    return BbmKendaraan.fromJson(json.decode(response.body)['data']);
  }
  
  // Upload foto KM awal
  Future<BbmKendaraan> uploadStartKm(String token, int bbmId, File photo) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan/$bbmId/upload-start-km');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('start_km_photo', photo.path, filename: basename(photo.path)));
    final response = await _multipartPostRequest(request);
    return BbmKendaraan.fromJson(json.decode(response.body)['data']);
  }
  
  // Konfirmasi selesai mengisi
  Future<BbmKendaraan> finishFilling(String token, int bbmId) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan/$bbmId/finish-filling');
    final response = await http.post(url, headers: {
      'Authorization': 'Bearer $token', 'Accept': 'application/json'
    });
    _handleResponse(response);
    return BbmKendaraan.fromJson(json.decode(response.body)['data']);
  }

  // Upload foto KM akhir dan nota
  Future<BbmKendaraan> uploadEndKmAndNota(String token, int bbmId, File? kmPhoto, File? notaPhoto) async {
    final url = Uri.parse('$_baseUrl/driver/bbm_kendaraan/$bbmId/upload-end-km-nota');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (kmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('end_km_photo', kmPhoto.path, filename: basename(kmPhoto.path)));
    }
    if (notaPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('nota_pengisian_photo', notaPhoto.path, filename: basename(notaPhoto.path)));
    }

    final response = await _multipartPostRequest(request);
    return BbmKendaraan.fromJson(json.decode(response.body)['data']);
  }
}