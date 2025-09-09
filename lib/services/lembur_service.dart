// lib/services/lembur_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:http/http.dart' as http;

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
}