// lib/models/vehicle_location_model.dart

import 'user_model.dart';
import 'vehicle_model.dart';
import 'trip_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/timezone.dart' as tz;

/*
 * Model data lokasi kendaraan di luar perjalanan (Trip),
 * misalnya saat standby atau kembali ke pool.
 */
class VehicleLocation {
  final int id;
  final int userId;
  final int vehicleId;
  final int? tripId;
  final String? keterangan;

  final String? startLocation;
  final String? standbyPhotoPath;
  final PhotoVerificationStatus standbyPhotoStatus;
  final String? startKmPhotoPath;
  final PhotoVerificationStatus startKmPhotoStatus;
  final String? endKmPhotoPath;
  final PhotoVerificationStatus endKmPhotoStatus;
  final String? endLocation;

  final String statusVehicleLocation;
  final String? statusLokasi;

  final DateTime createdAt;
  final DateTime updatedAt;
  final User? user;
  final Vehicle? vehicle;

  final String? fullStandbyPhotoUrl;
  final String? fullStartKmPhotoUrl;
  final String? fullEndKmPhotoUrl;

  VehicleLocation({
    required this.id,
    required this.userId,
    required this.vehicleId,
    this.tripId,
    this.keterangan,
    this.startLocation,
    this.standbyPhotoPath,
    required this.standbyPhotoStatus,
    this.startKmPhotoPath,
    required this.startKmPhotoStatus,
    this.endKmPhotoPath,
    required this.endKmPhotoStatus,
    this.endLocation,
    required this.statusVehicleLocation,
    this.statusLokasi,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.vehicle,
    this.fullStandbyPhotoUrl,
    this.fullStartKmPhotoUrl,
    this.fullEndKmPhotoUrl,
  });


  // getter untuk memeriksa apakah proses laporan lokasi kendaraan sudah selesai dan disetujui.
  bool get isFullyCompleted {
    return endKmPhotoPath != null && endKmPhotoStatus.isApproved;
  }


  // Getter untuk menentukan status turunan (derived status) dari laporan lokasi kendaraan.
  TripDerivedStatus get derivedStatus {
    if ([standbyPhotoStatus, startKmPhotoStatus, endKmPhotoStatus]
        .any((s) => s.status?.toLowerCase() == 'rejected')) {
      return TripDerivedStatus.revisiGambar;
    }

    if (isFullyCompleted || statusVehicleLocation == 'selesai') {
      return TripDerivedStatus.selesai;
    }

    if (statusVehicleLocation == 'verifikasi gambar') {
      return TripDerivedStatus.verifikasiGambar;
    }
    
    return TripDerivedStatus.proses;
  }


  // Getter untuk mengumpulkan semua dokumen/foto yang telah diunggah.
  List<DocumentInfo> get allDocuments {
    return [
      if (standbyPhotoPath != null)
        DocumentInfo(
          'standby_photo', 
          'Foto Standby', 
          standbyPhotoStatus, 
          [fullStandbyPhotoUrl].whereType<String>().toList()
        ),
      if (startKmPhotoPath != null)
        DocumentInfo(
          'start_km_photo', 
          'Foto KM Awal', 
          startKmPhotoStatus,
          [fullStartKmPhotoUrl].whereType<String>().toList()
        ),
      if (endKmPhotoPath != null)
        DocumentInfo(
          'end_km_photo', 
          'Foto KM Akhir', 
          endKmPhotoStatus,
          [fullEndKmPhotoUrl].whereType<String>().toList()
        ),
    ];
  }

  // Getter untuk menemukan dokumen pertama yang ditolak (rejected).
  DocumentRevisionInfo? get firstRejectedDocumentInfo {
    for (final doc in allDocuments) {
      if (doc.verificationStatus.isRejected) {
        int pageIndex;
        switch (doc.type) {
          case 'standby_photo':
          case 'start_km_photo':
            pageIndex = 0;
            break;
          case 'end_km_photo':
            pageIndex = 2;
            break;
          default:
            pageIndex = 0;
        }
        return DocumentRevisionInfo(doc, pageIndex);
      }
    }
    return null;
  }

  String? get allRejectionReasons {
    final reasons = allDocuments
      .where((doc) => doc.verificationStatus.isRejected)
      .map((doc) => '• ${doc.name}: ${doc.verificationStatus.rejectionReason ?? "Ditolak."}')
      .toList();
    return reasons.isEmpty ? null : reasons.join('\n');
  }

  factory VehicleLocation.fromJson(Map<String, dynamic> json) {
    final String imageBaseUrl = dotenv.env['API_BASE_IMAGE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '';
    final wib = tz.getLocation('Asia/Jakarta');
    String buildFullUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return '';
      final String sanitizedBaseUrl = imageBaseUrl.endsWith('/api')
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 4)
          : imageBaseUrl;
      if (relativePath.startsWith('/')) return '$sanitizedBaseUrl$relativePath';
      return '$sanitizedBaseUrl/$relativePath';
    }

    DateTime parseToWib(String dateString) {
        final utcDate = DateTime.parse(dateString);
        return tz.TZDateTime.from(utcDate, wib);
    }

    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    return VehicleLocation(
      id: safeParseInt(json['id']),
      userId: safeParseInt(json['user_id']),
      vehicleId: safeParseInt(json['vehicle_id']),
      tripId: safeParseInt(json['trip_id']),
      keterangan: json['keterangan'],
      startLocation: json['start_location']?.toString(),
      standbyPhotoPath: json['standby_photo_path'],
      standbyPhotoStatus: PhotoVerificationStatus.fromJson(json, 'standby_photo'),
      startKmPhotoPath: json['start_km_photo_path'],
      startKmPhotoStatus: PhotoVerificationStatus.fromJson(json, 'start_km_photo'),
      endKmPhotoPath: json['end_km_photo_path'],
      endKmPhotoStatus: PhotoVerificationStatus.fromJson(json, 'end_km_photo'),
      endLocation: json['end_location']?.toString(),
      statusVehicleLocation: json['status_vehicle_location'] ?? 'proses',
      statusLokasi: json['status_lokasi'],
      createdAt: parseToWib(json['created_at']),
      updatedAt: parseToWib(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      fullStandbyPhotoUrl: buildFullUrl(json['full_standby_photo_url']),
      fullStartKmPhotoUrl: buildFullUrl(json['full_start_km_photo_url']),
      fullEndKmPhotoUrl: buildFullUrl(json['full_end_km_photo_url']),
    );
  }
}