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

  Future<void> clockIn(File image, String token, String attendanceStatus) async {
    _status = AttendanceStatus.processing;
    _message = 'Memproses absensi datang...';
    notifyListeners();

    try {
      await _attendanceService.submitAttendance(image, token,'datang', attendanceStatus);
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

  Future<void> clockOut(File image, String token, String attendanceStatus) async {
    _status = AttendanceStatus.processing;
    _message = 'Memproses absensi pulang...';
    notifyListeners();

    try {
      await _attendanceService.submitAttendance(image, token, 'pulang', attendanceStatus);
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
