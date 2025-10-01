// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // PERUBAHAN: Jadikan plugin nullable dan inisialisasi nanti
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  Future<void> initialize() async {
    // Jika sudah ada instance, berarti sudah diinisialisasi
    if (_notificationsPlugin != null) return;

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin!.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          OpenFilex.open(payload);
        }
      },
    );
    //  debugPrint('NotificationService Initialized');
  }

  Future<void> showDownloadCompleteNotification({
    required String filePath,
    required String fileName,
  }) async {
    // "Penjaga" utama: Jika plugin belum siap, inisialisasi dulu
    if (_notificationsPlugin == null) {
      await initialize();
    }
    
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download Selesai',
      channelDescription: 'Notifikasi saat file berhasil diunduh.',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        'File Anda "$fileName" telah berhasil diunduh. Ketuk untuk membuka.',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin!.show(
        DateTime.now().millisecond,
        'Download Selesai',
        'Ketuk untuk membuka "$fileName"',
        notificationDetails,
        payload: filePath,
      );
    } catch (e) {
      // Menambahkan log jika terjadi error saat menampilkan notifikasi
      // debugPrint('Error showing notification: $e');
    }
  }
}