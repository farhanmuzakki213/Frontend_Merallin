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
    final DateTime parsedPeriod = tz.TZDateTime.parse(tz.local, json['period']);

    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    return PayslipSummary(
      id: safeParseInt(json['id']),
      fileUrl: json['file_url'],
      period: parsedPeriod,
    );
  }
}
