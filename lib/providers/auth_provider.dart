// lib/providers/auth_provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/navigation_service.dart';
import '../services/profile_service.dart';
import '../main.dart';

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

  DateTime? _lastSessionCheck;

  User? _user;
  String? _token;
  String? _errorMessage;
  AuthStatus _authStatus = AuthStatus.uninitialized;
  int? _pendingTripId;
  int? _pendingBbmId;
  int? _pendingVehicleLocationId;

  bool get isUpdating => _isUpdating;
  int? get pendingTripId => _pendingTripId;
  int? get pendingBbmId => _pendingBbmId;
  int? get pendingVehicleLocationId => _pendingVehicleLocationId;

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

    try {
      _token = storedToken as String;
      _user = User.fromJson(json.decode(storedUser as String));

      final storedPendingTripId = _authBox.get('pendingTripId');
      if (storedPendingTripId != null) {
        _pendingTripId = storedPendingTripId as int;
      }
      final storedPendingBbmId = _authBox.get('pendingBbmId');
      if (storedPendingBbmId != null) {
        _pendingBbmId = storedPendingBbmId as int;
      }
      final storedPendingLocationId = _authBox.get('pendingVehicleLocationId');
      if (storedPendingLocationId != null) {
        _pendingVehicleLocationId = storedPendingLocationId as int;
      }

      _authStatus = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint("Gagal memuat sesi dari Hive: $e. Sesi dibersihkan.");
      await logout();
    }
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

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _authBox.clear();
    await clearPendingTripForVerification();
    await clearPendingBbmForVerification();
    await clearPendingVehicleLocationForVerification();
    _authStatus = AuthStatus.unauthenticated;

    notifyListeners();

    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> handleInvalidSession() async {
    if (_authStatus == AuthStatus.authenticated) {
      debugPrint("5. DIALOG 'SESI BERAKHIR' SEHARUSNYA MUNCUL SEKARANG.");
      final BuildContext? context = NavigationService.currentContext;
      if (context != null && context.mounted) {
        if (ModalRoute.of(context)?.isCurrent != true) {
          Navigator.of(context).pop();
        }
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sesi Berakhir'),
              content: const Text(
                  'Sesi Anda telah berakhir atau login dari perangkat lain.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      }
      await logout();
    }
  }

  Future<bool> checkActiveSession() async {
    if (token == null || _authStatus != AuthStatus.authenticated) {
      return false;
    }

    try {
      await _profileService.getProfile(token: token!);
      return true;
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated.')) {
        debugPrint(
            "Sesi tidak valid terdeteksi oleh checkActiveSession! Memanggil handleInvalidSession...");
        handleInvalidSession();
      } else {
        debugPrint("Error saat checkActiveSession: $errorString");
      }
      return false;
    }
  }

  Future<void> syncUserProfile() async {
    if (token == null || _authStatus != AuthStatus.authenticated) {
      return;
    }

    final now = DateTime.now();
    if (_lastSessionCheck != null &&
        now.difference(_lastSessionCheck!).inMinutes < 5) {
      return;
    }

    try {
      debugPrint(
          "1. MEMERIKSA SESI: API profil dipanggil karena ada aksi dari user...");

      _lastSessionCheck = now;

      await _profileService.getProfile(token: token!);
      debugPrint("   -> Panggilan API Profil Berhasil (Sesi Masih Valid).");
    } catch (e) {
      _lastSessionCheck = null;

      final errorString = e.toString();
      debugPrint("2. API PROFIL GAGAL! Eror: $errorString");
      if (errorString.contains('Unauthenticated.')) {
        debugPrint(
            "3. SESI TIDAK VALID TERDETEKSI! Memanggil handleInvalidSession...");
        await handleInvalidSession();
      }
    }
  }

  Future<void> setPendingTripForVerification(int tripId) async {
    _pendingTripId = tripId;
    await _authBox.put('pendingTripId', tripId);
    notifyListeners();
  }

  Future<void> setPendingBbmForVerification(int bbmId) async {
    _pendingBbmId = bbmId;
    await _authBox.put('pendingBbmId', bbmId);
    notifyListeners();
  }

  Future<void> setPendingVehicleLocationForVerification(int locationId) async {
    _pendingVehicleLocationId = locationId;
    await _authBox.put('pendingVehicleLocationId', locationId);
    notifyListeners();
  }

  Future<void> clearPendingTripForVerification() async {
    _pendingTripId = null;
    await _authBox.delete('pendingTripId');
    notifyListeners();
  }

  Future<void> clearPendingBbmForVerification() async {
    _pendingBbmId = null;
    await _authBox.delete('pendingBbmId');
    notifyListeners();
  }

  Future<void> clearPendingVehicleLocationForVerification() async {
    _pendingVehicleLocationId = null;
    await _authBox.delete('pendingVehicleLocationId');
    notifyListeners();
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
    required BuildContext context,
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (_token == null) return 'Anda tidak terautentikasi.';

    _isUpdating = true;
    notifyListeners();

    try {
      await _authService.updatePassword(
        context: context,
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return _errorMessage;
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
}
