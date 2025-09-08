import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../models/vehicle_model.dart';
import '../services/vehicle_service.dart';
import 'dart:io';
import 'dart:async';
// HAPUS IMPORT AUTH_PROVIDER DARI SINI JIKA ADA

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

  Future<void> fetchVehicles(String token) async {
    try {
      debugPrint(
          '[TripProvider] Memulai fetchVehicles...'); // Lacak pemanggilan
      _vehicles = await _vehicleService.getVehicles(token);
      debugPrint(
          '[TripProvider] Berhasil. Ditemukan ${_vehicles.length} kendaraan.'); // Lacak jumlah data
      notifyListeners();
    } catch (e) {
      debugPrint(
          '[TripProvider] Gagal memuat kendaraan: ${e.toString()}'); // Lacak jika ada error
      _errorMessage = "Gagal memuat data kendaraan: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> fetchTrips(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allTrips = await _tripService.getTrips(token);
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.toString();
      _allTrips = [];
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan tidak terduga: ${e.toString()}';
      _allTrips = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptTrip(String token, int tripId) async {
    try {
      await _tripService.acceptTrip(token, tripId);
      await fetchTrips(token);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memulai tugas: ${e.toString()}';
      notifyListeners();
      return false;
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
    List<File>? muatPhotos,
  }) async {
    try {
      return await _tripService.updateProsesMuat(
        token: token,
        tripId: tripId,
        muatPhotos: muatPhotos,
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
    List<File>? bongkarPhotos,
  }) async {
    try {
      return await _tripService.updateProsesBongkar(
        token: token,
        tripId: tripId,
        bongkarPhotos: bongkarPhotos,
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
