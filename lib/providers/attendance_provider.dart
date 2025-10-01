// lib/providers/attendance_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:frontend_merallin/services/attendance_service.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_provider.dart'; // Import AuthProvider

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

  // Pola perbaikan diterapkan di semua fungsi yang memanggil API

  void resetStatus() {
    _status = AttendanceProcessStatus.idle;
    _message = null;
    notifyListeners();
  }
  
  Future<void> checkTodayAttendanceStatus({
    required BuildContext context,
    required String token,
  }) async {
    try {
      final statusResult = await _attendanceService.checkStatusToday(token);
      _hasClockedIn = statusResult['has_clocked_in'] ?? false;
      _hasClockedOut = statusResult['has_clocked_out'] ?? false;
      notifyListeners();
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        if (context.mounted) {
          Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        }
      } else {
        print("Gagal cek status: $e");
      }
    }
  }

  Future<void> performClockIn({
    required BuildContext context,
    required File image,
    required String token,
  }) async {
    _status = AttendanceProcessStatus.processing;
    _message = null;
    notifyListeners();
    try {
      await _attendanceService.clockIn(image, token);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Datang berhasil direkam!';
      await checkTodayAttendanceStatus(context: context, token: token);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _status = AttendanceProcessStatus.error;
        _message = errorString;
      }
    } finally {
      _status = AttendanceProcessStatus.idle;
      notifyListeners();
    }
  }

  Future<void> performClockInWithLocation({
    required BuildContext context,
    required File image,
    required String token,
    required Position position,
  }) async {
    _status = AttendanceProcessStatus.processing;
    _message = null;
    notifyListeners();
    try {
      await _attendanceService.clockInWithLocation(
          image, token, position.latitude, position.longitude);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Datang berhasil direkam!';
      await checkTodayAttendanceStatus(context: context, token: token);
    } catch (e) {
      final errorString = e.toString().replaceFirst('Exception: ', '');
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _status = AttendanceProcessStatus.error;
        _message = errorString;
      }
    } 
      notifyListeners();
  }

  Future<void> performClockOut({
    required BuildContext context,
    required File image,
    required String token,
  }) async {
    _status = AttendanceProcessStatus.processing;
    _message = null;
    notifyListeners();
    try {
      await _attendanceService.clockOut(image, token);
      _status = AttendanceProcessStatus.success;
      _message = 'Absensi Pulang berhasil direkam!';
      await checkTodayAttendanceStatus(context: context, token: token);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _status = AttendanceProcessStatus.error;
        _message = errorString;
      }
    } 
      notifyListeners();
  }
}