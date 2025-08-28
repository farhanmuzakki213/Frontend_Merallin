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
        final message = entry.value is List ? entry.value.join(' ') : entry.value;
        return '$field: $message';
      }).join('\n');
    }
    return message;
  }
}

class TripService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic>? errorBody;
    try {
      errorBody = json.decode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      throw ApiException('Gagal memproses respons dari server. Status: ${response.statusCode}');
    }
    if (errorBody == null) throw ApiException('Terjadi kesalahan tidak diketahui.');
    if (response.statusCode == 422 && errorBody.containsKey('errors')) {
      throw ApiException(errorBody['message'] ?? 'Data tidak valid.', errorBody['errors'] as Map<String, dynamic>);
    }
    throw ApiException(errorBody['message'] ?? 'Terjadi kesalahan pada server.');
  }

  Future<http.Response> _multipartPostRequest(http.MultipartRequest request) async {
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _handleResponse(response);
      return response;
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> _postRequest(String token, String endpoint, {Map<String, dynamic>? body}) async {
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
      _handleResponse(response);
      return response;
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Trip>> getTrips(String token) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      _handleResponse(response);
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Trip.fromJson(json)).toList();
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip> getTripDetails(String token, int tripId) async {
     if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
     final url = Uri.parse('$_baseUrl/trips/$tripId');
     try {
       final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
       _handleResponse(response);
       return Trip.fromJson(json.decode(response.body));
     } on SocketException {
       throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
     } on TimeoutException {
      throw ApiException('Server tidak merespons tepat waktu. Silakan coba lagi.');
    } catch (e) {
       rethrow;
     }
  }

  Future<Trip> acceptTrip(String token, int tripId) async {
    final response = await _postRequest(token, '$tripId/accept');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateStartTrip({ required String token, required int tripId, required String licensePlate, required String startKm, File? startKmPhoto }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/start');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['license_plate'] = licensePlate
      ..fields['start_km'] = startKm;
    if (startKmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('start_km_photo', startKmPhoto.path, filename: basename(startKmPhoto.path)));
    }
    final response = await _multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateToLoadingPoint({required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/at-loading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> finishLoading({required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/finish-loading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateAfterLoading({ required String token, required int tripId, File? muatPhoto, List<File>? deliveryLetters }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/after-loading');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (muatPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('muat_photo', muatPhoto.path, filename: basename(muatPhoto.path)));
    }
    if (deliveryLetters != null) {
      for (var file in deliveryLetters) {
        request.files.add(await http.MultipartFile.fromPath('delivery_letters[]', file.path, filename: basename(file.path)));
      }
    }
    final response = await _multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> uploadTripDocuments({ required String token, required int tripId, File? deliveryOrder, File? segelPhoto, File? timbanganPhoto }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/upload-documents');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (deliveryOrder != null) {
      request.files.add(await http.MultipartFile.fromPath('delivery_order', deliveryOrder.path, filename: basename(deliveryOrder.path)));
    }
    if (segelPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('segel_photo', segelPhoto.path, filename: basename(segelPhoto.path)));
    }
    if (timbanganPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('timbangan_kendaraan_photo', timbanganPhoto.path, filename: basename(timbanganPhoto.path)));
    }
    final response = await _multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateToUnloadingPoint({required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/at-unloading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> finishUnloading({required String token, required int tripId}) async {
    final response = await _postRequest(token, '$tripId/finish-unloading');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateFinishTrip({ required String token, required int tripId, required String endKm, File? endKmPhoto, List<File>? bongkarPhoto, List<File>? deliveryLetters }) async {
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/finish');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['end_km'] = endKm;
    if (endKmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('end_km_photo', endKmPhoto.path, filename: basename(endKmPhoto.path)));
    }
    if (bongkarPhoto != null) {
      for (var file in bongkarPhoto) {
        request.files.add(await http.MultipartFile.fromPath('bongkar_photo[]', file.path, filename: basename(file.path)));
      }
    }
    if (deliveryLetters != null) {
      for (var file in deliveryLetters) {
        request.files.add(await http.MultipartFile.fromPath('delivery_letters[]', file.path, filename: basename(file.path)));
      }
    }
    final response = await _multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }
}