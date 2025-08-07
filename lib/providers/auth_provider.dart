import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final Box _authBox = Hive.box('authBox');

  User? _user;
  String? _token;
  String? _errorMessage;
  AuthStatus _authStatus = AuthStatus.uninitialized;

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

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _authBox.clear();
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }
}