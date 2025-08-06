import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/services/attendance_service.dart';

enum AttendanceStatus { idle, processing, success, error }

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  AttendanceStatus _status = AttendanceStatus.idle;
  String? _message;

  AttendanceStatus get status => _status;
  String? get message => _message;

  Future<void> clockIn(File image, String token) async {
    _status = AttendanceStatus.processing;
    _message = 'Memproses absensi...';
    notifyListeners();

    try {
      await _attendanceService.performAttendance(image, token);
      _status = AttendanceStatus.success;
      _message = 'Absensi berhasil direkam!';
      notifyListeners();
    } catch (e) {
      _status = AttendanceStatus.error;
      _message = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    } finally {
      Future.delayed(const Duration(seconds: 4), () {
        if (status != AttendanceStatus.processing) {
          _status = AttendanceStatus.idle;
          notifyListeners();
        }
      });
    }
  }
}