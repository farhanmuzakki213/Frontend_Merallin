import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/services/attendance_service.dart';

enum AttendanceStatus { idle, processing, success, error }

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  AttendanceStatus _status = AttendanceStatus.idle;
  String? _message;
  bool _hasClockedIn = false;
  bool _hasClockedOut = false;

  AttendanceStatus get status => _status;
  String? get message => _message;
  bool get hasClockedIn => _hasClockedIn;
  bool get hasClockedOut => _hasClockedOut;

  Future<void> checkTodayAttendanceStatus(String token) async {
    try {
      final status = await _attendanceService.getTodayAttendanceStatus(token);
      _hasClockedIn = status['clock_in'] != null;
      _hasClockedOut = status['clock_out'] != null;
      notifyListeners();
    } catch (e) {
      print("Gagal memeriksa status absensi: $e");
    }
  }

  Future<void> clockIn(File image, String token) async {
    _status = AttendanceStatus.processing;
    _message = 'Memproses absensi datang...';
    notifyListeners();

    try {
      await _attendanceService.performClockIn(image, token);
      _status = AttendanceStatus.success;
      _message = 'Absensi Datang berhasil direkam!';
      _hasClockedIn = true;
      notifyListeners();
    } catch (e) {
      _status = AttendanceStatus.error;
      _message = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> clockOut(File image, String token) async {
    _status = AttendanceStatus.processing;
    _message = 'Memproses absensi pulang...';
    notifyListeners();

    try {
      await _attendanceService.performClockOut(image, token);
      _status = AttendanceStatus.success;
      _message = 'Absensi Pulang berhasil direkam!';
      _hasClockedOut = true;
      notifyListeners();
    } catch (e) {
      _status = AttendanceStatus.error;
      _message = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}
