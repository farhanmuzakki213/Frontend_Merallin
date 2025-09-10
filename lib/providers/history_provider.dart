// lib/providers/history_provider.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../models/attendance_history_model.dart';
import '../services/history_service.dart';
import 'auth_provider.dart'; // Import AuthProvider

enum DataStatus { idle, loading, success, error }

class HistoryProvider extends ChangeNotifier {
  final HistoryService _historyService = HistoryService();

  DataStatus _status = DataStatus.idle;
  String? _message;
  List<AttendanceHistory> _historyList = [];

  DataStatus get status => _status;
  String? get message => _message;
  List<AttendanceHistory> get historyList => _historyList;

  Future<void> getHistory({
    required BuildContext context,
    required String token,
    required DateTime date,
  }) async {
    _status = DataStatus.loading;
    notifyListeners();

    try {
      _historyList = await _historyService.fetchHistory(token, date);
      _status = DataStatus.success;
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _status = DataStatus.error;
        _message = errorString.replaceFirst('Exception: ', '');
      }
      // ===== AKHIR PERBAIKAN =====
    } finally {
      notifyListeners();
    }
  }
}