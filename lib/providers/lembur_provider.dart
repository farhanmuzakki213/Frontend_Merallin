// lib/providers/lembur_provider.dart

import 'package:flutter/foundation.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:frontend_merallin/services/lembur_service.dart';

enum DataStatus { initial, loading, success, error }

class LemburProvider with ChangeNotifier {
  final LemburService _lemburService = LemburService();

  // State untuk riwayat lembur
  DataStatus _historyStatus = DataStatus.initial;
  DataStatus get historyStatus => _historyStatus;

  List<Lembur> _overtimeHistory = [];
  List<Lembur> get overtimeHistory => _overtimeHistory;

  String? _historyMessage;
  String? get historyMessage => _historyMessage;

  // State untuk pengajuan lembur
  DataStatus _submissionStatus = DataStatus.initial;
  DataStatus get submissionStatus => _submissionStatus;

  String? _submissionMessage;
  String? get submissionMessage => _submissionMessage;

  // Fungsi untuk mengambil riwayat lembur
  Future<void> fetchOvertimeHistory(String token) async {
    _historyStatus = DataStatus.loading;
    notifyListeners();

    try {
      _overtimeHistory = await _lemburService.getOvertimeHistory(token);
      _historyStatus = DataStatus.success;
    } catch (e) {
      _historyMessage = e.toString();
      _historyStatus = DataStatus.error;
    }
    notifyListeners();
  }

  // Fungsi untuk mengirim pengajuan lembur baru
  Future<void> submitOvertime({
    required String token,
    required JenisHariLembur jenisHari,
    required DepartmentLembur department,
    required DateTime tanggalLembur,
    required String keteranganLembur,
    required String mulaiJamLembur,
    required String selesaiJamLembur,
  }) async {
    _submissionStatus = DataStatus.loading;
    _submissionMessage = null; // Reset pesan error sebelumnya
    notifyListeners();

    try {
      await _lemburService.submitOvertimeRequest(
        token: token,
        jenisHari: jenisHari,
        department: department,
        tanggalLembur: tanggalLembur,
        keteranganLembur: keteranganLembur,
        mulaiJamLembur: mulaiJamLembur,
        selesaiJamLembur: selesaiJamLembur,
      );
      _submissionStatus = DataStatus.success;
      _submissionMessage = 'Pengajuan lembur berhasil dikirim.';
      // Setelah berhasil, langsung muat ulang data riwayat
      await fetchOvertimeHistory(token);
    } catch (e) {
      _submissionMessage = e.toString();
      _submissionStatus = DataStatus.error;
    }
    notifyListeners();
  }
}