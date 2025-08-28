import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/services/attendance_service.dart';
import 'package:geolocator/geolocator.dart';

enum AttendanceProcessStatus { idle, processing, success, error }

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  AttendanceProcessStatus _status = AttendanceProcessStatus.idle;
  String? _message;
  bool _hasClockedIn = false;
  bool _hasClockedOut = false;

  AttendanceProcessStatus get status => _status;
  String? get message => _message;
  bool get hasClockedIn => _hasClockedIn;
  bool get hasClockedOut => _hasClockedOut;

  Future<void> checkTodayAttendanceStatus(String token) async {
    try {
      final statusResult = await _attendanceService.checkStatusToday(token);
      _hasClockedIn = statusResult['has_clocked_in'] ?? false;
      _hasClockedOut = statusResult['has_clocked_out'] ?? false;
      notifyListeners();
    } catch (e) {
      print("Gagal cek status: $e");
    }
  }

  Future<void> performClockIn(File image, String token) async {
    _status = AttendanceProcessStatus.processing;
    notifyListeners();
    try {
      await _attendanceService.clockIn(image, token);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Datang berhasil direkam!';
      await checkTodayAttendanceStatus(token);
    } catch (e) {
      _status = AttendanceProcessStatus.error;
      _message = e.toString();
      notifyListeners();
    } finally {
      _status = AttendanceProcessStatus.idle;
      notifyListeners();
    }
  }

  Future<void> performClockInWithLocation(
      File image, String token, Position position) async {
    _status = AttendanceProcessStatus.processing;
    notifyListeners();
    try {
      await _attendanceService.clockInWithLocation(
          image, token, position.latitude, position.longitude);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Datang berhasil direkam!';
      await checkTodayAttendanceStatus(token);
    } catch (e) {
      _status = AttendanceProcessStatus.error;
      _message = e.toString();
      notifyListeners();
    } finally {
      _status = AttendanceProcessStatus.idle;
      notifyListeners();
    }
  }

  Future<void> performClockOut(File image, String token) async {
    _status = AttendanceProcessStatus.processing;
    notifyListeners();
    try {
      await _attendanceService.clockOut(image, token);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Pulang berhasil direkam!';
      await checkTodayAttendanceStatus(token);
    } catch (e) {
      _status = AttendanceProcessStatus.error;
      _message = e.toString();
      notifyListeners();
    } finally {
      _status = AttendanceProcessStatus.idle;
      notifyListeners();
    }
  }
}
