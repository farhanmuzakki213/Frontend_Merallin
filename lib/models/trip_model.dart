// lib/models/trip_model.dart

import 'user_model.dart';
import 'vehicle_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/timezone.dart' as tz;


// merepresentasikan status turunan (derived status) dari sebuah perjalanan (Trip).
enum TripDerivedStatus {
  tersedia,
  proses,
  verifikasiGambar,
  revisiGambar,
  selesai,
  tidakDiketahui
}


/*
 * Kelas untuk menampung status verifikasi foto, termasuk siapa yang memverifikasi dan kapan.
 */
class PhotoVerificationStatus {
  final String? status;
  final int? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  PhotoVerificationStatus(
      {this.status, this.verifiedBy, this.verifiedAt, this.rejectionReason});

  factory PhotoVerificationStatus.fromJson(
      Map<String, dynamic> json, String fieldPrefix) {
    return PhotoVerificationStatus(
      status: json['${fieldPrefix}_status'],
      verifiedBy: Trip._parseToInt(json['${fieldPrefix}_verified_by']),
      verifiedAt: json['${fieldPrefix}_verified_at'] == null
          ? null
          : DateTime.parse(json['${fieldPrefix}_verified_at']),
      rejectionReason: json['${fieldPrefix}_rejection_reason'],
    );
  }

  bool get isApproved => status?.toLowerCase() == 'approved';
  bool get isRejected => status?.toLowerCase() == 'rejected';
}

class DocumentInfo {
  final String type;
  final String name;
  final PhotoVerificationStatus verificationStatus;
  final List<String> urls;
  DocumentInfo(this.type, this.name, this.verificationStatus, this.urls);
}

class DocumentRevisionInfo {
  final DocumentInfo document;
  final int pageIndex;
  DocumentRevisionInfo(this.document, this.pageIndex);
}


/*
 * Model data sebuah perjalanan (Trip).
 * Berisi semua informasi terkait perjalanan, mulai dari alamat, kendaraan, hingga semua foto dokumentasi.
 */
class Trip {
  final int id;
  final int? userId;
  final String projectName;
  final String originAddress;
  final String originLink;
  final String destinationAddress;
  final String destinationLink;
  final int? vehicleId;
  final String? slotTime;
  final String? jenisBerat;
  final int? jumlahGudangMuat;
  final int? jumlahGudangBongkar;
  final int? startKm;
  final int? endKm;
  final String? statusTrip;
  final String? jenisTrip;
  final String? statusLokasi;
  final String? statusMuatan;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user;
  final Vehicle? vehicle;

  // Paths
  final String? startKmPhotoPath;
  final String? kmMuatPhotoPath;
  final String? kedatanganMuatPhotoPath;
  final String? deliveryOrderPath;
  final Map<String, List<String>> muatPhotoPath;
  final Map<String, List<String>> deliveryLetterPath;
  final String? timbanganKendaraanPhotoPath;
  final String? segelPhotoPath;
  final String? endKmPhotoPath;
  final String? kedatanganBongkarPhotoPath;
  final Map<String, List<String>> bongkarPhotoPath;

  // Statuses
  final PhotoVerificationStatus startKmPhotoStatus;
  final PhotoVerificationStatus kmMuatPhotoStatus;
  final PhotoVerificationStatus kedatanganMuatPhotoStatus;
  final PhotoVerificationStatus deliveryOrderStatus;
  final PhotoVerificationStatus muatPhotoStatus;
  final PhotoVerificationStatus deliveryLetterInitialStatus;
  final PhotoVerificationStatus timbanganKendaraanPhotoStatus;
  final PhotoVerificationStatus segelPhotoStatus;
  final PhotoVerificationStatus endKmPhotoStatus;
  final PhotoVerificationStatus kedatanganBongkarPhotoStatus;
  final PhotoVerificationStatus bongkarPhotoStatus;
  final PhotoVerificationStatus deliveryLetterFinalStatus;

  // Full URLs from backend
  final String? fullStartKmPhotoUrl;
  final String? fullKmMuatPhotoUrl;
  final String? fullKedatanganMuatPhotoUrl;
  final String? fullDeliveryOrderUrl;
  final Map<String, List<String>> fullMuatPhotoUrls;
  final Map<String, List<String>> fullDeliveryLetterUrls;
  final String? fullTimbanganKendaraanPhotoUrl;
  final String? fullSegelPhotoUrl;
  final String? fullEndKmPhotoUrl;
  final String? fullKedatanganBongkarPhotoUrl;
  final Map<String, List<String>> fullBongkarPhotoUrls;

  Trip({
    required this.id,
    this.userId,
    required this.projectName,
    required this.originAddress,
    required this.originLink,
    required this.destinationAddress,
    required this.destinationLink,
    this.vehicleId,
    this.slotTime,
    this.jenisBerat,
    this.jumlahGudangMuat,
    this.jumlahGudangBongkar,
    this.startKm,
    this.endKm,
    this.statusTrip,
    this.jenisTrip,
    this.statusLokasi,
    this.statusMuatan,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.vehicle,
    this.startKmPhotoPath,
    this.kmMuatPhotoPath,
    this.kedatanganMuatPhotoPath,
    this.deliveryOrderPath,
    required this.muatPhotoPath,
    required this.deliveryLetterPath,
    this.timbanganKendaraanPhotoPath,
    this.segelPhotoPath,
    this.endKmPhotoPath,
    this.kedatanganBongkarPhotoPath,
    required this.bongkarPhotoPath,
    required this.startKmPhotoStatus,
    required this.kmMuatPhotoStatus,
    required this.kedatanganMuatPhotoStatus,
    required this.deliveryOrderStatus,
    required this.muatPhotoStatus,
    required this.deliveryLetterInitialStatus,
    required this.timbanganKendaraanPhotoStatus,
    required this.segelPhotoStatus,
    required this.endKmPhotoStatus,
    required this.kedatanganBongkarPhotoStatus,
    required this.bongkarPhotoStatus,
    required this.deliveryLetterFinalStatus,
    this.fullStartKmPhotoUrl,
    this.fullKmMuatPhotoUrl,
    this.fullKedatanganMuatPhotoUrl,
    this.fullDeliveryOrderUrl,
    required this.fullMuatPhotoUrls,
    required this.fullDeliveryLetterUrls,
    this.fullTimbanganKendaraanPhotoUrl,
    this.fullSegelPhotoUrl,
    this.fullEndKmPhotoUrl,
    this.fullKedatanganBongkarPhotoUrl,
    required this.fullBongkarPhotoUrls,
  });

  // Membuat salinan objek Trip dengan beberapa field yang diperbaharui
  Trip copyWith({
    int? id,
    int? userId,
    String? projectName,
    String? originAddress,
    String? originLink,
    String? destinationAddress,
    String? destinationLink,
    int? vehicleId,
    String? slotTime,
    String? jenisBerat,
    int? jumlahGudangMuat,
    int? jumlahGudangBongkar,
    int? startKm,
    int? endKm,
    String? statusTrip,
    String? jenisTrip,
    String? statusLokasi,
    String? statusMuatan,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    Vehicle? vehicle,
    String? startKmPhotoPath,
    String? kmMuatPhotoPath,
    String? kedatanganMuatPhotoPath,
    String? deliveryOrderPath,
    Map<String, List<String>>? muatPhotoPath,
    Map<String, List<String>>? deliveryLetterPath,
    String? timbanganKendaraanPhotoPath,
    String? segelPhotoPath,
    String? endKmPhotoPath,
    String? kedatanganBongkarPhotoPath,
    Map<String, List<String>>? bongkarPhotoPath,
    PhotoVerificationStatus? startKmPhotoStatus,
    PhotoVerificationStatus? kmMuatPhotoStatus,
    PhotoVerificationStatus? kedatanganMuatPhotoStatus,
    PhotoVerificationStatus? deliveryOrderStatus,
    PhotoVerificationStatus? muatPhotoStatus,
    PhotoVerificationStatus? deliveryLetterInitialStatus,
    PhotoVerificationStatus? timbanganKendaraanPhotoStatus,
    PhotoVerificationStatus? segelPhotoStatus,
    PhotoVerificationStatus? endKmPhotoStatus,
    PhotoVerificationStatus? kedatanganBongkarPhotoStatus,
    PhotoVerificationStatus? bongkarPhotoStatus,
    PhotoVerificationStatus? deliveryLetterFinalStatus,
    String? fullStartKmPhotoUrl,
    String? fullKmMuatPhotoUrl,
    String? fullKedatanganMuatPhotoUrl,
    String? fullDeliveryOrderUrl,
    Map<String, List<String>>? fullMuatPhotoUrls,
    Map<String, List<String>>? fullDeliveryLetterUrls,
    String? fullTimbanganKendaraanPhotoUrl,
    String? fullSegelPhotoUrl,
    String? fullEndKmPhotoUrl,
    String? fullKedatanganBongkarPhotoUrl,
    Map<String, List<String>>? fullBongkarPhotoUrls,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectName: projectName ?? this.projectName,
      originAddress: originAddress ?? this.originAddress,
      originLink: originLink ?? this.originLink,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLink: destinationLink ?? this.destinationLink,
      vehicleId: vehicleId ?? this.vehicleId,
      slotTime: slotTime ?? this.slotTime,
      jenisBerat: jenisBerat ?? this.jenisBerat,
      jumlahGudangMuat: jumlahGudangMuat ?? this.jumlahGudangMuat,
      jumlahGudangBongkar: jumlahGudangBongkar ?? this.jumlahGudangBongkar,
      startKm: startKm ?? this.startKm,
      endKm: endKm ?? this.endKm,
      statusTrip: statusTrip ?? this.statusTrip,
      jenisTrip: jenisTrip ?? this.jenisTrip,
      statusLokasi: statusLokasi ?? this.statusLokasi,
      statusMuatan: statusMuatan ?? this.statusMuatan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      vehicle: vehicle ?? this.vehicle,
      startKmPhotoPath: startKmPhotoPath ?? this.startKmPhotoPath,
      kmMuatPhotoPath: kmMuatPhotoPath ?? this.kmMuatPhotoPath,
      kedatanganMuatPhotoPath:
          kedatanganMuatPhotoPath ?? this.kedatanganMuatPhotoPath,
      deliveryOrderPath: deliveryOrderPath ?? this.deliveryOrderPath,
      muatPhotoPath: muatPhotoPath ?? this.muatPhotoPath,
      deliveryLetterPath: deliveryLetterPath ?? this.deliveryLetterPath,
      timbanganKendaraanPhotoPath:
          timbanganKendaraanPhotoPath ?? this.timbanganKendaraanPhotoPath,
      segelPhotoPath: segelPhotoPath ?? this.segelPhotoPath,
      endKmPhotoPath: endKmPhotoPath ?? this.endKmPhotoPath,
      kedatanganBongkarPhotoPath:
          kedatanganBongkarPhotoPath ?? this.kedatanganBongkarPhotoPath,
      bongkarPhotoPath: bongkarPhotoPath ?? this.bongkarPhotoPath,
      startKmPhotoStatus: startKmPhotoStatus ?? this.startKmPhotoStatus,
      kmMuatPhotoStatus: kmMuatPhotoStatus ?? this.kmMuatPhotoStatus,
      kedatanganMuatPhotoStatus:
          kedatanganMuatPhotoStatus ?? this.kedatanganMuatPhotoStatus,
      deliveryOrderStatus: deliveryOrderStatus ?? this.deliveryOrderStatus,
      muatPhotoStatus: muatPhotoStatus ?? this.muatPhotoStatus,
      deliveryLetterInitialStatus:
          deliveryLetterInitialStatus ?? this.deliveryLetterInitialStatus,
      timbanganKendaraanPhotoStatus:
          timbanganKendaraanPhotoStatus ?? this.timbanganKendaraanPhotoStatus,
      segelPhotoStatus: segelPhotoStatus ?? this.segelPhotoStatus,
      endKmPhotoStatus: endKmPhotoStatus ?? this.endKmPhotoStatus,
      kedatanganBongkarPhotoStatus:
          kedatanganBongkarPhotoStatus ?? this.kedatanganBongkarPhotoStatus,
      bongkarPhotoStatus: bongkarPhotoStatus ?? this.bongkarPhotoStatus,
      deliveryLetterFinalStatus:
          deliveryLetterFinalStatus ?? this.deliveryLetterFinalStatus,
      fullStartKmPhotoUrl: fullStartKmPhotoUrl ?? this.fullStartKmPhotoUrl,
      fullKmMuatPhotoUrl: fullKmMuatPhotoUrl ?? this.fullKmMuatPhotoUrl,
      fullKedatanganMuatPhotoUrl:
          fullKedatanganMuatPhotoUrl ?? this.fullKedatanganMuatPhotoUrl,
      fullDeliveryOrderUrl: fullDeliveryOrderUrl ?? this.fullDeliveryOrderUrl,
      fullMuatPhotoUrls: fullMuatPhotoUrls ?? this.fullMuatPhotoUrls,
      fullDeliveryLetterUrls:
          fullDeliveryLetterUrls ?? this.fullDeliveryLetterUrls,
      fullTimbanganKendaraanPhotoUrl:
          fullTimbanganKendaraanPhotoUrl ?? this.fullTimbanganKendaraanPhotoUrl,
      fullSegelPhotoUrl: fullSegelPhotoUrl ?? this.fullSegelPhotoUrl,
      fullEndKmPhotoUrl: fullEndKmPhotoUrl ?? this.fullEndKmPhotoUrl,
      fullKedatanganBongkarPhotoUrl:
          fullKedatanganBongkarPhotoUrl ?? this.fullKedatanganBongkarPhotoUrl,
      fullBongkarPhotoUrls: fullBongkarPhotoUrls ?? this.fullBongkarPhotoUrls,
    );
  }


  // Getter untuk memeriksa apakah semua proses akhir perjalanan telah selesai dan disetujui.
  bool get isFullyCompleted {
    final finalLetters = deliveryLetterPath['final_letters'];

    return endKmPhotoPath != null &&
        endKmPhotoStatus.isApproved &&
        kedatanganBongkarPhotoPath != null &&
        kedatanganBongkarPhotoStatus.isApproved &&
        bongkarPhotoPath.isNotEmpty &&
        bongkarPhotoStatus.isApproved &&
        (finalLetters != null && finalLetters.isNotEmpty) &&
        deliveryLetterFinalStatus.isApproved;
  }

  TripDerivedStatus get derivedStatus {
    if (getAllVerificationStatuses()
        .any((s) => s.status?.toLowerCase() == 'rejected')) {
      return TripDerivedStatus.revisiGambar;
    }

    if (isFullyCompleted || statusTrip == 'selesai') {
      return TripDerivedStatus.selesai;
    }
    switch (statusTrip) {
      case 'tersedia':
        return TripDerivedStatus.tersedia;
      case 'proses':
        return TripDerivedStatus.proses;
      case 'verifikasi gambar':
        return TripDerivedStatus.verifikasiGambar;
      case 'revisi gambar':
        return TripDerivedStatus.revisiGambar;
      default:
        return TripDerivedStatus.proses;
    }
  }


  // Fungsi untuk mendapatkan semua status verifikasi dari seluruh dokumen.
  List<PhotoVerificationStatus> getAllVerificationStatuses() {
    return allDocuments.map((doc) => doc.verificationStatus).toList();
  }


  // Getter untuk mengumpulkan semua dokumen/foto yang telah diunggah selama perjalanan.
  List<DocumentInfo> get allDocuments {
    return [
      if (startKmPhotoPath != null)
        DocumentInfo('start_km_photo', 'Foto KM Awal', startKmPhotoStatus,
            [fullStartKmPhotoUrl].whereType<String>().toList()),
      if (kmMuatPhotoPath != null)
        DocumentInfo(
            'km_muat_photo',
            'Foto KM di Lokasi Muat',
            kmMuatPhotoStatus,
            [fullKmMuatPhotoUrl].whereType<String>().toList()),
      if (kedatanganMuatPhotoPath != null)
        DocumentInfo(
            'kedatangan_muat_photo',
            'Foto Tiba di Lokasi Muat',
            kedatanganMuatPhotoStatus,
            [fullKedatanganMuatPhotoUrl].whereType<String>().toList()),
      if (deliveryOrderPath != null)
        DocumentInfo(
            'delivery_order_photo',
            'Delivery Order',
            deliveryOrderStatus,
            [fullDeliveryOrderUrl].whereType<String>().toList()),
      if (muatPhotoPath.isNotEmpty)
        DocumentInfo('muat_photo', 'Foto Muat Barang', muatPhotoStatus,
            fullMuatPhotoUrls.values.expand((list) => list).toList()),
      if (deliveryLetterPath['initial_letters']?.isNotEmpty ?? false)
        DocumentInfo(
            'delivery_letter_initial',
            'Surat Jalan Awal',
            deliveryLetterInitialStatus,
            fullDeliveryLetterUrls['initial'] ?? []),
      if (timbanganKendaraanPhotoPath != null)
        DocumentInfo(
            'timbangan_kendaraan_photo',
            'Foto Timbangan',
            timbanganKendaraanPhotoStatus,
            [fullTimbanganKendaraanPhotoUrl].whereType<String>().toList()),
      if (segelPhotoPath != null)
        DocumentInfo('segel_photo', 'Foto Segel', segelPhotoStatus,
            [fullSegelPhotoUrl].whereType<String>().toList()),
      if (kedatanganBongkarPhotoPath != null)
        DocumentInfo(
            'kedatangan_bongkar_photo',
            'Foto Tiba di Lokasi Bongkar',
            kedatanganBongkarPhotoStatus,
            [fullKedatanganBongkarPhotoUrl].whereType<String>().toList()),
      if (bongkarPhotoPath.isNotEmpty)
        DocumentInfo('bongkar_photo', 'Foto Bongkar Barang', bongkarPhotoStatus,
            fullBongkarPhotoUrls.values.expand((list) => list).toList()),
      if (endKmPhotoPath != null)
        DocumentInfo('end_km_photo', 'Foto KM Akhir', endKmPhotoStatus,
            [fullEndKmPhotoUrl].whereType<String>().toList()),
      if (deliveryLetterPath['final_letters']?.isNotEmpty ?? false)
        DocumentInfo('delivery_letter_final', 'Surat Jalan Akhir',
            deliveryLetterFinalStatus, fullDeliveryLetterUrls['final'] ?? []),
    ];
  }


/*
 *  Getter untuk menemukan dokumen pertama yang ditolak (rejected).
 *  Untuk mengarahkan user langsung ke halaman revisi yang sesuai.
 */
  DocumentRevisionInfo? get firstRejectedDocumentInfo {
    for (final doc in allDocuments) {
      if (doc.verificationStatus.isRejected) {
        int pageIndex;
        switch (doc.type) {
          case 'start_km_photo':
            pageIndex = 0;
            break;
          case 'km_muat_photo':
          case 'kedatangan_muat_photo':
          case 'delivery_order_photo':
            pageIndex = 2;
            break;
          case 'muat_photo':
            pageIndex = 3;
            break;
          case 'delivery_letter_initial':
          case 'timbangan_kendaraan_photo':
          case 'segel_photo':
            pageIndex = 4;
            break;
          case 'kedatangan_bongkar_photo':
          case 'end_km_photo':
            pageIndex = 6;
            break;
          case 'bongkar_photo':
            pageIndex = 7;
            break;
          case 'delivery_letter_final':
            pageIndex = 8;
            break;
          default:
            pageIndex = 0;
        }
        return DocumentRevisionInfo(doc, pageIndex);
      }
    }
    return null;
  }

  // Getter untuk mengumpulkan semua alasan penolakan dari dokumen yang ditolak menjadi satu string yang mudah dibaca
  String? get allRejectionReasons {
    final reasons = allDocuments
        .where((doc) => doc.verificationStatus.isRejected)
        .map((doc) {
      final reason = doc.verificationStatus.rejectionReason;
      return '• ${doc.name}: ${reason != null && reason.isNotEmpty ? reason : "Ditolak tanpa alasan spesifik."}';
    }).toList();
    if (reasons.isEmpty) return null;
    return reasons.join('\n');
  }

  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, List<String>> _parseToMapStringList(dynamic jsonValue) {
    if (jsonValue is Map) {
      return jsonValue.map((key, value) {
        if (value is List) {
          return MapEntry(
              key.toString(), value.map((e) => e.toString()).toList());
        }
        return MapEntry(key.toString(), <String>[]);
      });
    }
    return {};
  }

  static List<String> _parseToListString(dynamic jsonValue) {
    if (jsonValue is List) {
      return List<String>.from(jsonValue.map((e) => e.toString()));
    }
    return [];
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final String imageBaseUrl =
        dotenv.env['API_BASE_IMAGE_URL'] ?? dotenv.env['API_BASE_URL'] ?? '';
    final wib = tz.getLocation('Asia/Jakarta');
    String buildFullUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) {
        return '';
      }

      final String sanitizedBaseUrl = imageBaseUrl.endsWith('/api')
          ? imageBaseUrl.substring(0, imageBaseUrl.length - 4)
          : imageBaseUrl;

      if (relativePath.startsWith('/')) {
        return '$sanitizedBaseUrl$relativePath';
      }
      return '$sanitizedBaseUrl/$relativePath';
    }

    DateTime? parseToWib(String? dateString) {
      if (dateString == null) return null;
      // 1. Parse string menjadi DateTime (masih dalam UTC)
      final utcDate = DateTime.parse(dateString);
      // 2. Konversi ke TZDateTime dengan zona waktu WIB
      return tz.TZDateTime.from(utcDate, wib);
    }

    List<String> buildFullUrlList(dynamic pathList) {
      if (pathList is! List) return [];
      return _parseToListString(pathList)
          .map((path) => buildFullUrl(path))
          .toList();
    }

    Map<String, List<String>> buildFullUrlMapNested(dynamic pathMap) {
      if (pathMap is! Map) return {};
      return pathMap.map(
          (key, value) => MapEntry(key.toString(), buildFullUrlList(value)));
    }

    Map<String, List<String>> buildFullUrlMap(dynamic pathMap) {
      if (pathMap is! Map) return {'initial': [], 'final': []};
      return {
        'initial': buildFullUrlList(pathMap['initial']),
        'final': buildFullUrlList(pathMap['final']),
      };
    }

    Map<String, List<String>> parseDeliveryLetterPath(dynamic jsonValue) {
      if (jsonValue is Map<String, dynamic>) {
        return {
          'initial_letters': jsonValue.containsKey('initial_letters')
              ? _parseToListString(jsonValue['initial_letters'])
              : [],
          'final_letters': jsonValue.containsKey('final_letters')
              ? _parseToListString(jsonValue['final_letters'])
              : [],
        };
      }
      return {'initial_letters': [], 'final_letters': []};
    }

    Map<String, dynamic> originData = {};
    if (json['origin'] is Map) {
      originData = json['origin'];
    } else if (json['origin'] is String) {
      originData['address'] = json['origin'];
    }

    Map<String, dynamic> destinationData = {};
    if (json['destination'] is Map) {
      destinationData = json['destination'];
    } else if (json['destination'] is String) {
      destinationData['address'] = json['destination'];
    }

    return Trip(
      id: _parseToInt(json['id']) ?? 0,
      userId: _parseToInt(json['user_id']),
      projectName: json['project_name'] ?? '',
      originAddress: originData['address'] ?? 'Alamat tidak tersedia',
      originLink: originData['link'] ?? '',
      destinationAddress: destinationData['address'] ?? 'Alamat tidak tersedia',
      destinationLink: destinationData['link'] ?? '',
      vehicleId: _parseToInt(json['vehicle_id']),
      slotTime: json['slot_time'],
      jenisBerat: json['jenis_berat'],
      startKm: _parseToInt(json['start_km']),
      endKm: _parseToInt(json['end_km']),
      statusTrip: json['status_trip'],
      jenisTrip: json['jenis_trip'],
      statusLokasi: json['status_lokasi'],
      statusMuatan: json['status_muatan'],
      createdAt: parseToWib(json['created_at']),
      updatedAt: parseToWib(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      jumlahGudangMuat: _parseToInt(json['jumlah_gudang_muat']),
      jumlahGudangBongkar: _parseToInt(json['jumlah_gudang_bongkar']),

      // Paths
      startKmPhotoPath: json['start_km_photo_path'],
      kmMuatPhotoPath: json['km_muat_photo_path'],
      kedatanganMuatPhotoPath: json['kedatangan_muat_photo_path'],
      deliveryOrderPath: json['delivery_order_photo_path'],
      muatPhotoPath: _parseToMapStringList(json['muat_photo_path']),
      deliveryLetterPath: parseDeliveryLetterPath(json['delivery_letter_path']),
      timbanganKendaraanPhotoPath: json['timbangan_kendaraan_photo_path'],
      segelPhotoPath: json['segel_photo_path'],
      endKmPhotoPath: json['end_km_photo_path'],
      kedatanganBongkarPhotoPath: json['kedatangan_bongkar_photo_path'],
      bongkarPhotoPath: _parseToMapStringList(json['bongkar_photo_path']),

      // Statuses
      startKmPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'start_km_photo'),
      kmMuatPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'km_muat_photo'),
      kedatanganMuatPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'kedatangan_muat_photo'),
      deliveryOrderStatus:
          PhotoVerificationStatus.fromJson(json, 'delivery_order_photo'),
      muatPhotoStatus: PhotoVerificationStatus.fromJson(json, 'muat_photo'),
      deliveryLetterInitialStatus:
          PhotoVerificationStatus.fromJson(json, 'delivery_letter_initial'),
      timbanganKendaraanPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'timbangan_kendaraan_photo'),
      segelPhotoStatus: PhotoVerificationStatus.fromJson(json, 'segel_photo'),
      endKmPhotoStatus: PhotoVerificationStatus.fromJson(json, 'end_km_photo'),
      kedatanganBongkarPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'kedatangan_bongkar_photo'),
      bongkarPhotoStatus:
          PhotoVerificationStatus.fromJson(json, 'bongkar_photo'),
      deliveryLetterFinalStatus:
          PhotoVerificationStatus.fromJson(json, 'delivery_letter_final'),

      // Full URLs
      fullStartKmPhotoUrl: buildFullUrl(json['full_start_km_photo_url']),
      fullKmMuatPhotoUrl: buildFullUrl(json['full_km_muat_photo_url']),
      fullKedatanganMuatPhotoUrl:
          buildFullUrl(json['full_kedatangan_muat_photo_url']),
      fullDeliveryOrderUrl: buildFullUrl(json['full_delivery_order_photo_url']),
      fullMuatPhotoUrls: buildFullUrlMapNested(json['full_muat_photo_urls']),
      fullDeliveryLetterUrls:
          buildFullUrlMap(json['full_delivery_letter_urls']),
      fullTimbanganKendaraanPhotoUrl:
          buildFullUrl(json['full_timbangan_kendaraan_photo_url']),
      fullSegelPhotoUrl: buildFullUrl(json['full_segel_photo_url']),
      fullEndKmPhotoUrl: buildFullUrl(json['full_end_km_photo_url']),
      fullKedatanganBongkarPhotoUrl:
          buildFullUrl(json['full_kedatangan_bongkar_photo_url']),
      fullBongkarPhotoUrls:
          buildFullUrlMapNested(json['full_bongkar_photo_urls']),
    );
  }
}
