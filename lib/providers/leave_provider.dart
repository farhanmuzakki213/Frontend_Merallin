// lib/providers/leave_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:frontend_merallin/services/izin_service.dart';
import 'auth_provider.dart'; // Import AuthProvider

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

  Future<void> fetchLeaveHistory({
    required BuildContext context,
    required String token,
  }) async {
    _historyStatus = DataStatus.loading;
    notifyListeners();
    try {
      _leaveHistory = await _izinService.getLeaveHistory(token);
      _historyStatus = DataStatus.success;
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _historyStatus = DataStatus.error;
        _historyMessage = errorString.replaceFirst('Exception: ', '');
      }
      // ===== AKHIR PERBAIKAN =====
    }
    notifyListeners();
  }

  Future<void> submitLeave({
    required BuildContext context,
    required String token,
    required LeaveType jenisIzin,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
    String? alasan,
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
        fileBukti: fileBukti,
      );

      _leaveHistory.insert(0, newLeaveRequest);
      _submissionStatus = DataStatus.success;
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _submissionStatus = DataStatus.error;
        _submissionMessage = errorString.replaceFirst('Exception: ', '');
      }
      // ===== AKHIR PERBAIKAN =====
    }
    notifyListeners();
  }
}