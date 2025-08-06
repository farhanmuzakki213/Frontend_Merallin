import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Fungsi untuk meminta semua izin yang dibutuhkan untuk absensi
  Future<bool> requestAttendancePermissions() async {
    // Meminta izin kamera dan lokasi secara bersamaan
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse, // Minta izin lokasi saat aplikasi digunakan
    ].request();

    // Cek apakah kedua izin diberikan
    bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    bool locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    return cameraGranted && locationGranted;
  }
}
