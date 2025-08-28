import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import 'dart:io';
import 'dart:async';
// HAPUS IMPORT AUTH_PROVIDER DARI SINI JIKA ADA

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();

  bool _isLoading = false;
  String? _errorMessage;

  List<Trip> _allTrips = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Trip> get activeTrips => _allTrips
      .where((trip) =>
          trip.derivedStatus != TripDerivedStatus.selesai &&
          trip.derivedStatus != TripDerivedStatus.tersedia)
      .toList();

  List<Trip> get availableTrips => _allTrips
      .where((trip) => trip.derivedStatus == TripDerivedStatus.tersedia)
      .toList();

  // ... (Sisa kode di file ini tidak perlu diubah, biarkan seperti versi terakhir yang saya berikan)
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
    String? licensePlate,
    String? startKm,
    File? startKmPhoto,
  }) async {
    try {
      final trip = await _tripService.updateStartTrip(
        token: token,
        tripId: tripId,
        licensePlate: licensePlate,
        startKm: startKm,
        startKmPhoto: startKmPhoto,
      );
      return trip;
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

  Future<Trip?> finishLoading(
      {required String token, required int tripId}) async {
    try {
      final trip =
          await _tripService.finishLoading(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat menyelesaikan muat: ${e.toString()}');
    }
  }

  Future<Trip?> updateAfterLoading({
    required String token,
    required int tripId,
    List<File>? deliveryLetters,
    File? muatPhoto,
  }) async {
    try {
      final trip = await _tripService.updateAfterLoading(
        token: token,
        tripId: tripId,
        deliveryLetters: deliveryLetters,
        muatPhoto: muatPhoto,
      );
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update setelah muat: ${e.toString()}');
    }
  }

  Future<Trip?> uploadTripDocuments({
    required String token,
    required int tripId,
    File? deliveryOrder,
    File? segelPhoto,
    File? timbanganPhoto,
  }) async {
    try {
      final trip = await _tripService.uploadTripDocuments(
        token: token,
        tripId: tripId,
        deliveryOrder: deliveryOrder,
        segelPhoto: segelPhoto,
        timbanganPhoto: timbanganPhoto,
      );
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat upload dokumen tambahan: ${e.toString()}');
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
          'Terjadi kesalahan saat update ke lokasi muat: ${e.toString()}');
    }
  }

  Future<Trip?> finishUnloading(
      {required String token, required int tripId}) async {
    try {
      final trip =
          await _tripService.finishUnloading(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat menyelesaikan bongkar: ${e.toString()}');
    }
  }

  Future<Trip?> updateFinishTrip({
    required String token,
    required int tripId,
    String? endKm,
    File? endKmPhoto,
    List<File>? bongkarPhoto,
    List<File>? deliveryLetters,
  }) async {
    try {
      final trip = await _tripService.updateFinishTrip(
        token: token,
        tripId: tripId,
        endKm: endKm,
        endKmPhoto: endKmPhoto,
        bongkarPhoto: bongkarPhoto,
        deliveryLetters: deliveryLetters,
      );
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception(
          'Terjadi kesalahan saat update finish trip: ${e.toString()}');
    }
  }
}
