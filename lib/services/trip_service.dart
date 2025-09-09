// lib/services/trip_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/trip_model.dart';
import 'dart:async'; // Import for TimeoutException

class ApiException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.message, [this.errors]);

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return errors!.entries.map((entry) {
        final field = entry.key;
        final message =
            entry.value is List ? entry.value.join(' ') : entry.value;
        return '$field: $message';
      }).join('\n');
    }
    return message;
  }
}

class TripService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
// PERUBAHAN UNTUK BISA DIPAKAI DI BBM
  void handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic>? errorBody;
    try {
      errorBody = json.decode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      throw ApiException(
          'Gagal memproses respons dari server. Status: ${response.statusCode}');
    }
    if (errorBody == null)
      throw ApiException('Terjadi kesalahan tidak diketahui.');
    if (response.statusCode == 422 && errorBody.containsKey('errors')) {
      throw ApiException(errorBody['message'] ?? 'Data tidak valid.',
          errorBody['errors'] as Map<String, dynamic>);
    }
    throw ApiException(
        errorBody['message'] ?? 'Terjadi kesalahan pada server.');
  }

  Future<http.Response> multipartPostRequest(
      http.MultipartRequest request) async {
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      handleResponse(response);
      return response;
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> _postRequest(String token, String endpoint,
      {Map<String, dynamic>? body}) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$endpoint');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json',
        },
        body: body != null ? json.encode(body) : null,
      );
      handleResponse(response);
      return response;
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Trip>> getTrips(String token) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips');
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });
      handleResponse(response);
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Trip.fromJson(json)).toList();
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip> getTripDetails(String token, int tripId) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/trips/$tripId');
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 20));
      handleResponse(response);
      return Trip.fromJson(json.decode(response.body));
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw ApiException(
          'Server tidak merespons tepat waktu. Silakan coba lagi.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip> acceptTrip(String token, int tripId) async {
    final response = await _postRequest(token, '$tripId/accept');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateStartTrip({
    required String token,
    required int tripId,
    required int vehicleId, // Diubah dari licensePlate
    required String startKm,
    File? startKmPhoto,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/start');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    request.fields['vehicle_id'] = vehicleId.toString(); // Kirim ID
    request.fields['start_km'] = startKm;

    if (startKmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'start_km_photo', startKmPhoto.path,
          filename: basename(startKmPhoto.path)));
    }
    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateToLoadingPoint(
      {required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/at-loading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateKedatanganMuat({
    required String token,
    required int tripId,
    File? kmMuatPhoto,
    File? kedatanganMuatPhoto,
    File? deliveryOrderPhoto,
  }) async {
    final url =
        Uri.parse('$_baseUrl/driver/trips/$tripId/update-kedatangan-muat');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (kmMuatPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'km_muat_photo', kmMuatPhoto.path,
          filename: basename(kmMuatPhoto.path)));
    }
    if (kedatanganMuatPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'kedatangan_muat_photo', kedatanganMuatPhoto.path,
          filename: basename(kedatanganMuatPhoto.path)));
    }
    if (deliveryOrderPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'delivery_order_photo', deliveryOrderPhoto.path,
          filename: basename(deliveryOrderPhoto.path)));
    }

    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateProsesMuat({
    required String token,
    required int tripId,
    List<File>? muatPhotos,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/update-proses-muat');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (muatPhotos != null) {
      for (var file in muatPhotos) {
        request.files.add(await http.MultipartFile.fromPath(
            'muat_photo[]', file.path,
            filename: basename(file.path)));
      }
    }

    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> uploadSelesaiMuat({
    required String token,
    required int tripId,
    List<File>? deliveryLetters,
    File? segelPhoto,
    File? timbanganPhoto,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/upload-selesai-muat');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (deliveryLetters != null) {
      for (var file in deliveryLetters) {
        request.files.add(await http.MultipartFile.fromPath(
            'delivery_letters[]', file.path,
            filename: basename(file.path)));
      }
    }
    if (segelPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'segel_photo', segelPhoto.path,
          filename: basename(segelPhoto.path)));
    }
    if (timbanganPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'timbangan_kendaraan_photo', timbanganPhoto.path,
          filename: basename(timbanganPhoto.path)));
    }
    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateToUnloadingPoint(
      {required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/at-unloading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateKedatanganBongkar({
    required String token,
    required int tripId,
    String? endKm,
    File? endKmPhoto,
    File? kedatanganBongkarPhoto,
  }) async {
    final url =
        Uri.parse('$_baseUrl/driver/trips/$tripId/update-kedatangan-bongkar');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (endKm != null) request.fields['end_km'] = endKm;

    if (endKmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'end_km_photo', endKmPhoto.path,
          filename: basename(endKmPhoto.path)));
    }
    if (kedatanganBongkarPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'kedatangan_bongkar_photo', kedatanganBongkarPhoto.path,
          filename: basename(kedatanganBongkarPhoto.path)));
    }

    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateProsesBongkar({
    required String token,
    required int tripId,
    List<File>? bongkarPhotos,
  }) async {
    final url =
        Uri.parse('$_baseUrl/driver/trips/$tripId/update-proses-bongkar');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (bongkarPhotos != null) {
      for (var file in bongkarPhotos) {
        request.files.add(await http.MultipartFile.fromPath(
            'bongkar_photo[]', file.path,
            filename: basename(file.path)));
      }
    }
    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateSelesaiBongkar({
    required String token,
    required int tripId,
    List<File>? deliveryLetters,
  }) async {
    final url =
        Uri.parse('$_baseUrl/driver/trips/$tripId/update-selesai-bongkar');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    if (deliveryLetters != null) {
      for (var file in deliveryLetters) {
        request.files.add(await http.MultipartFile.fromPath(
            'delivery_letters[]', file.path,
            filename: basename(file.path)));
      }
    }
    final response = await multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }
}
