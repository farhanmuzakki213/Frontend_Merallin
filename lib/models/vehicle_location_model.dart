// lib/models/vehicle_location_model.dart

import 'user_model.dart';
import 'vehicle_model.dart';
import 'trip_model.dart'; // Re-using helper classes from trip_model

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
  });

  bool get isFullyCompleted {
    return endKmPhotoPath != null && endKmPhotoStatus.isApproved;
  }

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
  
  DocumentRevisionInfo? get firstRejectedDocumentInfo {
    final documents = [
      if (standbyPhotoPath != null) DocumentInfo('standby_photo', 'Foto Standby', standbyPhotoStatus, null),
      if (startKmPhotoPath != null) DocumentInfo('start_km_photo', 'Foto KM Awal', startKmPhotoStatus, null),
      if (endKmPhotoPath != null) DocumentInfo('end_km_photo', 'Foto KM Akhir', endKmPhotoStatus, null),
    ];

    for (final doc in documents) {
      if (doc.verificationStatus.status?.toLowerCase() == 'rejected') {
        int pageIndex;
        switch (doc.type) {
          case 'standby_photo':
          case 'start_km_photo':
            pageIndex = 0;
            break;
          // --- PERBAIKAN DI SINI ---
          case 'end_km_photo':
            pageIndex = 2; // Indeks halaman 'Bukti Akhir' adalah 2
            break;
          // -------------------------
          default:
            pageIndex = 0;
        }
        return DocumentRevisionInfo(doc, pageIndex);
      }
    }
    return null;
  }

  String? get allRejectionReasons {
    final documents = [
      DocumentInfo('standby_photo', 'Foto Standby', standbyPhotoStatus, null),
      DocumentInfo('start_km_photo', 'Foto KM Awal', startKmPhotoStatus, null),
      DocumentInfo('end_km_photo', 'Foto KM Akhir', endKmPhotoStatus, null),
    ];
    final reasons = documents
      .where((doc) => doc.verificationStatus.status?.toLowerCase() == 'rejected')
      .map((doc) => '• ${doc.name}: ${doc.verificationStatus.rejectionReason ?? "Ditolak."}')
      .toList();
    return reasons.isEmpty ? null : reasons.join('\n');
  }

  factory VehicleLocation.fromJson(Map<String, dynamic> json) {
    return VehicleLocation(
      id: json['id'],
      userId: json['user_id'],
      vehicleId: json['vehicle_id'],
      tripId: json['trip_id'],
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
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
    );
  }
}