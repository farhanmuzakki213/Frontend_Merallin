// lib/providers/bbm_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bbm_model.dart';
import '../models/vehicle_model.dart';
import '../services/bbm_service.dart';
import '../services/vehicle_service.dart';

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

  Future<void> fetchBbmRequests(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Muat data BBM dan Kendaraan secara bersamaan
      final bbmFuture = _bbmService.getBbmRequests(token);
      final vehicleFuture = _vehicleService.getVehicles(token);

      final results = await Future.wait([bbmFuture, vehicleFuture]);
      _bbmRequests = results[0] as List<BbmKendaraan>;
      _vehicles = results[1] as List<Vehicle>;
    } on ApiException catch (e) {
      _errorMessage = e.toString();
    } catch (e) {
      _errorMessage = "Terjadi kesalahan tidak terduga: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BbmKendaraan?> createBbmRequest(String token, int vehicleId) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newRequest = await _bbmService.createBbmRequest(token, vehicleId);
      _bbmRequests.insert(0, newRequest);
      return newRequest;
    } on ApiException catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

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