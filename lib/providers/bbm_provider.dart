// lib/providers/bbm_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/bbm_waiting_verification.dart';
import 'package:provider/provider.dart';
import '../models/bbm_model.dart';
import '../models/vehicle_model.dart';
import '../services/bbm_service.dart';
import '../services/vehicle_service.dart';
import 'auth_provider.dart';


class BbmProvider with ChangeNotifier {
  final BbmService _bbmService = BbmService();
  final VehicleService _vehicleService = VehicleService();

  List<BbmKendaraan> _bbmRequests = [];
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  List<BbmKendaraan> get bbmRequests => _bbmRequests;
  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  BbmVerificationResult? _lastVerificationResult;

  void setAndProcessVerificationResult(BbmVerificationResult result) {
    _lastVerificationResult = result;
    final index = _bbmRequests.indexWhere((b) => b.id == result.updatedBbm.id);
    if (index != -1) {
      _bbmRequests[index] = result.updatedBbm;
    }
    notifyListeners();
  }

  void clearLastVerificationResult() {
    _lastVerificationResult = null;
  }

  Future<void> fetchBbmRequests({
    required BuildContext context,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final bbmFuture = _bbmService.getBbmRequests(token);
      final vehicleFuture = _vehicleService.getAvailableVehicles(token);

      final results = await Future.wait([bbmFuture, vehicleFuture]);
      _bbmRequests = results[0] as List<BbmKendaraan>;
      _vehicles = results[1] as List<Vehicle>;
    } catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        return;
      }
      _errorMessage = "Terjadi kesalahan: $errorString";
      // ===== AKHIR PERBAIKAN =====
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BbmKendaraan?> createBbmRequest({
    required BuildContext context,
    required String token,
    required int vehicleId,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newRequest = await _bbmService.createBbmRequest(token, vehicleId);
      _bbmRequests.insert(0, newRequest);
      return newRequest;
    } on ApiException catch (e) {
      // ===== MULAI PERBAIKAN =====
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        return null;
      }
      _errorMessage = errorString;
      rethrow;
      // ===== AKHIR PERBAIKAN =====
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // Fungsi-fungsi di bawah ini yang menggunakan 'rethrow' tidak perlu diubah.
  // Penanganan error akan dilakukan di UI saat memanggilnya.
  Future<BbmKendaraan?> getBbmDetails(String token, int bbmId) async {
    try {
      return await _bbmService.getBbmDetails(token, bbmId);
    } catch (e) {
      rethrow;
    }
  }

  Future<BbmKendaraan> uploadStartKm(String token, int bbmId, File photo) async {
    return await _bbmService.uploadStartKm(token, bbmId, photo);
  }

  Future<BbmKendaraan> finishFilling(String token, int bbmId) async {
    return await _bbmService.finishFilling(token, bbmId);
  }

  Future<BbmKendaraan> uploadEndKmAndNota(
      String token, int bbmId, File? kmPhoto, File? notaPhoto) async {
    return await _bbmService.uploadEndKmAndNota(
        token, bbmId, kmPhoto, notaPhoto);
  }
}