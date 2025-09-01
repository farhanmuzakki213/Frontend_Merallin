// lib/models/bbm_model.dart
import 'vehicle_model.dart';

class BbmPhotoVerificationStatus {
  final String? status;
  final String? rejectionReason;

  BbmPhotoVerificationStatus({ this.status, this.rejectionReason });

  factory BbmPhotoVerificationStatus.fromJson(Map<String, dynamic> json, String fieldPrefix) {
    return BbmPhotoVerificationStatus(
      status: json['${fieldPrefix}_status'],
      rejectionReason: json['${fieldPrefix}_rejection_reason'],
    );
  }
}

extension BbmPhotoStatusCheck on BbmPhotoVerificationStatus {
  bool get isRejected => (status?.toLowerCase() == 'rejected' ||
      (rejectionReason != null && rejectionReason!.isNotEmpty));
      
  bool get isApproved => status?.toLowerCase() == 'approved';

  bool get isPending => status?.toLowerCase() == 'pending' || status == null || status!.isEmpty;
}

enum BbmStatus { proses, verifikasiGambar, selesai, ditolak }
enum BbmProgressStatus { sedangAntri, sedangIsiBbm, selesaiIsiBbm, tidakAda }

class BbmKendaraan {
  final int id;
  final int userId;
  final int vehicleId;
  final String statusBbmKendaraan;
  final String? statusPengisian;
  
  final BbmPhotoVerificationStatus startKmPhotoStatus;
  final BbmPhotoVerificationStatus endKmPhotoStatus;
  final BbmPhotoVerificationStatus notaPengisianPhotoStatus;

  final String? startKmPhotoPath;
  final String? endKmPhotoPath;
  final String? notaPengisianPhotoPath;

  final String? fullStartKmPhotoUrl;
  final String? fullEndKmPhotoUrl;
  final String? fullNotaPengisianPhotoUrl;

  final Vehicle? vehicle;
  final DateTime createdAt;

  BbmKendaraan({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.statusBbmKendaraan,
    this.statusPengisian,
    required this.startKmPhotoStatus,
    required this.endKmPhotoStatus,
    required this.notaPengisianPhotoStatus,
    this.startKmPhotoPath,
    this.endKmPhotoPath,
    this.notaPengisianPhotoPath,
    this.fullStartKmPhotoUrl,
    this.fullEndKmPhotoUrl,
    this.fullNotaPengisianPhotoUrl,
    this.vehicle,
    required this.createdAt,
  });

  // --- PERBAIKAN LOGIKA STATUS DI SINI ---
  BbmStatus get derivedStatus {
    // Prioritas 1: Jika ada foto yang ditolak, statusnya adalah 'ditolak'.
    if (startKmPhotoStatus.isRejected || endKmPhotoStatus.isRejected || notaPengisianPhotoStatus.isRejected) {
      return BbmStatus.ditolak;
    }
    // Prioritas 2: Jika status dari backend adalah 'selesai', maka selesai.
    if (statusBbmKendaraan == 'selesai') {
      return BbmStatus.selesai;
    }
    bool hasPendingPhotos = startKmPhotoStatus.isPending || endKmPhotoStatus.isPending || notaPengisianPhotoStatus.isPending;
    // Prioritas 3: Jika status dari backend adalah 'verifikasi gambar', maka menunggu verifikasi.
    if (statusBbmKendaraan == 'verifikasi gambar' && !hasPendingPhotos) {
      return BbmStatus.verifikasiGambar;
    }
    // Default: Jika tidak ada kondisi di atas, berarti sedang dalam proses.
    return BbmStatus.proses;
  }

  BbmProgressStatus get progressStatus {
    switch (statusPengisian) {
      case 'sedang antri': return BbmProgressStatus.sedangAntri;
      case 'sedang isi bbm': return BbmProgressStatus.sedangIsiBbm;
      case 'selesai isi bbm': return BbmProgressStatus.selesaiIsiBbm;
      default: return BbmProgressStatus.tidakAda;
    }
  }

  factory BbmKendaraan.fromJson(Map<String, dynamic> json) {
    return BbmKendaraan(
      id: json['id'],
      userId: json['user_id'],
      vehicleId: json['vehicle_id'],
      statusBbmKendaraan: json['status_bbm_kendaraan'] ?? 'proses',
      statusPengisian: json['status_pengisian'],
      startKmPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'start_km_photo'),
      endKmPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'end_km_photo'),
      notaPengisianPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'nota_pengisian_photo'),
      startKmPhotoPath: json['start_km_photo_path'],
      endKmPhotoPath: json['end_km_photo_path'],
      notaPengisianPhotoPath: json['nota_pengisian_photo_path'],
      fullStartKmPhotoUrl: json['full_start_km_photo_url'],
      fullEndKmPhotoUrl: json['full_end_km_photo_url'],
      fullNotaPengisianPhotoUrl: json['full_nota_pengisian_photo_url'],
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}