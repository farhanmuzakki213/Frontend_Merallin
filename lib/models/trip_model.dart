// lib/models/trip_model.dart

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
  final String? deliveryLetterPath;
  final String statusTrip; // 'tersedia', 'proses', 'selesai'
  final String? statusLokasi;
  final String? statusMuatan;

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
    this.deliveryLetterPath,
    required this.statusTrip,
    this.statusLokasi,
    this.statusMuatan,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      userId: json['user_id'],
      projectName: json['project_name'],
      origin: json['origin'],
      destination: json['destination'],
      licensePlate: json['license_plate'],
      startKm: json['start_km'],
      startKmPhotoPath: json['start_km_photo_path'],
      muatPhotoPath: json['muat_photo_path'],
      bongkarPhotoPath: json['bongkar_photo_path'],
      endKm: json['end_km'],
      endKmPhotoPath: json['end_km_photo_path'],
      deliveryLetterPath: json['delivery_letter_path'],
      statusTrip: json['status_trip'],
      statusLokasi: json['status_lokasi'],
      statusMuatan: json['status_muatan'],
    );
  }
}