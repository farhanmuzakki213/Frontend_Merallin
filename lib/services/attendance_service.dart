import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// import 'package:frontend_merallin/services/face_auth_service.dart';
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

    // final faceId = await _faceAuthService.detectFace(image);
    // if (faceId == null) {
    //   throw Exception(
    //       'Wajah tidak terdeteksi. Mohon posisikan wajah Anda dengan jelas.');
    // }

    // final personId = await _faceAuthService.identifyFace(faceId);
    // if (personId == null) {
    //   throw Exception(
    //       'Verifikasi wajah gagal. Wajah tidak cocok dengan data terdaftar.');
    // }

    // 2. Siapkan request untuk unggah file
    final url = Uri.parse('$_baseUrl/attendance/clock-in');
    try {
      var request = http.MultipartRequest('POST', url);

      // 3. Tambahkan headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // 4. Tambahkan data teks (fields)
      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();
      request.fields['is_mocked'] = position.isMocked ? '1' : '0';

      // 5. Tambahkan file gambar
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo', // Nama field ini harus sama dengan yang diharapkan backend
          image.path,
        ),
      );

      // 6. Kirim request dan dapatkan respons
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 7. Cek status code dan tangani error
      if (response.statusCode != 200) {
        final responseBody = json.decode(response.body);
        // Coba baca pesan error dari backend
        throw Exception(responseBody['message'] ?? 'Gagal mengirim data absensi.');
      }
    } on SocketException {
      throw Exception('Gagal mengirim data absensi. Periksa koneksi Anda.');
    } catch (e) {
      // Lempar kembali error yang sudah ada atau error baru
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
