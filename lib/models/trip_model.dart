// lib/models/trip_model.dart

import 'user_model.dart';

enum TripDerivedStatus { tersedia, proses, verifikasiGambar, revisiGambar, selesai, tidakDiketahui }

class PhotoVerificationStatus {
  final String? status;
  final int? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  PhotoVerificationStatus({ this.status, this.verifiedBy, this.verifiedAt, this.rejectionReason });

  factory PhotoVerificationStatus.fromJson(Map<String, dynamic> json, String fieldPrefix) {
    return PhotoVerificationStatus(
      status: json['${fieldPrefix}_status'],
      verifiedBy: Trip._parseToInt(json['${fieldPrefix}_verified_by']),
      verifiedAt: json['${fieldPrefix}_verified_at'] == null ? null : DateTime.parse(json['${fieldPrefix}_verified_at']),
      rejectionReason: json['${fieldPrefix}_rejection_reason'],
    );
  }
  
  bool get isApproved => status?.toLowerCase() == 'approved';
}

class DocumentInfo {
  final String type;
  final String name;
  final PhotoVerificationStatus verificationStatus;
  final String? url;
  DocumentInfo(this.type, this.name, this.verificationStatus, this.url);
}

class DocumentRevisionInfo {
  final DocumentInfo document;
  final int pageIndex;
  DocumentRevisionInfo(this.document, this.pageIndex);
}

class Trip {
  final int id;
  final int? userId;
  final String projectName;
  final String origin;
  final String destination;
  final String? licensePlate;
  final int? startKm;
  final int? endKm;
  final String? startKmPhotoPath;
  final String? muatPhotoPath;
  final List<String> bongkarPhotoPath;
  final String? endKmPhotoPath;
  final Map<String, List<String>> deliveryLetterPath;
  final String? deliveryOrderPath;
  final String? timbanganKendaraanPhotoPath;
  final String? segelPhotoPath;
  final String statusTrip;
  final String? jenisTrip;
  final String? statusLokasi;
  final String? statusMuatan;
  final PhotoVerificationStatus startKmPhotoStatus;
  final PhotoVerificationStatus muatPhotoStatus;
  final PhotoVerificationStatus bongkarPhotoStatus;
  final PhotoVerificationStatus endKmPhotoStatus;
  final PhotoVerificationStatus deliveryLetterInitialStatus;
  final PhotoVerificationStatus deliveryLetterFinalStatus;
  final PhotoVerificationStatus deliveryOrderStatus;
  final PhotoVerificationStatus timbanganKendaraanPhotoStatus;
  final PhotoVerificationStatus segelPhotoStatus;
  final String? fullStartKmPhotoUrl;
  final String? fullMuatPhotoUrl;
  final List<String> fullBongkarPhotoUrl;
  final String? fullEndKmPhotoUrl;
  final List<String> fullDeliveryLetterUrls;
  final String? fullDeliveryOrderUrl;
  final String? fullTimbanganKendaraanPhotoUrl;
  final String? fullSegelPhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user;

  Trip({
    required this.id, this.userId, required this.projectName, required this.origin, required this.destination,
    this.licensePlate, this.startKm, this.endKm, this.startKmPhotoPath, this.muatPhotoPath,
    required this.bongkarPhotoPath, this.endKmPhotoPath, required this.deliveryLetterPath,
    this.deliveryOrderPath, this.timbanganKendaraanPhotoPath, this.segelPhotoPath,
    required this.statusTrip, this.jenisTrip, this.statusLokasi, this.statusMuatan,
    required this.startKmPhotoStatus, required this.muatPhotoStatus, required this.bongkarPhotoStatus,
    required this.endKmPhotoStatus, required this.deliveryLetterInitialStatus, required this.deliveryLetterFinalStatus,
    required this.deliveryOrderStatus, required this.timbanganKendaraanPhotoStatus, required this.segelPhotoStatus,
    this.fullStartKmPhotoUrl, this.fullMuatPhotoUrl, required this.fullBongkarPhotoUrl,
    this.fullEndKmPhotoUrl, required this.fullDeliveryLetterUrls, this.fullDeliveryOrderUrl,
    this.fullTimbanganKendaraanPhotoUrl, this.fullSegelPhotoUrl, this.createdAt, this.updatedAt, this.user,
  });

  bool get isFullyCompleted {
    final finalLetters = deliveryLetterPath['final_letters'];
    
    return endKmPhotoPath != null && endKmPhotoStatus.isApproved &&
           bongkarPhotoPath.isNotEmpty && bongkarPhotoStatus.isApproved &&
           (finalLetters != null && finalLetters.isNotEmpty) && deliveryLetterFinalStatus.isApproved;
  }

  TripDerivedStatus get derivedStatus {
    if (getAllVerificationStatuses().any((s) => s.status?.toLowerCase() == 'rejected' || (s.rejectionReason != null && s.rejectionReason!.isNotEmpty))) {
      return TripDerivedStatus.revisiGambar;
    }
    
    if (isFullyCompleted || statusTrip == 'selesai') {
      return TripDerivedStatus.selesai;
    }

    if (statusTrip == 'verifikasi gambar') {
      return TripDerivedStatus.verifikasiGambar;
    }

    switch (statusTrip) {
      case 'tersedia': return TripDerivedStatus.tersedia;
      case 'proses': return TripDerivedStatus.proses;
      default: return TripDerivedStatus.proses;
    }
  }

  List<PhotoVerificationStatus> getAllVerificationStatuses() {
    final statuses = <PhotoVerificationStatus>[];
    if (startKmPhotoPath != null) statuses.add(startKmPhotoStatus);
    if (muatPhotoPath != null) statuses.add(muatPhotoStatus);
    if (deliveryLetterPath['initial_letters']?.isNotEmpty ?? false) statuses.add(deliveryLetterInitialStatus);
    if (deliveryOrderPath != null) statuses.add(deliveryOrderStatus);
    if (timbanganKendaraanPhotoPath != null) statuses.add(timbanganKendaraanPhotoStatus);
    if (segelPhotoPath != null) statuses.add(segelPhotoStatus);
    if (bongkarPhotoPath.isNotEmpty) statuses.add(bongkarPhotoStatus);
    if (endKmPhotoPath != null) statuses.add(endKmPhotoStatus);
    if (deliveryLetterPath['final_letters']?.isNotEmpty ?? false) statuses.add(deliveryLetterFinalStatus);
    return statuses;
  }

  List<DocumentInfo> get allDocuments {
    return [
      if (startKmPhotoPath != null) DocumentInfo('start_km_photo', 'Foto KM Awal', startKmPhotoStatus, fullStartKmPhotoUrl),
      if (muatPhotoPath != null) DocumentInfo('muat_photo', 'Foto Muat Barang', muatPhotoStatus, fullMuatPhotoUrl),
      if (deliveryLetterPath['initial_letters']?.isNotEmpty ?? false) DocumentInfo('initial_delivery_letters', 'Surat Jalan Awal', deliveryLetterInitialStatus, fullDeliveryLetterUrls.join(', ')),
      if (deliveryOrderPath != null) DocumentInfo('delivery_order', 'Delivery Order', deliveryOrderStatus, fullDeliveryOrderUrl),
      if (timbanganKendaraanPhotoPath != null) DocumentInfo('timbangan_kendaraan_photo', 'Foto Timbangan', timbanganKendaraanPhotoStatus, fullTimbanganKendaraanPhotoUrl),
      if (segelPhotoPath != null) DocumentInfo('segel_photo', 'Foto Segel', segelPhotoStatus, fullSegelPhotoUrl),
      if (bongkarPhotoPath.isNotEmpty) DocumentInfo('bongkar_photo', 'Foto Bongkar', bongkarPhotoStatus, fullBongkarPhotoUrl.join(', ')),
      if (endKmPhotoPath != null) DocumentInfo('end_km_photo', 'Foto KM Akhir', endKmPhotoStatus, fullEndKmPhotoUrl),
      if (deliveryLetterPath['final_letters']?.isNotEmpty ?? false) DocumentInfo('final_delivery_letters', 'Surat Jalan Akhir', deliveryLetterFinalStatus, fullDeliveryLetterUrls.join(', ')),
    ];
  }
  
  DocumentRevisionInfo? get firstRejectedDocumentInfo {
    for (final doc in allDocuments) {
      if (doc.verificationStatus.status?.toLowerCase() == 'rejected' ||
          (doc.verificationStatus.rejectionReason != null && doc.verificationStatus.rejectionReason!.isNotEmpty)) {
        int pageIndex;
        switch (doc.type) {
          case 'start_km_photo': pageIndex = 0; break;
          case 'muat_photo':
          case 'initial_delivery_letters': pageIndex = 3; break;
          case 'delivery_order':
          case 'timbangan_kendaraan_photo':
          case 'segel_photo': pageIndex = 4; break;
          case 'bongkar_photo':
          case 'end_km_photo':
          case 'final_delivery_letters': pageIndex = 7; break;
          default: pageIndex = 0;
        }
        return DocumentRevisionInfo(doc, pageIndex);
      }
    }
    return null;
  }

  String? get allRejectionReasons {
    final reasons = allDocuments
      .where((doc) => (doc.verificationStatus.status?.toLowerCase() == 'rejected' || (doc.verificationStatus.rejectionReason != null && doc.verificationStatus.rejectionReason!.isNotEmpty)))
      .map((doc) {
          final reason = doc.verificationStatus.rejectionReason;
          return '• ${doc.name}: ${reason != null && reason.isNotEmpty ? reason : "Ditolak tanpa alasan spesifik."}';
      })
      .toList();

    if (reasons.isEmpty) return null;
    return reasons.join('\n');
  }

  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _parseToListString(dynamic jsonValue) {
    if (jsonValue is List) return List<String>.from(jsonValue.map((e) => e.toString()));
    return [];
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> parseDeliveryLetterPath(dynamic jsonValue) {
      if (jsonValue is Map<String, dynamic>) {
        return {
          'initial_letters': jsonValue.containsKey('initial_letters') ? _parseToListString(jsonValue['initial_letters']) : [],
          'final_letters': jsonValue.containsKey('final_letters') ? _parseToListString(jsonValue['final_letters']) : [],
        };
      }
      return {'initial_letters': [], 'final_letters': []};
    }

    return Trip(
      id: _parseToInt(json['id']) ?? 0,
      userId: _parseToInt(json['user_id']),
      projectName: json['project_name'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      licensePlate: json['license_plate'],
      startKm: _parseToInt(json['start_km']),
      endKm: _parseToInt(json['end_km']),
      startKmPhotoPath: json['start_km_photo_path'],
      muatPhotoPath: json['muat_photo_path'],
      bongkarPhotoPath: _parseToListString(json['bongkar_photo_path']),
      endKmPhotoPath: json['end_km_photo_path'],
      deliveryLetterPath: parseDeliveryLetterPath(json['delivery_letter_path']),
      deliveryOrderPath: json['delivery_order_path'],
      timbanganKendaraanPhotoPath: json['timbangan_kendaraan_photo_path'],
      segelPhotoPath: json['segel_photo_path'],
      statusTrip: json['status_trip'] ?? 'tersedia',
      jenisTrip: json['jenis_trip'],
      statusLokasi: json['status_lokasi'],
      statusMuatan: json['status_muatan'],
      startKmPhotoStatus: PhotoVerificationStatus.fromJson(json, 'start_km_photo'),
      muatPhotoStatus: PhotoVerificationStatus.fromJson(json, 'muat_photo'),
      bongkarPhotoStatus: PhotoVerificationStatus.fromJson(json, 'bongkar_photo'),
      endKmPhotoStatus: PhotoVerificationStatus.fromJson(json, 'end_km_photo'),
      deliveryLetterInitialStatus: PhotoVerificationStatus.fromJson(json, 'delivery_letter_initial'),
      deliveryLetterFinalStatus: PhotoVerificationStatus.fromJson(json, 'delivery_letter_final'),
      deliveryOrderStatus: PhotoVerificationStatus.fromJson(json, 'delivery_order'),
      timbanganKendaraanPhotoStatus: PhotoVerificationStatus.fromJson(json, 'timbangan_kendaraan_photo'),
      segelPhotoStatus: PhotoVerificationStatus.fromJson(json, 'segel_photo'),
      fullStartKmPhotoUrl: json['full_start_km_photo_url'],
      fullMuatPhotoUrl: json['full_muat_photo_url'],
      fullBongkarPhotoUrl: _parseToListString(json['full_bongkar_photo_url']),
      fullEndKmPhotoUrl: json['full_end_km_photo_url'],
      fullDeliveryLetterUrls: _parseToListString(json['full_delivery_letter_urls']),
      fullDeliveryOrderUrl: json['full_delivery_order_url'],
      fullTimbanganKendaraanPhotoUrl: json['full_timbangan_kendaraan_photo_url'],
      fullSegelPhotoUrl: json['full_segel_photo_url'],
      createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}