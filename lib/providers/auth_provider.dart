import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  uninitialized, // Status awal, saat aplikasi baru dibuka
  authenticated, // Pengguna berhasil login dan punya token
  authenticating, // Sedang dalam proses login/register
  unauthenticated, // Pengguna belum login atau token tidak valid
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final Box _authBox = Hive.box('authBox');

  User? _user;
  String? _token;
  String? _errorMessage;
  // 2. Ganti _isLoading dengan _authStatus
  AuthStatus _authStatus = AuthStatus.uninitialized;

  // Getter untuk UI
  User? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  AuthStatus get authStatus => _authStatus;

  AuthProvider() {
    // 3. Panggil tryAutoLogin dari konstruktor
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    // Saat aplikasi mulai, statusnya adalah sedang mengautentikasi
    _authStatus = AuthStatus.authenticating;
    notifyListeners();

    final storedToken = _authBox.get('token');

    if (storedToken == null) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Di sini Anda bisa menambahkan validasi token ke server jika perlu
    // Untuk saat ini, kita anggap token yang ada sudah valid.
    _token = storedToken;
    _authStatus = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _authStatus = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      _user = result['user'];
      _token = result['token'];
      await _authBox.put('token', _token);

      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _errorMessage = errorMessage;
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return errorMessage;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String phone, // Tambahkan ini
    required String address, // Tambahkan ini
  }) async {
    _authStatus = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        phone: phone, // Tambahkan ini
        address: address, // Tambahkan ini
      );
      // Setelah register, arahkan ke unauthenticated (halaman login)
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _authBox.delete('token');
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
