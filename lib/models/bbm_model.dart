// lib/models/bbm_model.dart
import 'vehicle_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/timezone.dart' as tz;

/*
 * Kelas untuk menampung status verifikasi foto beserta alasan penolakannya.
 */
class BbmPhotoVerificationStatus {
  final String? status;
  final String? rejectionReason;

  BbmPhotoVerificationStatus({this.status, this.rejectionReason});

  factory BbmPhotoVerificationStatus.fromJson(
      Map<String, dynamic> json, String fieldPrefix) {
    return BbmPhotoVerificationStatus(
      status: json['${fieldPrefix}_status'],
      rejectionReason: json['${fieldPrefix}_rejection_reason'],
    );
  }


  // getter untuk persetuan dan penolakan
  bool get isApproved => status?.toLowerCase() == 'approved';
  bool get isRejected => status?.toLowerCase() == 'rejected';
}

/*
 * class untuk menampung informasi detail dari sebuah dokumen (foto) BBM
 */
class BbmDocumentInfo {
  final String type;
  final String name;
  final BbmPhotoVerificationStatus verificationStatus;
  final List<String> urls;
  BbmDocumentInfo(this.type, this.name, this.verificationStatus, this.urls);
}

/*
 * class untuk menampung informasi dokumen yang perlu direvisi,
 * menggabungkan data dokumen dengan `pageIndex` untuk navigasi di UI.
 */
class BbmDocumentRevisionInfo {
  final BbmDocumentInfo document;
  final int pageIndex;
  BbmDocumentRevisionInfo(this.document, this.pageIndex);
}


enum BbmStatus { proses, verifikasiGambar, selesai, revisiGambar }

/*
 * Model utama data pengajuan BBM oleh user untuk sebuah kendaraan.
 */
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

  bool get isFullyCompleted {
    return startKmPhotoPath != null &&
        startKmPhotoStatus.isApproved &&
        endKmPhotoPath != null &&
        endKmPhotoStatus.isApproved &&
        notaPengisianPhotoPath != null &&
        notaPengisianPhotoStatus.isApproved;
  }

  BbmStatus get derivedStatus {
    if (allDocuments.any((doc) => doc.verificationStatus.isRejected)) {
      return BbmStatus.revisiGambar;
    }
    if (statusBbmKendaraan == 'selesai') {
      return BbmStatus.selesai;
    }
    if (statusBbmKendaraan == 'verifikasi gambar') {
      return BbmStatus.verifikasiGambar;
    }
    return BbmStatus.proses;
  }
  
  List<BbmDocumentInfo> get allDocuments {
    return [
      if (startKmPhotoPath != null)
        BbmDocumentInfo(
          'start_km_photo', 
          'Foto KM Awal', 
          startKmPhotoStatus,
          [fullStartKmPhotoUrl].whereType<String>().toList()
        ),
      if (endKmPhotoPath != null)
        BbmDocumentInfo(
          'end_km_photo', 
          'Foto KM Akhir', 
          endKmPhotoStatus,
          [fullEndKmPhotoUrl].whereType<String>().toList()
        ),
      if (notaPengisianPhotoPath != null)
        BbmDocumentInfo(
          'nota_pengisian_photo', 
          'Foto Nota Pengisian',
          notaPengisianPhotoStatus,
          [fullNotaPengisianPhotoUrl].whereType<String>().toList()
        ),
    ];
  }

  /*
   * Getter untuk menemukan dokumen pertama yang ditolak (rejected).
   * untuk mengarahkan user langsung ke halaman revisi yang sesuai.
   */
  BbmDocumentRevisionInfo? get firstRejectedDocumentInfo {
    for (final doc in allDocuments) {
      if (doc.verificationStatus.isRejected) {
        int pageIndex;
        switch (doc.type) {
          case 'start_km_photo':
            pageIndex = 0;
            break;
          case 'end_km_photo':
          case 'nota_pengisian_photo':
            pageIndex = 2;
            break;
          default:
            pageIndex = 0;
        }
        return BbmDocumentRevisionInfo(doc, pageIndex);
      }
    }
    return null;
  }


  /*
   * Getter untuk mengumpulkan semua alasan penolakan dari dokumen yang ditolak menjadi satu string yang terformat.
   */
  String? get allRejectionReasons {
    final reasons = allDocuments
      .where((doc) => doc.verificationStatus.isRejected)
      .map((doc) => '• ${doc.name}: ${doc.verificationStatus.rejectionReason ?? "Ditolak."}')
      .toList();
    return reasons.isEmpty ? null : reasons.join('\n');
  }

  factory BbmKendaraan.fromJson(Map<String, dynamic> json) {
    final String imageBaseUrl = dotenv.env['API_BASE_IMAGE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '';
    final wib = tz.getLocation('Asia/Jakarta');
    final utcDate = DateTime.parse(json['created_at']);
    
    String buildFullUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return '';
      final String sanitizedBaseUrl = imageBaseUrl.endsWith('/api')
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 4)
          : imageBaseUrl;
      if (relativePath.startsWith('/')) return '$sanitizedBaseUrl$relativePath';
      return '$sanitizedBaseUrl/$relativePath';
    }
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    return BbmKendaraan(
      id: safeParseInt(json['id']),
      userId: safeParseInt(json['user_id']),
      vehicleId: safeParseInt(json['vehicle_id']),
      statusBbmKendaraan: json['status_bbm_kendaraan'] ?? 'proses',
      statusPengisian: json['status_pengisian'],
      startKmPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'start_km_photo'),
      endKmPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'end_km_photo'),
      notaPengisianPhotoStatus: BbmPhotoVerificationStatus.fromJson(json, 'nota_pengisian_photo'),
      startKmPhotoPath: json['start_km_photo_path'],
      endKmPhotoPath: json['end_km_photo_path'],
      notaPengisianPhotoPath: json['nota_pengisian_photo_path'],
      fullStartKmPhotoUrl: buildFullUrl(json['full_start_km_photo_url']),
      fullEndKmPhotoUrl: buildFullUrl(json['full_end_km_photo_url']),
      fullNotaPengisianPhotoUrl: buildFullUrl(json['full_nota_pengisian_photo_url']),
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      createdAt: tz.TZDateTime.from(utcDate, wib),
    );
  }
}