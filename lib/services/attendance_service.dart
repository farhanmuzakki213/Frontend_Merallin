// frontend_merallin/services/attendance_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AttendanceService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  Future<Map<String, dynamic>> getTodayAttendanceStatus(String token) async {
    final url = Uri.parse('$_baseUrl/attendance/status-today');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception('Gagal mendapatkan status absensi.');
      }
    } on SocketException {
      throw Exception('Periksa koneksi internet Anda.');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> performClockIn(File image, String token) async {
    final url = Uri.parse('$_baseUrl/attendance/clock-in');
    await _uploadAttendance(url, image, token);
  }

  Future<void> performClockOut(File image, String token) async {
    final url = Uri.parse('$_baseUrl/attendance/clock-in');
    await _uploadAttendance(url, image, token);
  }

  Future<void> _uploadAttendance(Uri url, File image, String token) async {
    try {
      final Position position = await _getLocation();
      if (position.isMocked) {
        throw Exception(
            'Terdeteksi menggunakan lokasi palsu. Proses dibatalkan.');
      }

      var request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();
      request.fields['is_mocked'] = position.isMocked ? '1' : '0';

      request.files.add(
        await http.MultipartFile.fromPath('photo', image.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final responseBody = json.decode(response.body);
        throw Exception(
            responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data absensi. Periksa koneksi Anda.');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Izin lokasi ditolak secara permanen, Anda tidak dapat melakukan absensi.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
