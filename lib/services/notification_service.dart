// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  // Buat instance dari plugin notifikasi
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Fungsi untuk inisialisasi
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
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