// lib/services/vehicle_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/vehicle_model.dart';
import 'trip_service.dart'; // Kita gunakan ulang ApiException

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
      
      if (response.statusCode != 200) {
        throw ApiException('Gagal memuat data kendaraan.');
      }

      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Vehicle.fromJson(json)).toList();

    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      rethrow;
    }
  }
}