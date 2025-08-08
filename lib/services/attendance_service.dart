import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AttendanceService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  Future<void> performAttendance(File image, String token) async {
    // 1. Dapatkan Lokasi
    final Position position = await _getLocation();
    if (position.isMocked) {
      throw Exception('Terdeteksi menggunakan lokasi palsu. Proses dibatalkan.');
    }
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
        // Coba baca pesan error dari backend
        throw Exception(responseBody['message'] ?? 'Gagal mengirim data absensi.');
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