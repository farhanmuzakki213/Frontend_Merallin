// lib/models/trip_model.dart
import 'user_model.dart';

// Kelas baru untuk menampung URL surat jalan
class DeliveryLetter {
  final List<String> initialLetters;
  final List<String> finalLetters;

  DeliveryLetter({
    required this.initialLetters,
    required this.finalLetters,
  });

  factory DeliveryLetter.fromJson(Map<String, dynamic> json) {
    final initial = json['initial_letters'];
    final finalL = json['final_letters'];

    return DeliveryLetter(
      initialLetters: initial is List ? List<String>.from(initial.map((e) => e.toString())) : [],
      finalLetters: finalL is List ? List<String>.from(finalL.map((e) => e.toString())) : [],
    );
  }
}

class Trip {
  final int id;
  final int? userId;
  final String projectName;
  final String origin;
  final String destination;
  final String? licensePlate;
  final int? startKm;
  final String? startKmPhotoPath;
  final String? muatPhotoPath;
  final String? bongkarPhotoPath;
  final int? endKm;
  final String? endKmPhotoPath;
  final DeliveryLetter? deliveryLetters;
  final String statusTrip;
  final String? statusLokasi;
  final String? statusMuatan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user;

  final String? fullStartKmPhotoUrl;
  final String? fullMuatPhotoUrl;
  final String? fullBongkarPhotoUrl;
  final String? fullEndKmPhotoUrl;

  Trip({
    required this.id,
    this.userId,
    required this.projectName,
    required this.origin,
    required this.destination,
    this.licensePlate,
    this.startKm,
    this.startKmPhotoPath,
    this.muatPhotoPath,
    this.bongkarPhotoPath,
    this.endKm,
    this.endKmPhotoPath,
    this.deliveryLetters,
    required this.statusTrip,
    this.statusLokasi,
    this.statusMuatan,
    this.fullStartKmPhotoUrl,
    this.fullMuatPhotoUrl,
    this.fullBongkarPhotoUrl,
    this.fullEndKmPhotoUrl,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  // Helper untuk parsing integer yang aman dari JSON
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      // ================== PERUBAHAN DI SINI ==================
      id: _parseToInt(json['id']) ?? 0, // ID seharusnya tidak pernah null
      userId: _parseToInt(json['user_id']),
      projectName: json['project_name'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      licensePlate: json['license_plate'],
      startKm: _parseToInt(json['start_km']),
      startKmPhotoPath: json['start_km_photo_path'],
      muatPhotoPath: json['muat_photo_path'],
      bongkarPhotoPath: json['bongkar_photo_path'],
      endKm: _parseToInt(json['end_km']),
      endKmPhotoPath: json['end_km_photo_path'],
      // ================== AKHIR PERUBAHAN ==================
      
      deliveryLetters: json['full_delivery_letter_urls'] != null && json['full_delivery_letter_urls'] is Map
          ? DeliveryLetter.fromJson(json['full_delivery_letter_urls'])
          : null,
      statusTrip: json['status_trip'] ?? '',
      statusLokasi: json['status_lokasi'],
      statusMuatan: json['status_muatan'],

      fullStartKmPhotoUrl: json['full_start_km_photo_url'],
      fullMuatPhotoUrl: json['full_muat_photo_url'],
      fullBongkarPhotoUrl: json['full_bongkar_photo_url'],
      fullEndKmPhotoUrl: json['full_end_km_photo_url'],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
