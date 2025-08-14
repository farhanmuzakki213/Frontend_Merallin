import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AttendanceService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  Future<Map<String, bool>> checkStatusToday(String token) async {
    final url = Uri.parse('$_baseUrl/attendance/status-today');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return {
        'has_clocked_in': body['has_clocked_in'] as bool,
        'has_clocked_out': body['has_clocked_out'] as bool,
      };
    } else {
      throw Exception('Gagal memeriksa status absensi.');
    }
  }

  Future<void> clockIn(File image, String token) async {
    final url = Uri.parse('$_baseUrl/attendance/clock-in');
    await _uploadAttendance(url, image, token);
  }

  Future<void> clockOut(File image, String token) async {
    final url = Uri.parse('$_baseUrl/attendance/clock-out');
    await _uploadAttendance(url, image, token);
  }

  Future<void> _uploadAttendance(Uri url, File image, String token) async {
    try {
      final Position position = await _getLocation();
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 400) {
        final responseBody = json.decode(response.body);
        throw Exception(responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data. Periksa koneksi Anda.');
    } catch (e) {
      rethrow;
    }
  }


  /// Fungsi privat untuk mendapatkan lokasi GPS pengguna.
  Future<Position> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cek apakah layanan lokasi di ponsel aktif.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Jika tidak aktif, lempar error untuk menghentikan proses.
      throw Exception('Layanan lokasi tidak aktif. Mohon aktifkan GPS Anda.');
    }

    // 2. Cek apakah aplikasi memiliki izin untuk mengakses lokasi.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Jika izin ditolak, minta izin kepada pengguna.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Jika pengguna tetap menolak, lempar error.
        throw Exception('Izin lokasi ditolak.');
      }
    }

    // 3. Cek jika izin ditolak secara permanen.
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen, Anda tidak dapat absen.');
    }

    // 4. Jika semua izin sudah diberikan, ambil posisi saat ini.
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
