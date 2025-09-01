// lib/providers/bbm_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bbm_model.dart';
import '../services/bbm_service.dart';
import '../services/trip_service.dart'; // Untuk ApiException

class BbmProvider with ChangeNotifier {
  final BbmService _bbmService = BbmService();
  
  List<BbmKendaraan> _bbmRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BbmKendaraan> get bbmRequests => _bbmRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBbmRequests(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _bbmRequests = await _bbmService.getBbmRequests(token);
    } on ApiException catch(e) {
      _errorMessage = e.toString();
    } catch(e) {
      _errorMessage = "Terjadi kesalahan tidak terduga.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BbmKendaraan?> createBbmRequest(String token, int vehicleId) async {
    try {
      final newRequest = await _bbmService.createBbmRequest(token, vehicleId);
      _bbmRequests.insert(0, newRequest);
      notifyListeners();
      return newRequest;
    } on ApiException catch(e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
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

  Future<BbmKendaraan> uploadEndKmAndNota(String token, int bbmId, File? kmPhoto, File? notaPhoto) async {
    return await _bbmService.uploadEndKmAndNota(token, bbmId, kmPhoto, notaPhoto);
  }
}