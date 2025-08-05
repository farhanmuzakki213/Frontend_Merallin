import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  // Ganti dengan IP address atau domain backend Anda
  final String _baseUrl = 'http://3.216.172.183/api';
  final Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final user = User.fromJson(responseBody['user']);
        final token = responseBody['token'];
        return {'user': user, 'token': token};
      } else if (response.statusCode == 401) {
        throw Exception('Email atau password salah');
      } else if (response.statusCode == 500) {
        throw Exception('Server sedang mengalami masalah');
      } else {
        final responseBody = json.decode(response.body);
        throw Exception(responseBody['message'] ?? 'Login gagal');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server');
    } on http.ClientException {
      throw Exception('Timeout koneksi');
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // Metode register juga perlu penanganan error yang serupa
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String phone, // Tambahkan ini
    required String address, // Tambahkan ini
  }) async {
    final url = Uri.parse('$_baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'no_telepon': phone, // Sesuaikan dengan nama field di API
          'alamat': address,
        }),
      );

      // Status 201 (Created) menandakan registrasi berhasil
      if (response.statusCode == 201) {
        // Registrasi berhasil, tidak perlu melakukan apa-apa
        return;
      } else if (response.statusCode == 422) {
        // Menangani error validasi (input tidak sesuai)
        final responseBody = json.decode(response.body);
        final errors = responseBody['errors'] as Map<String, dynamic>;
        // Ambil pesan error pertama dari daftar error
        final errorMessage = errors.values.map((e) => e[0]).join('\n');
        throw Exception(errorMessage);
      } else {
        // Menangani error lainnya saat registrasi
        final responseBody = json.decode(response.body);
        throw Exception(responseBody['message'] ?? 'Registrasi Gagal');
      }
    } on SocketException {
      // Menangani error koneksi internet
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi Anda.');
    } catch (e) {
      // Menangani error lainnya
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }
}
