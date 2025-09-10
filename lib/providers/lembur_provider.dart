// lib/providers/lembur_provider.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:frontend_merallin/services/lembur_service.dart';
import 'package:geolocator/geolocator.dart';

enum DataStatus { initial, loading, success, error }

class LemburProvider with ChangeNotifier {
  final LemburService _lemburService = LemburService();

  // State untuk riwayat lembur
  DataStatus _historyStatus = DataStatus.initial;
  DataStatus get historyStatus => _historyStatus;

  List<Lembur> _overtimeHistory = [];
  List<Lembur> get overtimeHistory => _overtimeHistory;

  String? _historyMessage;
  String? get historyMessage => _historyMessage;

  // State untuk pengajuan lembur
  DataStatus _submissionStatus = DataStatus.initial;
  DataStatus get submissionStatus => _submissionStatus;

  String? _submissionMessage;
  String? get submissionMessage => _submissionMessage;

  DataStatus _detailStatus = DataStatus.initial;
  DataStatus get detailStatus => _detailStatus;

  Lembur? _selectedLembur;
  Lembur? get selectedLembur => _selectedLembur;

  String? _detailMessage;
  String? get detailMessage => _detailMessage;

  // PENAMBAHAN: State khusus untuk aksi clock-in/out
  bool _isActionLoading = false;
  bool get isActionLoading => _isActionLoading;

  String? _actionMessage;
  String? get actionMessage => _actionMessage;

  void _updateLemburState(Lembur updatedLembur) {
    _selectedLembur = updatedLembur;
    
    // Cari index dari item yang lama di dalam daftar riwayat
    final index = _overtimeHistory.indexWhere((item) => item.uuid == updatedLembur.uuid);
    
    // Jika ditemukan, ganti dengan data yang baru
    if (index != -1) {
      _overtimeHistory[index] = updatedLembur;
    }
  }

  // Fungsi untuk mengambil riwayat lembur
  Future<void> fetchOvertimeHistory(String token) async {
    _historyStatus = DataStatus.loading;
    notifyListeners();

    try {
      _overtimeHistory = await _lemburService.getOvertimeHistory(token);
      _historyStatus = DataStatus.success;
    } catch (e) {
      _historyMessage = e.toString();
      _historyStatus = DataStatus.error;
    }
    notifyListeners();
  }

  // Fungsi untuk mengirim pengajuan lembur baru
  Future<void> submitOvertime({
    required String token,
    required JenisHariLembur jenisHari,
    required DepartmentLembur department,
    required DateTime tanggalLembur,
    required String keteranganLembur,
    required String mulaiJamLembur,
    required String selesaiJamLembur,
  }) async {
    _submissionStatus = DataStatus.loading;
    _submissionMessage = null; // Reset pesan error sebelumnya
    notifyListeners();

    try {
      await _lemburService.submitOvertimeRequest(
        token: token,
        jenisHari: jenisHari,
        department: department,
        tanggalLembur: tanggalLembur,
        keteranganLembur: keteranganLembur,
        mulaiJamLembur: mulaiJamLembur,
        selesaiJamLembur: selesaiJamLembur,
      );
      _submissionStatus = DataStatus.success;
      _submissionMessage = 'Pengajuan lembur berhasil dikirim.';
      // Setelah berhasil, langsung muat ulang data riwayat
      await fetchOvertimeHistory(token);
    } catch (e) {
      _submissionMessage = e.toString();
      _submissionStatus = DataStatus.error;
    }
    notifyListeners();
  }

  Future<void> fetchOvertimeDetail(String token, String uuid) async {
    _detailStatus = DataStatus.loading;
    notifyListeners();
    try {
      // 1. Ambil data LENGKAP yang sudah ada dari riwayat/daftar
      final fullDataFromList = _overtimeHistory.firstWhere((item) => item.uuid == uuid);

      // 2. Ambil data UPDATE (parsial) dari API detail
      final partialDataFromApi = await _lemburService.getOvertimeDetail(token, uuid);

      // 3. Gabungkan keduanya menggunakan copyWith
      //    Timpa data lama dengan data baru yang tidak null
      _selectedLembur = fullDataFromList.copyWith(
        statusLembur: partialDataFromApi.statusLembur,
        alasanPenolakan: partialDataFromApi.alasanPenolakan,
        fileFinalUrl: partialDataFromApi.fileFinalUrl,
        jamMulaiAktual: partialDataFromApi.jamMulaiAktual,
        jamSelesaiAktual: partialDataFromApi.jamSelesaiAktual,
      );

      _detailStatus = DataStatus.success;
    } catch (e) {
      _detailMessage = e.toString();
      _detailStatus = DataStatus.error;
    }
    notifyListeners();
  }

  Future<bool> performClockIn({
    required String token,
    required String uuid,
    required File image,
    required Position position,
  }) async {
    _isActionLoading = true;
    _actionMessage = null;
    notifyListeners();

    try {
      // 1. Ambil data LENGKAP yang ada saat ini
      final existingData = _selectedLembur ?? _overtimeHistory.firstWhere((item) => item.uuid == uuid);

      // 2. Panggil API, yang akan mengembalikan data PARSIAL (tidak lengkap)
      final partialUpdate = await _lemburService.clockIn(
        token: token,
        uuid: uuid,
        image: image,
        position: position,
      );
      // 3. Gabungkan keduanya: timpa data lama dengan data baru yang tidak null
      final mergedData = existingData.copyWith(
        jamMulaiAktual: partialUpdate.jamMulaiAktual,
        fotoMulaiPath: partialUpdate.fotoMulaiPath,
      );

      // 4. Perbarui state dengan data yang sudah digabung
      _updateLemburState(mergedData);
      
      _actionMessage = 'Clock-in berhasil direkam.';
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }


  Future<bool> performClockOut({
    required String token,
    required String uuid,
    required File image,
    required Position position,
  }) async {
    _isActionLoading = true;
    _actionMessage = null;
    notifyListeners();

    try {
      // 1. Ambil data LENGKAP yang ada saat ini
      final existingData = _selectedLembur ?? _overtimeHistory.firstWhere((item) => item.uuid == uuid);
      
      // 2. Panggil API, yang akan mengembalikan data PARSIAL (tidak lengkap)
      final partialUpdate = await _lemburService.clockOut(
        token: token,
        uuid: uuid,
        image: image,
        position: position,
      );
      
      // 3. Gabungkan keduanya
      final mergedData = existingData.copyWith(
        jamSelesaiAktual: partialUpdate.jamSelesaiAktual,
        fotoSelesaiPath: partialUpdate.fotoSelesaiPath,
      );
      
      // 4. Perbarui state dengan data yang sudah digabung
      _updateLemburState(mergedData);

      _actionMessage = 'Clock-out berhasil direkam.';
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionMessage = e.toString();
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }
}