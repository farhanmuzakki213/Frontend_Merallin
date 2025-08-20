// lib/services/trip_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/trip_model.dart';

/// Custom Exception for API-related errors.
///
/// Contains a user-friendly [message] and an optional map of [errors]
/// for validation failures.
class ApiException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.message, [this.errors]);

  /// Provides a string representation of the exception.
  ///
  /// If validation errors are present, it concatenates them into a
  /// single string. Otherwise, it returns the main message.
  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      // Join all error messages from the map into a single string.
      return errors!.values
          .map((value) => value is List ? value.join(' ') : value)
          .join('');
    }
    return message;
  }
}

class TripService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  /// Handles response status codes and throws an [ApiException] on failure.
  ///
  /// Decodes the JSON response body to extract error messages.
  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Request was successful
      return;
    }

    Map<String, dynamic>? errorBody;
    try {
      errorBody = json.decode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      // The body wasn't a valid JSON.
      throw ApiException('Gagal memproses respons dari server.');
    }

    if (errorBody == null) {
      throw ApiException('Terjadi kesalahan tidak diketahui.');
    }

    // For validation errors (422), pass the detailed errors map.
    if (response.statusCode == 422 && errorBody.containsKey('errors')) {
      throw ApiException(
        errorBody['message'] ?? 'Data yang diberikan tidak valid.',
        errorBody['errors'] as Map<String, dynamic>,
      );
    }

    // For other errors, use the main message.
    throw ApiException(errorBody['message'] ?? 'Terjadi kesalahan pada server.');
  }

  /// Generic helper for POST requests without a body.
  Future<void> _postRequest(String token, String endpoint) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$endpoint');

    try {
      final response = await http.post(
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
      rethrow; // Rethrow ApiException or other exceptions
    }
  }

  /// Generic helper for multipart (file upload) POST requests.
  Future<void> _multipartPostRequest(http.MultipartRequest request) async {
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _handleResponse(response);
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
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Trip.fromJson(json)).toList();
      } else {
        _handleResponse(response); // This will throw ApiException
        return []; // Should not be reached
      }
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptTrip(String token, int tripId) async {
     if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips/$tripId/accept');
    try {
      final response = await http.post(
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

  Future<Trip> createTrip({
    required String token,
    required String projectName,
    required String origin,
    required String destination,
  }) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/trips');
    try {
      final response = await http.post(
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

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Trip.fromJson(json.decode(response.body)['data']);
      } else {
        _handleResponse(response);
        throw StateError('Should not be reached');
      }
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> updateTrip({
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

  Future<void> updateStartTrip({
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

    await _multipartPostRequest(request);
  }

  Future<void> updateToLoadingPoint({required String token, required int tripId}) async {
    await _postRequest(token, '$tripId/at-loading');
  }

  Future<void> finishLoading({required String token, required int tripId}) async {
    await _postRequest(token, '$tripId/finish-loading');
  }

  Future<void> updateAfterLoading({
    required String token,
    required int tripId,
    required File muatPhoto,
    required File deliveryLetter,
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
    request.files.add(await http.MultipartFile.fromPath(
      'delivery_letter',
      deliveryLetter.path,
      filename: basename(deliveryLetter.path),
    ));

    await _multipartPostRequest(request);
  }

  Future<void> updateToUnloadingPoint({required String token, required int tripId}) async {
    await _postRequest(token, '$tripId/at-unloading');
  }

  Future<void> finishUnloading({required String token, required int tripId}) async {
    await _postRequest(token, '$tripId/finish-unloading');
  }

  Future<void> updateFinishTrip({
    required String token,
    required int tripId,
    required String endKm,
    required File endKmPhoto,
    required File bongkarPhoto,
    required File deliveryLetter,
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
    request.files.add(await http.MultipartFile.fromPath(
      'delivery_letter',
      deliveryLetter.path,
      filename: basename(deliveryLetter.path),
    ));

    await _multipartPostRequest(request);
  }
}