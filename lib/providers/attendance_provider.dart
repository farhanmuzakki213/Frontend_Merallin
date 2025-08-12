import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/services/attendance_service.dart';
import 'package:frontend_merallin/models/attendance_history_model.dart';

enum DataStatus { initial, loading, success, error }

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  // State untuk Proses Absensi
  DataStatus _attendanceStatus = DataStatus.initial;
  String? _attendanceMessage;
  bool _hasClockedIn = false;
  bool _hasClockedOut = false;

  DataStatus get attendanceStatus => _attendanceStatus;
  String? get attendanceMessage => _attendanceMessage;
  bool get hasClockedIn => _hasClockedIn;
  bool get hasClockedOut => _hasClockedOut;

  // State untuk Riwayat Absensi
  DataStatus _historyStatus = DataStatus.initial;
  String? _historyMessage;
  List<AttendanceHistory> _historyList = [];

  DataStatus get historyStatus => _historyStatus;
  String? get historyMessage => _historyMessage;
  List<AttendanceHistory> get historyList => _historyList;

  Future<void> clockIn(File image, String token) async {
    _attendanceStatus = DataStatus.loading;
    _attendanceMessage = 'Memproses absensi datang...';
    notifyListeners();

    try {
      await _attendanceService.performAttendance(image, token);
      _attendanceStatus = DataStatus.success;
      _attendanceMessage = 'Absensi Datang berhasil direkam!';
      _hasClockedIn = true;
    } catch (e) {
      _attendanceStatus = DataStatus.error;
      _attendanceMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> clockOut(File image, String token) async {
    _attendanceStatus = DataStatus.loading;
    _attendanceMessage = 'Memproses absensi pulang...';
    notifyListeners();

    try {
      await _attendanceService.performAttendance(image, token);
      _attendanceStatus = DataStatus.success;
      _attendanceMessage = 'Absensi Pulang berhasil direkam!';
      _hasClockedOut = true;
    } catch (e) {
      _attendanceStatus = DataStatus.error;
      _attendanceMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> fetchHistory(String token) async {
    _historyStatus = DataStatus.loading;
    notifyListeners();

    try {
      _historyList = await _attendanceService.getAttendanceHistory(token);
      _historyStatus = DataStatus.success;
    } catch (e) {
      _historyStatus = DataStatus.error;
      _historyMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  // --- FUNGSI BARU UNTUK MEMBERSIHKAN STATE ---
  void reset() {
    _attendanceStatus = DataStatus.initial;
    _attendanceMessage = null;
    _hasClockedIn = false;
    _hasClockedOut = false;

    _historyStatus = DataStatus.initial;
    _historyMessage = null;
    _historyList = [];
    
    // Beri tahu widget yang mendengarkan bahwa state sudah bersih
    notifyListeners();
    debugPrint('AttendanceProvider state has been reset.');
  }
}