// lib/models/payslip_model.dart

import 'package:timezone/timezone.dart' as tz; // <-- TAMBAHKAN IMPOR INI

class PayslipSummary {
  final int id;
  final String fileUrl;
  final DateTime period;

  PayslipSummary({
    required this.id,
    required this.fileUrl,
    required this.period,
  });

  factory PayslipSummary.fromJson(Map<String, dynamic> json) {
    // ===== BAGIAN INI DIPERBAIKI =====
    // Kita gunakan TZDateTime.parse untuk memastikan tanggal dibaca
    // sesuai dengan zona waktu lokal (WIB) yang sudah diatur di main.dart.
    final DateTime parsedPeriod =
        tz.TZDateTime.parse(tz.local, json['period']);
    // ================================

    return PayslipSummary(
      id: json['id'],
      fileUrl: json['file_url'],
      period: parsedPeriod, // Gunakan hasil parse yang sudah benar
    );
  }
}