// lib/services/payslip_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/payslip_model.dart';
import 'package:http/http.dart' as http;

class PayslipService {
  final String? _baseUrl = dotenv.env['API_BASE_URL'];

  Future<List<PayslipSummary>> getSummaries(String token) async {
    if (_baseUrl == null) {
      throw Exception("API_URL tidak ditemukan di .env");
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/salary-slips'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      // Backend mengembalikan object dengan key 'data'
      final List<dynamic> slipsJson = responseData['data']; 
      return slipsJson.map((json) => PayslipSummary.fromJson(json)).toList();
    } else {
      // Coba decode pesan error dari backend jika ada
      try {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Gagal memuat data slip gaji';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Gagal memuat data slip gaji. Status: ${response.statusCode}');
      }
    }
  }
}