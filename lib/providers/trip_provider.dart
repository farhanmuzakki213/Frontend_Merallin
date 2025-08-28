// lib/providers/trip_provider.dart

import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart';
import 'dart:io';
import 'dart:async';

class TripProvider with ChangeNotifier {
  final TripService _tripService = TripService();

  bool _isLoading = false;
  String? _errorMessage;
  
  // State sekarang hanya disimpan di memori, bukan Hive
  List<Trip> _allTrips = []; 
  List<Trip> get myTrips => _allTrips;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Kalkulasi performa sekarang berdasarkan state di memori
  int get totalTrips {
      final now = DateTime.now();
      return _allTrips.where((trip) =>
          trip.statusTrip == 'selesai' &&
          trip.updatedAt != null &&
          trip.updatedAt!.month == now.month &&
          trip.updatedAt!.year == now.year
      ).length;
  }
  
  int get companyTrips {
      final now = DateTime.now();
      return _allTrips.where((trip) =>
          trip.statusTrip == 'selesai' &&
          trip.jenisTrip == 'muatan perusahan' &&
          trip.updatedAt != null &&
          trip.updatedAt!.month == now.month &&
          trip.updatedAt!.year == now.year
      ).length;
  }
  
  int get driverTrips {
      final now = DateTime.now();
      return _allTrips.where((trip) =>
          trip.statusTrip == 'selesai' &&
          trip.jenisTrip == 'muatan driver' &&
          trip.updatedAt != null &&
          trip.updatedAt!.month == now.month &&
          trip.updatedAt!.year == now.year
      ).length;
  }

  // Fungsi fetch diganti menjadi lebih sederhana
  Future<void> fetchMyTrips(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Langsung panggil service, tidak ada lagi interaksi dengan cache
      _allTrips = await _tripService.getTrips(token);
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.toString();
      _allTrips = []; // Kosongkan list jika gagal
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan tidak terduga: ${e.toString()}';
      _allTrips = []; // Kosongkan list jika gagal
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fungsi fetchMonthlyTrips bisa digabung atau memanggil fetchMyTrips
  Future<void> fetchMonthlyTrips(String token) async {
    // Cukup panggil fetchMyTrips karena data performa (totalTrips, dll)
    // sudah otomatis dihitung dari _allTrips
    await fetchMyTrips(token);
  }

  // Fungsi lainnya tetap sama karena hanya meneruskan panggilan ke service
  Future<Trip?> getTripDetails(String token, int tripId) async {
    try {
      return await _tripService.getTripDetails(token, tripId);
    } catch (e) {
      // Anda bisa menangani error di sini jika perlu
      rethrow;
    }
  }
  
  // ... (Semua fungsi lain seperti updateStartTrip, updateAfterLoading, dll. TIDAK PERLU DIUBAH)
  // ... karena mereka sudah benar, yaitu hanya meneruskan panggilan ke TripService.
  Future<Trip?> updateStartTrip({
    required String token,
    required int tripId,
    required String licensePlate,
    required String startKm,
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
      throw Exception('Terjadi kesalahan saat update start trip: ${e.toString()}');
    }
  }

  Future<Trip?> updateToLoadingPoint({required String token, required int tripId}) async {
    try {
      final trip = await _tripService.updateToLoadingPoint(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Terjadi kesalahan saat update ke lokasi muat: ${e.toString()}');
    }
  }

  Future<Trip?> finishLoading({required String token, required int tripId}) async {
    try {
      final trip = await _tripService.finishLoading(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Terjadi kesalahan saat menyelesaikan muat: ${e.toString()}');
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
      throw Exception('Terjadi kesalahan saat update setelah muat: ${e.toString()}');
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
      throw Exception('Terjadi kesalahan saat upload dokumen tambahan: ${e.toString()}');
    }
  }

  Future<Trip?> updateToUnloadingPoint({required String token, required int tripId}) async {
    try {
      final trip = await _tripService.updateToUnloadingPoint(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Terjadi kesalahan saat update ke lokasi muat: ${e.toString()}');
    }
  }

  Future<Trip?> finishUnloading({required String token, required int tripId}) async {
    try {
      final trip = await _tripService.finishUnloading(token: token, tripId: tripId);
      return trip;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Terjadi kesalahan saat menyelesaikan bongkar: ${e.toString()}');
    }
  }

  Future<Trip?> updateFinishTrip({
    required String token,
    required int tripId,
    required String endKm,
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
      throw Exception('Terjadi kesalahan saat update finish trip: ${e.toString()}');
    }
  }
}