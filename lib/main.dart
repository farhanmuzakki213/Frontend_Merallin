// lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/home_screen.dart'; 
import 'package:frontend_merallin/login_screen.dart';
import 'package:frontend_merallin/models/trip_model.dart';
import 'package:frontend_merallin/models/user_model.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/trip_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:frontend_merallin/providers/history_provider.dart';
import 'package:frontend_merallin/providers/leave_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  
  Hive.registerAdapter(UserAdapter());
  // Hive.registerAdapter(PhotoVerificationStatusAdapter());
  // Hive.registerAdapter(TripAdapter());

  final encryptionKeyString = dotenv.env['HIVE_ENCRYPTION_KEY'];
  if (encryptionKeyString == null) {
    throw Exception("HIVE_ENCRYPTION_KEY tidak ditemukan di file .env");
  }
  final encryptionKey = base64Url.decode(encryptionKeyString);

  await Hive.openBox(
    'authBox',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  // await Hive.openBox<Trip>('tripsBox', encryptionCipher: HiveAesCipher(encryptionKey));
  // await Hive.openBox('performanceBox', encryptionCipher: HiveAesCipher(encryptionKey));
  // await Hive.openBox('historyBox', encryptionCipher: HiveAesCipher(encryptionKey));

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
      ],
      child: MaterialApp(
        title: 'Absensi App',
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.authStatus) {
          case AuthStatus.uninitialized:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.updating:
          case AuthStatus.authenticated:            
            return const HomeScreen(); // Selalu arahkan ke HomeScreen
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}