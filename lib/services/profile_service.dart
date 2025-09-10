// lib/services/profile_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class ProfileService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  Future<User> getProfile({required String token}) async {
    final url = Uri.parse('$_baseUrl/user/profile');
    try {
      // ===== PERUBAHAN DI SINI: get diubah menjadi post =====
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      // ===== AKHIR PERUBAHAN =====

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return User.fromJson(decoded['user'] ?? decoded);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthenticated.');
      } else {
        throw Exception(decoded['message'] ?? 'Gagal mengambil data profil');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server.');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateProfile({
    required String token,
    required String name,
    required String email,
    required String address,
    required String phone,
    File? profilePhoto,
  }) async {
    final url = Uri.parse('$_baseUrl/user/profile');

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['alamat'] = address;
      request.fields['no_telepon'] = phone;

      if (profilePhoto != null) {
        final mimeTypeData = lookupMimeType(profilePhoto.path)?.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          profilePhoto.path,
          contentType: mimeTypeData != null
              ? MediaType(mimeTypeData[0], mimeTypeData[1])
              : null,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return User.fromJson(decoded['user']);
      } else {
        final errors = decoded['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final errorMessage = errors.values.map((e) => e[0]).join('\n');
          throw Exception(errorMessage);
        }
        throw Exception(decoded['message'] ?? 'Gagal memperbarui profil');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server.');
    } catch (e) {
      rethrow;
    }
  }
}