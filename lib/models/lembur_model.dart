class LemburRequest {
  // Data Awal Pengajuan
  final String id;
  final String tanggal;
  final String jamMulai; // Rencana Jam Mulai
  final String jamSelesai; // Rencana Jam Selesai
  final String durasi; // Rencana Durasi
  final String pekerjaan;
  String status;

  // Data Realisasi (setelah Clock-in & Clock-out)
  final DateTime? waktuMulaiAsli;
  final double? latMulai;
  final double? lonMulai;
  final String? fotoMulaiUrl;

  final DateTime? waktuSelesaiAsli;
  final double? latSelesai;
  final double? lonSelesai;
  final String? fotoSelesaiUrl;

  LemburRequest({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.durasi,
    required this.pekerjaan,
    required this.status,
    // Jadikan field realisasi opsional
    this.waktuMulaiAsli,
    this.latMulai,
    this.lonMulai,
    this.fotoMulaiUrl,
    this.waktuSelesaiAsli,
    this.latSelesai,
    this.lonSelesai,
    this.fotoSelesaiUrl,
  });

  // Factory constructor untuk membuat instance LemburRequest dari JSON
  // Ini akan sangat membantu saat integrasi dengan API Laravel
  factory LemburRequest.fromJson(Map<String, dynamic> json) {
    // Fungsi bantu untuk parsing double yang aman
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return LemburRequest(
      id: json['id'].toString(),
      tanggal: json['tanggal'] ?? '',
      jamMulai: json['jam_mulai'] ?? '',
      jamSelesai: json['jam_selesai'] ?? '',
      durasi: json['durasi'] ?? '',
      pekerjaan: json['pekerjaan'] ?? '',
      status: json['status'] ?? 'Pending',
      waktuMulaiAsli: json['waktu_mulai_asli'] != null
          ? DateTime.tryParse(json['waktu_mulai_asli'])
          : null,
      latMulai: parseDouble(json['lat_mulai']),
      lonMulai: parseDouble(json['lon_mulai']),
      fotoMulaiUrl: json['foto_mulai_url'],
      waktuSelesaiAsli: json['waktu_selesai_asli'] != null
          ? DateTime.tryParse(json['waktu_selesai_asli'])
          : null,
      latSelesai: parseDouble(json['lat_selesai']),
      lonSelesai: parseDouble(json['lon_selesai']),
      fotoSelesaiUrl: json['foto_selesai_url'],
    );
  }
}
