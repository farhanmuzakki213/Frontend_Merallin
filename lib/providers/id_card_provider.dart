// lib/providers/id_card_provider.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:frontend_merallin/services/id_card_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_provider.dart'; // Import AuthProvider

enum IdCardStatus { initial, loading, success, error }

class IdCardProvider with ChangeNotifier {
  final IdCardService _idCardService = IdCardService();
  String? _token;

  final Box<bool> _statusBox = Hive.box<bool>('idCardStatusBox');
  bool get hasBeenDownloaded => _statusBox.get('idCardDownloaded', defaultValue: false) ?? false;

  void setAsDownloaded() {
    _statusBox.put('idCardDownloaded', true);
    notifyListeners();
  }

  IdCardStatus _status = IdCardStatus.initial;
  String? _errorMessage;
  String? _pdfPath;

  IdCardStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get pdfPath => _pdfPath;

  void updateToken(String? token) {
    _token = token;
  }

  Future<void> fetchIdCard({required BuildContext context}) async {
    if (_token == null) {
      _status = IdCardStatus.error;
      _errorMessage = "Sesi tidak valid.";
      notifyListeners();
      Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      return;
    }

    _status = IdCardStatus.loading;
    notifyListeners();

    try {
      final user = await _idCardService.fetchUserProfile(_token!);
      final idCardUrl = user.idCardUrl;

      if (idCardUrl == null || idCardUrl.isEmpty) {
        throw Exception('File ID Card tidak ditemukan untuk pengguna ini.');
      }

      _pdfPath = await _idCardService.downloadAndCachePdf(idCardUrl, _token!);
      _status = IdCardStatus.success;
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _status = IdCardStatus.error;
        _errorMessage = errorString.replaceFirst('Exception: ', '');
      }
      // ===== AKHIR PERBAIKAN =====
    }
    notifyListeners();
  }
}