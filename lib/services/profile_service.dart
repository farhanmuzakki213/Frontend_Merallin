import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart'; // TAMBAHKAN import ini

class ProfileService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  // UBAH tipe data return menjadi Future<User>
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

      // Field wajib
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['alamat'] = address;
      request.fields['no_telepon'] = phone;

      // Upload foto profil jika ada
      if (profilePhoto != null) {
        final mimeTypeData = lookupMimeType(profilePhoto.path)?.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'photo', // <-- UBAH KEY dari 'profile_photo_path' menjadi 'photo'
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
        // API mengembalikan user object di dalam key 'user'
        return User.fromJson(decoded['user']);
      } else if (response.statusCode == 422) {
        // Handle error validasi
        final errors = decoded['errors'] as Map<String, dynamic>;
        final errorMessage = errors.values.map((e) => e[0]).join('\n');
        throw Exception(errorMessage);
      } else {
        throw Exception(decoded['message'] ?? 'Gagal memperbarui profil');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      // Lempar kembali error yang sudah diformat atau error baru
      rethrow;
    }
  }
}