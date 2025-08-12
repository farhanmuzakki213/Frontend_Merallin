import 'package:flutter_dotenv/flutter_dotenv.dart';

class AttendanceHistory {
  final int id;
  final String namaUser;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String tipeAbsensi;
  final String statusAbsensi;
  final DateTime createdAt;

  AttendanceHistory({
    required this.id,
    required this.namaUser,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.tipeAbsensi,
    required this.statusAbsensi,
    required this.createdAt,
  });

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    double _safeParseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final String baseUrl = dotenv.env['API_BASE_URL']?.replaceAll('/api', '') ?? '';
    final String fullPhotoUrl = baseUrl + (json['photoUrl'] ?? '');

    return AttendanceHistory(
      id: json['id'],
      namaUser: json['namaUser'],
      photoUrl: fullPhotoUrl,
      latitude: _safeParseDouble(json['latitude']),
      longitude: _safeParseDouble(json['longitude']),
      tipeAbsensi: json['tipeAbsensi'],
      statusAbsensi: json['statusAbsensi'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}