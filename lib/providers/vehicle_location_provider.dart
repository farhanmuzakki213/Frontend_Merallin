import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../models/vehicle_location_model.dart';
import '../models/vehicle_model.dart';
import '../services/trip_service.dart'; // For ApiException
import '../services/vehicle_location_service.dart';
import '../services/vehicle_service.dart';
import 'auth_provider.dart'; // Import AuthProvider

class VehicleLocationProvider with ChangeNotifier {
  final VehicleLocationService _locationService = VehicleLocationService();
  final VehicleService _vehicleService = VehicleService();

  List<VehicleLocation> _history = [];
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<VehicleLocation> get history => _history;
  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchHistory({
    required BuildContext context,
    required String token,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _history = await _locationService.getHistory(token);
      _errorMessage = null;
    } on ApiException catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _errorMessage = errorString;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchVehicles({
    required BuildContext context,
    required String token,
  }) async {
    try {
      _vehicles = await _vehicleService.getVehicles(token);
      notifyListeners();
    } on ApiException catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
      } else {
        _errorMessage = errorString;
        notifyListeners();
      }
    }
  }

  Future<VehicleLocation?> create({
    required BuildContext context,
    required String token,
    required int vehicleId,
    required String keterangan,
  }) async {
    try {
      final newLocation =
          await _locationService.create(token, vehicleId, keterangan);
      _history.insert(0, newLocation);
      notifyListeners();
      return newLocation;
    } on ApiException catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        return null;
      }
      _errorMessage = errorString;
      notifyListeners();
      return null;
    }
  }

  // ===== PERUBAHAN: FUNGSI 'create' YANG DUPLIKAT DIHAPUS DARI SINI =====

  Future<VehicleLocation?> getDetails(String token, int locationId) async {
    try {
      return await _locationService.getDetails(token, locationId);
    } catch (e) {
      rethrow;
    }
  }

  Future<VehicleLocation?> uploadStandbyAndStartKm({
    required String token,
    required int locationId,
    File? standbyPhoto,
    File? startKmPhoto,
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _locationService.uploadStandbyAndStartKm(
          token: token,
          locationId: locationId,
          standbyPhoto: standbyPhoto,
          startKmPhoto: startKmPhoto,
          latitude: latitude,
          longitude: longitude);
    } on ApiException {
      rethrow;
    }
  }

  Future<VehicleLocation?> arriveAtLocation({
    required String token,
    required int locationId,
  }) async {
    try {
      return await _locationService.arriveAtLocation(
          token: token, locationId: locationId);
    } on ApiException {
      rethrow;
    }
  }

  Future<VehicleLocation?> uploadEndKm({
    required String token,
    required int locationId,
    required File endKmPhoto,
    required double latitude,
    required double longitude,
  }) async {
    try {
      return await _locationService.uploadEndKm(
        token: token,
        locationId: locationId,
        endKmPhoto: endKmPhoto,
        latitude: latitude,
        longitude: longitude,
      );
    } on ApiException {
      rethrow;
    }
  }
}
