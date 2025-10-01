// lib/models/izin_model.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Enum untuk jenis izin, sekarang berada di dalam file model
enum LeaveType {
  sakit,
  kepentinganKeluarga,
}

// Helper extension untuk mengubah String menjadi Enum dan sebaliknya
extension LeaveTypeExtension on LeaveType {
  String get name {
    switch (this) {
      case LeaveType.sakit:
        return 'Sakit';
      case LeaveType.kepentinganKeluarga:
        return 'Kepentingan Keluarga';
      default:
        return '';
    }
  }

  static LeaveType fromString(String type) {
    if (type == 'Sakit') {
      return LeaveType.sakit;
    } else if (type == 'Kepentingan Keluarga') {
      return LeaveType.kepentinganKeluarga;
    }
    // Default fallback
    return LeaveType.sakit;
  }
}

class Izin {
  final int id;
  final int userId;
  final LeaveType jenisIzin; // Menggunakan Enum
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? alasan;
  final String? fullUrlBukti;

  const Izin({
    required this.id,
    required this.userId,
    required this.jenisIzin,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.alasan,
    this.fullUrlBukti,
  });

  factory Izin.fromJson(Map<String, dynamic> json) {
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    final String imageBaseUrl = dotenv.env['API_BASE_IMAGE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '';

    // 2. Buat fungsi helper untuk membangun URL yang lengkap dan aman.
    String? buildFullUrl(String? relativePath) {
      // Jika path null atau kosong, kembalikan null.
      if (relativePath == null || relativePath.isEmpty) return null;
      
      // Jika backend sudah memberikan URL lengkap, langsung gunakan.
      if (relativePath.startsWith('http')) {
        return relativePath;
      }
      
      // Pastikan base URL tidak memiliki garis miring di akhir.
      final String sanitizedBaseUrl = imageBaseUrl.endsWith('/')
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
          : imageBaseUrl;
      
      // Gabungkan base URL dengan path relatif dari backend.
      return '$sanitizedBaseUrl$relativePath';
    }
    
    try {
      return Izin(
        id: safeParseInt(json['id']),
        userId: safeParseInt(json['user_id']),
        // Mengubah String dari JSON menjadi Enum
        jenisIzin: LeaveTypeExtension.fromString(json['jenis_izin']),
        tanggalMulai: DateTime.parse(json['tanggal_mulai']),
        tanggalSelesai: DateTime.parse(json['tanggal_selesai']),
        alasan: json['alasan'],
        fullUrlBukti: buildFullUrl(json['full_url_bukti']),
      );
    } catch (e) {
      debugPrint('Error parsing Izin from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      // Mengubah Enum menjadi String untuk dikirim ke API
      'jenis_izin': jenisIzin.name,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'tanggal_selesai': tanggalSelesai.toIso8601String(),
      'alasan': alasan,
      'url_bukti': fullUrlBukti, // Backend akan mengabaikan ini saat create
    };
  }
}