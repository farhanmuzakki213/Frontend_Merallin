// lib/models/lembur_model.dart

import 'package:flutter/foundation.dart';

// Enum untuk jenis hari lembur, sesuai dengan skema database
enum JenisHariLembur {
  kerja,
  libur,
  liburNasional,
}

// Helper extension untuk mengubah String menjadi Enum JenisHariLembur dan sebaliknya
extension JenisHariLemburExtension on JenisHariLembur {
  String get name {
    switch (this) {
      case JenisHariLembur.kerja:
        return 'Kerja';
      case JenisHariLembur.libur:
        return 'Libur';
      case JenisHariLembur.liburNasional:
        return 'Libur Nasional';
    }
  }

  static JenisHariLembur fromString(String type) {
    switch (type) {
      case 'Kerja':
        return JenisHariLembur.kerja;
      case 'Libur':
        return JenisHariLembur.libur;
      case 'Libur Nasional':
        return JenisHariLembur.liburNasional;
      default:
        return JenisHariLembur.kerja;
    }
  }
}

// Enum untuk departemen, sesuai dengan skema database
enum DepartmentLembur {
  finance,
  managerOperasional,
  hrd,
  it,
  admin,
}

// Helper extension untuk mengubah String menjadi Enum DepartmentLembur dan sebaliknya
extension DepartmentLemburExtension on DepartmentLembur {
  String get name {
    switch (this) {
      case DepartmentLembur.finance:
        return 'Finance';
      case DepartmentLembur.managerOperasional:
        return 'Manager Operasional';
      case DepartmentLembur.hrd:
        return 'HRD';
      case DepartmentLembur.it:
        return 'IT';
      case DepartmentLembur.admin:
        return 'Admin';
    }
  }

  static DepartmentLembur fromString(String type) {
    switch (type) {
      case 'Finance':
        return DepartmentLembur.finance;
      case 'Manager Operasional':
        return DepartmentLembur.managerOperasional;
      case 'HRD':
        return DepartmentLembur.hrd;
      case 'IT':
        return DepartmentLembur.it;
      case 'Admin':
        return DepartmentLembur.admin;
      default:
        return DepartmentLembur.finance; // Fallback default
    }
  }
}

// Enum untuk status persetujuan, dapat digunakan untuk ketiga kolom status
enum StatusPersetujuan {
  ditolak,
  diterima,
  menungguPersetujuan,
  menungguKonfirmasiAdmin,
}

// Helper extension untuk mengubah String menjadi Enum StatusPersetujuan dan sebaliknya
extension StatusPersetujuanExtension on StatusPersetujuan {
  String get name {
    switch (this) {
      case StatusPersetujuan.ditolak:
        return 'Ditolak';
      case StatusPersetujuan.diterima:
        return 'Diterima';
      case StatusPersetujuan.menungguPersetujuan:
        return 'Menunggu Persetujuan';
      case StatusPersetujuan.menungguKonfirmasiAdmin:
        return 'Menunggu Konformasi Admin';
      default:
        return 'Menunggu Persetujuan';
    }
  }

  static StatusPersetujuan fromString(String status) {
    switch (status) {
      case 'Ditolak':
        return StatusPersetujuan.ditolak;
      case 'Diterima':
        return StatusPersetujuan.diterima;
      case 'Menunggu Persetujuan':
        return StatusPersetujuan.menungguPersetujuan;
      case 'Menunggu Konfirmasi Admin':
        return StatusPersetujuan.menungguKonfirmasiAdmin;
      default:
        return StatusPersetujuan.menungguPersetujuan; // Fallback default
    }
  }
}

class Lembur {
  final int id;
  final String? uuid;
  final int userId;
  final JenisHariLembur jenisHari;
  final DepartmentLembur department;
  final DateTime tanggalLembur;
  final String keteranganLembur;
  final String mulaiJamLembur; // Format "HH:mm:ss"
  final String selesaiJamLembur; // Format "HH:mm:ss"
  final StatusPersetujuan statusLembur;
  final StatusPersetujuan persetujuanDireksi;
  // final StatusPersetujuan persetujuanManajer;
  final String? alasanPenolakan;
  final String? fileFinalUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final DateTime? jamMulaiAktual;
  final DateTime? jamSelesaiAktual;
  final String? fotoMulaiPath;
  final String? fotoSelesaiPath;

  const Lembur({
    required this.id,
    this.uuid,
    required this.userId,
    required this.jenisHari,
    required this.department,
    required this.tanggalLembur,
    required this.keteranganLembur,
    required this.mulaiJamLembur,
    required this.selesaiJamLembur,
    required this.statusLembur,
    required this.persetujuanDireksi,
    // required this.persetujuanManajer,
    this.alasanPenolakan,
    this.fileFinalUrl,
    this.createdAt,
    this.updatedAt,
    this.jamMulaiAktual,
    this.jamSelesaiAktual,
    this.fotoMulaiPath,
    this.fotoSelesaiPath,
  });

  factory Lembur.fromJson(Map<String, dynamic> json) {
    try {
      // Helper untuk parsing tanggal yang WAJIB ADA (tidak boleh null)
      int safeParseInt(dynamic value) {
        if (value == null) return 0;
        return int.tryParse(value.toString()) ?? 0;
      }

      DateTime _parseDate(String? dateString) {
        if (dateString == null)
          return DateTime.now(); // Fallback ke tanggal sekarang
        return DateTime.parse(dateString);
      }

      DateTime? _parseNullableDate(String? dateString) {
        return dateString != null ? DateTime.parse(dateString) : null;
      }

      return Lembur(
        id: safeParseInt(json['id']),
        uuid: json['uuid']?.toString(),
        userId: safeParseInt(json['user_id']),
        jenisHari:
            JenisHariLemburExtension.fromString(json['jenis_hari'] ?? 'Kerja'),
        department:
            DepartmentLemburExtension.fromString(json['department'] ?? 'Admin'),
        tanggalLembur: _parseDate(json['tanggal_lembur']),

        keteranganLembur: json['keterangan_lembur'] ?? '',
        mulaiJamLembur: json['mulai_jam_lembur'] ?? '00:00:00',
        selesaiJamLembur: json['selesai_jam_lembur'] ?? '00:00:00',

        statusLembur: StatusPersetujuanExtension.fromString(
            json['status_final'] ??
                json['status_lembur'] ??
                'Menunggu Persetujuan'),

        persetujuanDireksi: StatusPersetujuanExtension.fromString(
            json['persetujuan_direksi'] ?? 'Menunggu Persetujuan'),

        // persetujuanManajer: StatusPersetujuanExtension.fromString(
        //     json['persetujuan_manajer'] ?? 'Menunggu Persetujuan'),

        alasanPenolakan: json['alasan_penolakan'] ?? json['alasan'],
        fileFinalUrl: json['file_final_url'] ?? json['file_url'],

        createdAt:
            _parseNullableDate(json['created_at'] ?? json['diajukan_pada']),

        updatedAt: _parseNullableDate(json['updated_at']),

        jamMulaiAktual: _parseNullableDate(json['jam_mulai_aktual']),
        jamSelesaiAktual: _parseNullableDate(json['jam_selesai_aktual']),
        fotoMulaiPath: json['foto_mulai_path'],
        fotoSelesaiPath: json['foto_selesai_path'],
      );
    } catch (e) {
      debugPrint('Error parsing Lembur from JSON: $e');
      rethrow;
    }
  }

  Lembur copyWith({
    StatusPersetujuan? statusLembur,
    StatusPersetujuan? persetujuanDireksi,
    // StatusPersetujuan? persetujuanManajer,
    String? alasanPenolakan,
    String? fileFinalUrl,
    DateTime? jamMulaiAktual,
    DateTime? jamSelesaiAktual,
    String? fotoMulaiPath,
    String? fotoSelesaiPath,
  }) {
    return Lembur(
      id: id,
      uuid: uuid,
      userId: userId,
      jenisHari: jenisHari,
      department: department,
      tanggalLembur: tanggalLembur,
      keteranganLembur: keteranganLembur,
      mulaiJamLembur: mulaiJamLembur,
      selesaiJamLembur: selesaiJamLembur,
      createdAt: createdAt,
      updatedAt: updatedAt,
      // Gunakan nilai baru jika ada, jika tidak, pakai nilai lama (this)
      statusLembur: statusLembur ?? this.statusLembur,
      persetujuanDireksi: persetujuanDireksi ?? this.persetujuanDireksi,
      // persetujuanManajer: persetujuanManajer ?? this.persetujuanManajer,
      alasanPenolakan: alasanPenolakan ?? this.alasanPenolakan,
      fileFinalUrl: fileFinalUrl ?? this.fileFinalUrl,
      jamMulaiAktual: jamMulaiAktual ?? this.jamMulaiAktual,
      jamSelesaiAktual: jamSelesaiAktual ?? this.jamSelesaiAktual,
      fotoMulaiPath: fotoMulaiPath ?? this.fotoMulaiPath,
      fotoSelesaiPath: fotoSelesaiPath ?? this.fotoSelesaiPath,
    );
  }
}
