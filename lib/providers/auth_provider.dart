import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  updating,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final Box _authBox = Hive.box('authBox');
  bool _isUpdating = false;

  User? _user;
  String? _token;
  String? _errorMessage;
  AuthStatus _authStatus = AuthStatus.uninitialized;
  bool get isUpdating => _isUpdating;

  User? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  AuthStatus get authStatus => _authStatus;

  AuthProvider() {
    tryAutoLogin();
  }

  Future<void> tryAutoLogin() async {
    final storedToken = _authBox.get('token');
    final storedUser = _authBox.get('user');

    if (storedToken == null || storedUser == null) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _token = storedToken;
    _user = User.fromJson(json.decode(storedUser));
    _authStatus = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _authStatus = AuthStatus.authenticating;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      _user = result['user'];
      _token = result['token'];

      await _authBox.put('token', _token);
      await _authBox.put('user', json.encode(_user!.toJson()));

      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String phone,
    required String address,
  }) async {
    _authStatus = AuthStatus.authenticating;
    notifyListeners();

    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        phone: phone,
        address: address,
      );
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (_token == null) return 'Anda tidak terautentikasi.';

    _isUpdating = true;
    notifyListeners();

    try {
      await _authService.updatePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      return null; // Sukses
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return _errorMessage; // Gagal, kembalikan pesan error
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserProfile({
    required String name,
    required String address,
    required String phone,
    File? profilePhoto,
  }) async {
    if (_user == null || _token == null) return false;

    _authStatus = AuthStatus.updating;
    notifyListeners();

    try {
      final updatedUser = await _profileService.updateProfile(
        token: _token!,
        name: name,
        email: _user!.email,
        address: address,
        phone: phone,
        profilePhoto: profilePhoto,
      );
      _user = updatedUser;
      await _authBox.put('user', json.encode(_user!.toJson()));
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _authStatus = AuthStatus.authenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _authBox.clear();
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
