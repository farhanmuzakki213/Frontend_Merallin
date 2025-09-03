
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/attendance_history_model.dart';
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

  Future<void> clockInWithLocation(
      File image, String token, double latitude, double longitude) async {
    final url = Uri.parse('$_baseUrl/attendance/clock-in');
    await _uploadAttendanceWithLocation(url, image, token, latitude, longitude);
  }

  Future<void> _uploadAttendanceWithLocation(Uri url, File image, String token,
      double latitude, double longitude) async {
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.files.add(await http.MultipartFile.fromPath('photo', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 400) {
        final responseBody = json.decode(response.body);
        throw Exception(
            responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data. Periksa koneksi Anda.');
    } catch (e) {
      rethrow;
    }
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
        throw Exception(
            responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data. Periksa koneksi Anda.');
    } catch (e) {
      rethrow;
    }
  }

  // +++ card baru absen +++
  Future<List<AttendanceHistory>> getAttendanceHistory(String token) async {
    final url = Uri.parse('$_baseUrl/attendance/history'); // Pastikan endpoint ini ada di backend Anda
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
  // Cek apakah response-nya object map dg key 'data' atau langsung list
  final List<dynamic> body = (decoded is Map<String, dynamic>) ? decoded['data'] : decoded;
  return body
      .map((dynamic item) => AttendanceHistory.fromJson(item))
      .toList();
} else {
        final responseBody = json.decode(response.body);
        throw Exception(
            responseBody['message'] ?? 'Gagal memuat riwayat absensi.');
      }
    } on SocketException {
      throw Exception('Gagal terhubung ke server. Periksa koneksi Anda.');
    } catch (e) {
      rethrow;
    }
  }

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
