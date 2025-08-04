import 'package:flutter/material.dart';
import 'package:frontend_merallin/homeScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins', // Anda bisa menggunakan font lain jika mau
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
