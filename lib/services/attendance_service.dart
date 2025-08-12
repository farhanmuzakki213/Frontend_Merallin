import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'; // Import untuk debugPrint
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/attendance_history_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AttendanceService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  /// Fungsi utama untuk melakukan absensi (clock-in/out).
  Future<void> performAttendance(File image, String token) async {
    try {
      final Position position = await _getLocation();
      if (position.isMocked) {
        throw Exception('Terdeteksi menggunakan lokasi palsu. Proses dibatalkan.');
      }

      final String currentTime = DateTime.now().toIso8601String();
      final url = Uri.parse('$_baseUrl/attendance/clock-in');
      var request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();
      request.fields['is_mocked'] = position.isMocked ? '1' : '0';
      request.fields['timestamp'] = currentTime;

      request.files.add(
        await http.MultipartFile.fromPath('photo', image.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final responseBody = json.decode(response.body);
        throw Exception(responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data absensi. Periksa koneksi Anda.');
    } catch (e) {
      rethrow;
    }
  }

  /// Fungsi untuk mengambil data riwayat absensi dari API.
  Future<List<AttendanceHistory>> getAttendanceHistory(String token) async {
    final url = Uri.parse('$_baseUrl/attendance/history');
    
    debugPrint('Mencoba mengambil riwayat dari: $url');
    debugPrint('Menggunakan Token: Bearer $token'); // Cek apakah token ada

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // --- PRINT UNTUK MELACAK RESPON DARI SERVER ---
      debugPrint('Status Code Riwayat: ${response.statusCode}');
      debugPrint('Body Respons Riwayat: ${response.body}');
      // ---------------------------------------------

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body
            .map((dynamic item) => AttendanceHistory.fromJson(item))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesi Anda telah berakhir. Silakan login kembali.');
      } else {
        throw Exception('Gagal memuat riwayat absensi (Kode: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error di getAttendanceHistory: $e');
      rethrow;
    }
  }

  /// Fungsi privat untuk mendapatkan lokasi GPS pengguna.
  Future<Position> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif. Mohon aktifkan GPS Anda.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen, Anda tidak dapat absen.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}