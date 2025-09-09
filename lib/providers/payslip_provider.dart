// lib/providers/payslip_provider.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/payslip_model.dart';
import 'package:frontend_merallin/services/payslip_service.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <-- TAMBAHKAN IMPOR HIVE

class PayslipProvider with ChangeNotifier {
  String? _token;
  final PayslipService _payslipService = PayslipService();

  // Ambil referensi ke kotak Hive yang sudah kita buka di main.dart
  final Box<int> _historyBox = Hive.box<int>('downloadedSlipsBox');
  
  // Getter untuk riwayat download sekarang membaca langsung dari Hive
  Set<int> get downloadedSlipIds => _historyBox.values.toSet();

  // Fungsi untuk menambah riwayat sekarang menulis ke Hive
  void addDownloadedSlipId(int id) {
    // Menggunakan ID slip sebagai kunci untuk mencegah duplikat
    _historyBox.put(id, id); 
    notifyListeners();
  }

  bool _isLoading = false;
  String? _errorMessage;
  List<PayslipSummary> _summaries = [];
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PayslipSummary> get summaries => _summaries;

  void updateToken(String? token) {
    _token = token;
  }

  Future<void> fetchPayslipSummaries() async {
    if (_token == null) {
      _errorMessage = "Sesi tidak valid. Silakan login ulang.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summaries = await _payslipService.getSummaries(_token!);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}