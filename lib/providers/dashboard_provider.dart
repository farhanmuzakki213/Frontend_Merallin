// lib/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:frontend_merallin/services/attendance_service.dart';
import 'package:frontend_merallin/services/izin_service.dart';

class DashboardProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final IzinService _izinService = IzinService();

  bool _isLoading = false;
  String? _errorMessage;
  int _hadirCount = 0;
  int _sakitCount = 0;
  int _izinCount = 0;
  String? _token;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get hadirCount => _hadirCount;
  int get sakitCount => _sakitCount;
  int get izinCount => _izinCount;

  void updateToken(String? newToken) {
    if (newToken != null && _token != newToken) {
      _token = newToken;
      fetchDashboardData();
    }
  }

  Future<void> fetchDashboardData() async {
    if (_token == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _attendanceService.getAttendanceHistory(_token!),
        _izinService.getLeaveHistory(_token!),
      ]);

      // --- PERBAIKAN 1: Menghapus 'as List<dynamic>' yang tidak perlu ---
      final attendances = results[0];
      final now = DateTime.now();
      _hadirCount = (attendances as List).where((att) {
        final attendanceDate = att.createdAt as DateTime;
        return attendanceDate.month == now.month &&
            attendanceDate.year == now.year;
      }).length;

      // --- PERBAIKAN 2: Menghapus 'as List<Izin>' yang tidak perlu ---
      final leaveRequests = results[1];
      _sakitCount = (leaveRequests as List).where((izin) {
        final izinDate = izin.tanggalMulai;
        return izin.jenisIzin == LeaveType.sakit &&
            izinDate.month == now.month &&
            izinDate.year == now.year;
      }).length;

      _izinCount = (leaveRequests as List).where((izin) {
        final izinDate = izin.tanggalMulai;
        return izin.jenisIzin == LeaveType.kepentinganKeluarga &&
            izinDate.month == now.month &&
            izinDate.year == now.year;
      }).length;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}