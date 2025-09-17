// lib/services/vehicle_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/vehicle_model.dart';
import 'trip_service.dart'; // Untuk mengakses ApiException

class VehicleService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  Future<List<Vehicle>> getVehicles(String token) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/vehicles');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> responseBody = json.decode(response.body);
        final List<dynamic> data = (responseBody is List && responseBody.isNotEmpty && responseBody[0] is Map && responseBody[0].containsKey('data'))
            ? responseBody[0]['data']
            : responseBody;

        return data.map((json) => Vehicle.fromJson(json)).toList();
      } else {
        throw ApiException('Gagal memuat data kendaraan.');
      }
    } catch (e) {
      throw ApiException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<List<Vehicle>> getAvailableVehicles(String token) async {
    if (_baseUrl.isEmpty) throw ApiException('API URL tidak dikonfigurasi.');
    final url = Uri.parse('$_baseUrl/driver/vehicles/available-vehicles');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        // Endpoint ini mengembalikan array JSON langsung, jadi kita bisa decode langsung.
        final List<dynamic> responseBody = json.decode(response.body);
        return responseBody.map((json) => Vehicle.fromJson(json)).toList();
      } else {
        final errorBody = json.decode(response.body);
        throw ApiException(errorBody['message'] ?? 'Gagal memuat kendaraan yang tersedia.');
      }
    } catch (e) {
      throw ApiException('Terjadi kesalahan saat mengambil kendaraan tersedia: ${e.toString()}');
    }
  }
}