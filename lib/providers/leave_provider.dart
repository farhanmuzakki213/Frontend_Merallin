// lib/providers/leave_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:frontend_merallin/services/izin_service.dart';

enum DataStatus { initial, loading, success, error }

class LeaveProvider extends ChangeNotifier {
  final IzinService _izinService = IzinService();

  DataStatus _submissionStatus = DataStatus.initial;
  String? _submissionMessage;
  DataStatus get submissionStatus => _submissionStatus;
  String? get submissionMessage => _submissionMessage;

  DataStatus _historyStatus = DataStatus.initial;
  String? _historyMessage;
  List<Izin> _leaveHistory = [];
  DataStatus get historyStatus => _historyStatus;
  String? get historyMessage => _historyMessage;
  List<Izin> get leaveHistory => _leaveHistory;

  Future<void> fetchLeaveHistory(String token) async {
    _historyStatus = DataStatus.loading;
    notifyListeners();
    try {
      _leaveHistory = await _izinService.getLeaveHistory(token);
      _historyStatus = DataStatus.success;
    } catch (e) {
      _historyStatus = DataStatus.error;
      _historyMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> submitLeave({
    required String token,
    required LeaveType jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    String? alasan,
    // Menggunakan File, agar sesuai dengan Service
    File? fileBukti,
  }) async {
    _submissionStatus = DataStatus.loading;
    notifyListeners();

    try {
      final newLeaveRequest = await _izinService.submitLeaveRequest(
        token: token,
        jenisIzin: jenisIzin,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        alasan: alasan,
        // Mengirim parameter fileBukti
        fileBukti: fileBukti,
      );

      _leaveHistory.insert(0, newLeaveRequest);
      _submissionStatus = DataStatus.success;
    } catch (e) {
      _submissionStatus = DataStatus.error;
      _submissionMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }
}