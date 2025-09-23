import 'package:flutter/material.dart';
import 'package:frontend_merallin/waiting_verification_screen.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../models/vehicle_model.dart';
import '../services/vehicle_service.dart';
import 'dart:io';
import 'dart:async';
import 'auth_provider.dart';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();
  final VehicleService _vehicleService = VehicleService();

  bool _isLoading = false;
  String? _errorMessage;

  List<Trip> _allTrips = [];
  List<Vehicle> _vehicles = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Vehicle> get vehicles => _vehicles;

  List<Trip> get allTrips => _allTrips;

  List<Trip> get activeTrips => _allTrips
      .where((trip) =>
          trip.derivedStatus != TripDerivedStatus.selesai &&
          trip.derivedStatus != TripDerivedStatus.tersedia)
      .toList();

  List<Trip> get availableTrips => _allTrips
      .where((trip) => trip.derivedStatus == TripDerivedStatus.tersedia)
      .toList();

  int get totalTrips {
    final now = DateTime.now();
    return _allTrips
        .where((trip) =>
            trip.statusTrip == 'selesai' &&
            trip.updatedAt != null &&
            trip.updatedAt!.month == now.month &&
            trip.updatedAt!.year == now.year)
        .length;
  }

  int get companyTrips {
    final now = DateTime.now();
    return _allTrips
        .where((trip) =>
            trip.statusTrip == 'selesai' &&
            trip.jenisTrip == 'muatan perusahan' &&
            trip.updatedAt != null &&
            trip.updatedAt!.month == now.month &&
            trip.updatedAt!.year == now.year)
        .length;
  }

  int get driverTrips {
    final now = DateTime.now();
    return _allTrips
        .where((trip) =>
            trip.statusTrip == 'selesai' &&
            trip.jenisTrip == 'muatan driver' &&
            trip.updatedAt != null &&
            trip.updatedAt!.month == now.month &&
            trip.updatedAt!.year == now.year)
        .length;
  }

  VerificationResult? _lastVerificationResult;

  void setAndProcessVerificationResult(VerificationResult result) {
    _lastVerificationResult = result;
    // Update data trip
    final index = _allTrips.indexWhere((t) => t.id == result.updatedTrip.id);
    if (index != -1) {
      _allTrips[index] = result.updatedTrip;
    }
    notifyListeners();
  }

  void clearLastVerificationResult() {
    _lastVerificationResult = null;
  }

  Future<void> fetchAvailableVehicles({required BuildContext context, required String token}) async {
    try {
      debugPrint('[TripProvider] Memulai fetchVehicles...');
      _vehicles = await _vehicleService.getAvailableVehicles(token);
      debugPrint('[TripProvider] Berhasil. Ditemukan ${_vehicles.length} kendaraan.');
      notifyListeners();
    } catch (e) {
      final errorString = e.toString();
      debugPrint('[TripProvider] Gagal memuat kendaraan: $errorString');
      if (errorString.contains('Unauthenticated')) {
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        return;
      }
      _errorMessage = "Gagal memuat data kendaraan: $errorString";
      notifyListeners();
    }
  }

  // ===== PERUBAHAN 2: Tambahkan 'context' =====
  Future<void> fetchTrips({required BuildContext context, required String token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allTrips = await _tripService.getTrips(token);
      _errorMessage = null;
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('Unauthenticated')) {
        // 'context' sekarang sudah tersedia karena ada di parameter fungsi
        Provider.of<AuthProvider>(context, listen: false).handleInvalidSession();
        _allTrips = [];
      } else {
        _errorMessage = 'Terjadi kesalahan: $errorString';
        _allTrips = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Trip?> acceptTrip(String token, int tripId) async {
    try {
      final updatedTrip = await _tripService.acceptTrip(token, tripId);

      final index = _allTrips.indexWhere((trip) => trip.id == tripId);
      if (index != -1) {
        _allTrips[index] = updatedTrip;
      }
      
      notifyListeners();

      return updatedTrip;
    } catch (e) {
      _errorMessage = 'Gagal memulai tugas: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<Trip?> getTripDetails(String token, int tripId) async {
    try {
      return await _tripService.getTripDetails(token, tripId);
    } catch (e) {
      rethrow;
    }
  }

  Future<Trip?> updateStartTrip({
    required String token,
    required int tripId,
    required int vehicleId,
    required String startKm,
    File? startKmPhoto,
  }) async {
    try {
      return await _tripService.updateStartTrip(
        token: token,
        tripId: tripId,
        vehicleId: vehicleId,
        startKm: startKm,
        startKmPhoto: startKmPhoto,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update start trip: ${e.toString()}');
    }
  }

  Future<Trip?> updateToLoadingPoint(
      {required String token, required int tripId}) async {
    try {
      final trip =
          await _tripService.updateToLoadingPoint(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update ke lokasi muat: ${e.toString()}');
    }
  }

  Future<Trip?> submitKedatanganMuat({
    required String token,
    required int tripId,
    File? kmMuatPhoto,
    File? kedatanganMuatPhoto,
    File? deliveryOrderPhoto,
  }) async {
    try {
      return await _tripService.updateKedatanganMuat(
        token: token,
        tripId: tripId,
        kmMuatPhoto: kmMuatPhoto,
        kedatanganMuatPhoto: kedatanganMuatPhoto,
        deliveryOrderPhoto: deliveryOrderPhoto,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update kedatangan muat: ${e.toString()}');
    }
  }

  Future<Trip?> submitProsesMuat({
    required String token,
    required int tripId,
    required Map<String, List<File>> photosByWarehouse,
  }) async {
    try {
      return await _tripService.updateProsesMuat(
        token: token,
        tripId: tripId,
        photosByWarehouse: photosByWarehouse, // Kirim data map
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat upload proses muat: ${e.toString()}');
    }
  }

  Future<Trip?> submitSelesaiMuat({
    required String token,
    required int tripId,
    List<File>? deliveryLetters,
    File? segelPhoto,
    File? timbanganPhoto,
  }) async {
    try {
      return await _tripService.uploadSelesaiMuat(
        token: token,
        tripId: tripId,
        deliveryLetters: deliveryLetters,
        segelPhoto: segelPhoto,
        timbanganPhoto: timbanganPhoto,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat upload dokumen selesai muat: ${e.toString()}');
    }
  }

  Future<Trip?> updateToUnloadingPoint(
      {required String token, required int tripId}) async {
    try {
      final trip = await _tripService.updateToUnloadingPoint(
          token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update ke lokasi bongkar: ${e.toString()}');
    }
  }

  Future<Trip?> submitKedatanganBongkar({
    required String token,
    required int tripId,
    String? endKm,
    File? endKmPhoto,
    File? kedatanganBongkarPhoto,
  }) async {
    try {
      return await _tripService.updateKedatanganBongkar(
        token: token,
        tripId: tripId,
        endKm: endKm,
        endKmPhoto: endKmPhoto,
        kedatanganBongkarPhoto: kedatanganBongkarPhoto,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update kedatangan bongkar: ${e.toString()}');
    }
  }

  Future<Trip?> submitProsesBongkar({
    required String token,
    required int tripId,
    // Sesuaikan tipe data parameter
    required Map<String, List<File>> photosByWarehouse,
  }) async {
    try {
      return await _tripService.updateProsesBongkar(
        token: token,
        tripId: tripId,
        photosByWarehouse: photosByWarehouse, // Kirim data map
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat upload proses bongkar: ${e.toString()}');
    }
  }

  Future<Trip?> submitSelesaiBongkar({
    required String token,
    required int tripId,
    List<File>? deliveryLetters,
  }) async {
    try {
      return await _tripService.updateSelesaiBongkar(
        token: token,
        tripId: tripId,
        deliveryLetters: deliveryLetters,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat menyelesaikan trip: ${e.toString()}');
    }
  }
}
