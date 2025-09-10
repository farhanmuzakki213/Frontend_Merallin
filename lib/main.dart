// lib/main.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/payslip_provider.dart'; //LIST GAJI
import 'package:frontend_merallin/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart'; // <-- Impor Firebase Core
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- Impor Firebase Messaging
// ===== MULAI KODE TAMBAHAN =====
// Impor file permission_service.dart yang sudah kita modifikasi
import 'package:frontend_merallin/services/navigation_service.dart';
import 'package:frontend_merallin/services/permission_service.dart';
// ===== AKHIR KODE TAMBAHAN =====
import 'package:frontend_merallin/home_screen.dart';
import 'package:frontend_merallin/login_screen.dart';
import 'package:frontend_merallin/models/user_model.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/bbm_provider.dart';
import 'package:frontend_merallin/providers/trip_provider.dart';
import 'package:frontend_merallin/providers/vehicle_location_provider.dart';
import 'package:frontend_merallin/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:frontend_merallin/providers/history_provider.dart';
import 'package:frontend_merallin/providers/leave_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:frontend_merallin/providers/id_card_provider.dart';


// ===== MULAI KODE TAMBAHAN: Handler untuk notifikasi di background =====
// =======================================================================
/// Fungsi ini harus berada di level atas (top-level), di luar kelas manapun.
/// Fungsinya untuk menangani notifikasi saat aplikasi tidak berjalan di foreground.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi
  await Firebase.initializeApp();

  // Cek apakah notifikasi berisi perintah untuk logout paksa
  if (message.data['type'] == 'force_logout') {
    debugPrint("Force logout message received in background. Clearing auth box.");
    // Buka authBox yang terenkripsi
    final encryptionKeyString = dotenv.env['HIVE_ENCRYPTION_KEY'];
    if (encryptionKeyString != null) {
      final encryptionKey = base64Url.decode(encryptionKeyString);
      final authBox = await Hive.openBox(
        'authBox',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      // Hapus semua data sesi
      await authBox.clear();
      debugPrint("Auth box cleared due to background force logout.");
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  // ===== MULAI KODE TAMBAHAN =====
  // Mendaftarkan background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // ===== AKHIR KODE TAMBAHAN =====
  await initializeDateFormatting('id_ID', null);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  Hive.registerAdapter(UserAdapter());

  final encryptionKeyString = dotenv.env['HIVE_ENCRYPTION_KEY'];
  if (encryptionKeyString == null) {
    throw Exception("HIVE_ENCRYPTION_KEY tidak ditemukan di file .env");
  }
  final encryptionKey = base64Url.decode(encryptionKeyString);

  await Hive.openBox(
    'authBox',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
  
  await Hive.openBox<int>('downloadedSlipsBox');
  await Hive.openBox<bool>('idCardStatusBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => AttendanceProvider()),
        ChangeNotifierProvider(create: (context) => LeaveProvider()),
        ChangeNotifierProvider(create: (context) => TripProvider()),
        ChangeNotifierProvider(create: (context) => HistoryProvider()),
        ChangeNotifierProvider(create: (context) => BbmProvider()),
        ChangeNotifierProvider(create: (context) => VehicleLocationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PayslipProvider>(
          create: (context) => PayslipProvider(),
          update: (context, auth, payslip) {
            payslip!.updateToken(auth.token);
            return payslip;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, DashboardProvider>(
          create: (context) => DashboardProvider(),
          update: (context, auth, dashboard) {
            // ===== PERUBAHAN DI SINI =====
            // Kirim context saat mengupdate token agar bisa digunakan untuk fetch data
            dashboard!.updateToken(auth.token, context);
            return dashboard;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, IdCardProvider>(
          create: (context) => IdCardProvider(),
          update: (context, auth, idCard) {
            idCard!.updateToken(auth.token);
            return idCard;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        title: 'Merallin Group',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Poppins',
        ),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', ''),
          Locale('en', ''),
        ],
        locale: const Locale('id', 'ID'),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFirebaseMessagingListener();
    });
  }

  void _setupFirebaseMessagingListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.data}');
      if (message.data['type'] == 'force_logout') {
        Provider.of<AuthProvider>(context, listen: false)
            .handleInvalidSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // AuthGate sekarang sangat sederhana, hanya menukar layar berdasarkan status.
    // Tidak ada lagi logika timer di sini.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.authStatus) {
          case AuthStatus.uninitialized:
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          case AuthStatus.updating:
          case AuthStatus.authenticated:
            return const PermissionGate(
              child: HomeScreen(),
            );
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}