// lib/services/id_card_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class IdCardService {
  final String? _baseUrl = dotenv.env['API_BASE_URL'];

  Future<User> fetchUserProfile(String token) async {
    if (_baseUrl == null) throw Exception("API_BASE_URL tidak ditemukan");
    
    final response = await http.get(
      Uri.parse('$_baseUrl/user'),
      headers: { 'Accept': 'application/json', 'Authorization': 'Bearer $token' },
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Gagal memuat profil pengguna.');
    }
  }

  Future<String> downloadAndCachePdf(String url, String token) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/id_card.pdf').create();
      await file.writeAsBytes(bytes);
      return file.path;
    } else {
      throw Exception('Gagal mengunduh ID Card. Status: ${response.statusCode}');
    }
  }
}