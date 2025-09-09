// lib/providers/id_card_provider.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/services/id_card_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum IdCardStatus { initial, loading, success, error }

class IdCardProvider with ChangeNotifier {
  final IdCardService _idCardService = IdCardService();
  String? _token;

  // ===== KODE UNTUK RIWAYAT DOWNLOAD =====
  final Box<bool> _statusBox = Hive.box<bool>('idCardStatusBox');
  // Cek apakah ID Card sudah pernah di-download
  bool get hasBeenDownloaded => _statusBox.get('idCardDownloaded', defaultValue: false) ?? false;

  // Tandai bahwa ID Card sudah di-download
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

  Future<void> fetchIdCard() async {
    if (_token == null) {
      _status = IdCardStatus.error;
      _errorMessage = "Sesi tidak valid.";
      notifyListeners();
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
      _status = IdCardStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }
}