// lib/models/attendance_history_model.dart

class AttendanceHistory {
  final int id;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const AttendanceHistory({
    required this.id,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  /// Factory constructor untuk membuat instance AttendanceHistory dari data JSON.
  /// Ini akan dipanggil di dalam ApiService Anda.
  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    return AttendanceHistory(
      id: json['id'],
      photoUrl: json['photo_url'],
      // Menggunakan `tryParse` untuk keamanan jika data dari API bukan angka.
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
      // Mengubah format string waktu dari API menjadi objek DateTime.
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}