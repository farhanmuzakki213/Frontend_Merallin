// lib/services/trip_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/trip_model.dart';

class ApiException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.message, [this.errors]);

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return errors!.values
          .map((value) => value is List ? value.join(' ') : value)
          .join('\n');
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
      print('Server returned non-JSON response (Status ${response.statusCode}):');
      print(response.body);
      throw ApiException('Gagal memproses respons dari server. Status: ${response.statusCode}');
    }

    if (errorBody == null) {
      throw ApiException('Terjadi kesalahan tidak diketahui.');
    }

    if (response.statusCode == 422 && errorBody.containsKey('errors')) {
      throw ApiException(
        errorBody['message'] ?? 'Data yang diberikan tidak valid.',
        errorBody['errors'] as Map<String, dynamic>,
      );
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
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.trim() == '[]') return [];
        if (!response.headers['content-type']!.contains('application/json')) {
          print('Server returned non-JSON response for getTrips:');
          print(response.body);
          throw ApiException('Server tidak memberikan respons JSON yang valid.');
        }
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Trip.fromJson(json)).toList();
      } else {
        _handleResponse(response);
        return [];
      }
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on FormatException catch (e) {
      print('Failed to decode JSON: $e');
      throw ApiException('Gagal mem-parsing data dari server.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip> acceptTrip(String token, int tripId) async {
    final response = await _postRequest(token, '$tripId/accept');
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> createTrip({
    required String token,
    required String projectName,
    required String origin,
    required String destination,
  }) async {
    final response = await _postRequest(
      token,
      '',
      body: {
        'project_name': projectName,
        'origin': origin,
        'destination': destination,
      },
    );
    return Trip.fromJson(json.decode(response.body)['data']);
  }

  Future<Trip> updateTrip({
    required String token,
    required int tripId,
    required String projectName,
    required String origin,
    required String destination,
  }) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/update');
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'project_name': projectName,
          'origin': origin,
          'destination': destination,
        }),
      );
      _handleResponse(response);
      return Trip.fromJson(json.decode(response.body)['data']);
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTrip(String token, int tripId) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/delete');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      _handleResponse(response);
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip> updateStartTrip({
    required String token,
    required int tripId,
    required String licensePlate,
    required String startKm,
    required File startKmPhoto,
  }) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/start');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['license_plate'] = licensePlate
      ..fields['start_km'] = startKm;

    request.files.add(await http.MultipartFile.fromPath(
      'start_km_photo',
      startKmPhoto.path,
      filename: basename(startKmPhoto.path),
    ));

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

  Future<Trip> updateAfterLoading({
    required String token,
    required int tripId,
    required File muatPhoto,
    required List<File> deliveryLetters,
  }) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/after-loading');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    request.files.add(await http.MultipartFile.fromPath(
      'muat_photo',
      muatPhoto.path,
      filename: basename(muatPhoto.path),
    ));

    for (var file in deliveryLetters) {
      request.files.add(await http.MultipartFile.fromPath(
        'delivery_letters[]',
        file.path,
        filename: basename(file.path),
      ));
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

  Future<Trip> updateFinishTrip({
    required String token,
    required int tripId,
    required String endKm,
    required File endKmPhoto,
    required File bongkarPhoto,
    required List<File> deliveryLetters,
  }) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/finish');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['end_km'] = endKm;

    request.files.add(await http.MultipartFile.fromPath(
      'bongkar_photo',
      bongkarPhoto.path,
      filename: basename(bongkarPhoto.path),
    ));

    request.files.add(await http.MultipartFile.fromPath(
      'end_km_photo',
      endKmPhoto.path,
      filename: basename(endKmPhoto.path),
    ));

    for (var file in deliveryLetters) {
      request.files.add(await http.MultipartFile.fromPath(
        'delivery_letters[]',
        file.path,
        filename: basename(file.path),
      ));
    }

    final response = await _multipartPostRequest(request);
    return Trip.fromJson(json.decode(response.body)['data']);
  }
}
