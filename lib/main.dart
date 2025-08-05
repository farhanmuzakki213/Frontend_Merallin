import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend_merallin/homeScreen.dart';
import 'package:frontend_merallin/login_screen.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  final encryptionKey = base64Url.decode(dotenv.env['HIVE_ENCRYPTION_KEY']!);
  await Hive.openBox(
    'authBox',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // AuthProvider akan langsung dipanggil di sini
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'Absensi App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Poppins',
        ),
        debugShowCheckedModeBanner: false,
        // Ganti home dengan Consumer yang akan menjadi gerbang utama
        home: const AuthGate(),
      ),
    );
  }
}

// Widget ini akan menjadi penentu halaman mana yang ditampilkan
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.authStatus) {
          case AuthStatus.uninitialized:
            // Loading awal saat buka aplikasi tetap di sini
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
