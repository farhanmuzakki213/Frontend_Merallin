// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  // Buat instance dari plugin notifikasi
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Fungsi untuk inisialisasi
  static Future<void> initialize() async {
    // Pengaturan untuk Android
    // 'ic_notification' adalah nama file ikon yang Anda siapkan di Langkah 2
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    // Pengaturan untuk iOS (tidak memerlukan ikon khusus di sini)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inisialisasi plugin dengan pengaturan di atas
    await _notificationsPlugin.initialize(
      settings,
      // Aksi yang dijalankan saat notifikasi ditekan
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
          // Buka file menggunakan path yang dikirim melalui payload
          await OpenFilex.open(response.payload!);
        }
      },
    );
  }

  // Fungsi untuk menampilkan notifikasi setelah download selesai
  static Future<void> showDownloadCompleteNotification({
    required String filePath,
    required String fileName,
  }) async {
    // Detail notifikasi untuk Android
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel', // ID channel
      'Downloads', // Nama channel
      channelDescription: 'Notifikasi untuk download yang telah selesai.',
      importance: Importance.max,
      priority: Priority.high,
    );

    // Detail notifikasi untuk iOS
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Tampilkan notifikasi
    await _notificationsPlugin.show(
      0, // ID notifikasi
      'Download Selesai', // Judul notifikasi
      fileName, // Isi notifikasi
      notificationDetails,
      payload: filePath, // Data yang dikirim saat notifikasi ditekan (path file)
    );
  }
}