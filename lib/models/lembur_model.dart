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
      default:
        return StatusPersetujuan.menungguPersetujuan; // Fallback default
    }
  }
}

class Lembur {
  final String id;
  final String userId;
  final JenisHariLembur jenisHari;
  final DepartmentLembur department;
  final DateTime tanggalLembur;
  final String keteranganLembur;
  final String mulaiJamLembur; // Format "HH:mm:ss"
  final String selesaiJamLembur; // Format "HH:mm:ss"
  final StatusPersetujuan statusLembur;
  final StatusPersetujuan persetujuanDireksi;
  final StatusPersetujuan persetujuanManajer;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lembur({
    required this.id,
    required this.userId,
    required this.jenisHari,
    required this.department,
    required this.tanggalLembur,
    required this.keteranganLembur,
    required this.mulaiJamLembur,
    required this.selesaiJamLembur,
    required this.statusLembur,
    required this.persetujuanDireksi,
    required this.persetujuanManajer,
    this.createdAt,
    this.updatedAt,
  });

  factory Lembur.fromJson(Map<String, dynamic> json) {
    try {
      return Lembur(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        jenisHari:
            JenisHariLemburExtension.fromString(json['jenis_hari'] ?? 'Kerja'),
        department:
            DepartmentLemburExtension.fromString(json['department'] ?? 'Admin'),
        tanggalLembur: DateTime.parse(json['tanggal_lembur']),
        keteranganLembur: json['keterangan_lembur'] ?? '',
        mulaiJamLembur: json['mulai_jam_lembur'] ?? '00:00:00',
        selesaiJamLembur: json['selesai_jam_lembur'] ?? '00:00:00',
        statusLembur: StatusPersetujuanExtension.fromString(
            json['status_lembur'] ?? 'Menunggu Persetujuan'),
        persetujuanDireksi: StatusPersetujuanExtension.fromString(
            json['persetujuan_direksi'] ?? 'Menunggu Persetujuan'),
        persetujuanManajer: StatusPersetujuanExtension.fromString(
            json['persetujuan_manajer'] ?? 'Menunggu Persetujuan'),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing Lembur from JSON: $e');
      rethrow;
    }
  }
}