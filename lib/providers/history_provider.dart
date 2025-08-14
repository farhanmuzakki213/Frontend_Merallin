import 'package:flutter/material.dart';
import '../models/attendance_history_model.dart';
import '../services/history_service.dart';

enum DataStatus { idle, loading, success, error }

class HistoryProvider extends ChangeNotifier {
  final HistoryService _historyService = HistoryService();

  DataStatus _status = DataStatus.idle;
  String? _message;
  List<AttendanceHistory> _historyList = [];

  DataStatus get status => _status;
  String? get message => _message;
  List<AttendanceHistory> get historyList => _historyList;

  Future<void> getHistory(String token, DateTime date) async {
    _status = DataStatus.loading;
    notifyListeners();

    try {
      _historyList = await _historyService.fetchHistory(token, date);
      _status = DataStatus.success;
    } catch (e) {
      _status = DataStatus.error;
      _message = e.toString().replaceFirst('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }
}