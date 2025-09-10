// lib/providers/payslip_provider.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:frontend_merallin/models/payslip_model.dart';
import 'package:frontend_merallin/services/payslip_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_provider.dart'; // Import AuthProvider

class PayslipProvider with ChangeNotifier {
  String? _token;
  final PayslipService _payslipService = PayslipService();

  final Box<int> _historyBox = Hive.box<int>('downloadedSlipsBox');
  
  Set<int> get downloadedSlipIds => _historyBox.values.toSet();

  void addDownloadedSlipId(int id) {
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

  Future<void> fetchPayslipSummaries({required BuildContext context}) async {
    if (_token == null) {
      _errorMessage = "Sesi tidak valid. Silakan login ulang.";
      notifyListeners();
      // Panggil juga handleInvalidSession untuk kasus di mana token sudah null
      Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summaries = await _payslipService.getSummaries(_token!);
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _errorMessage = errorString.replaceFirst('Exception: ', '');
      }
      // ===== AKHIR PERBAIKAN =====
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}