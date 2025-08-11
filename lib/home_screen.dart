// lib/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/profile_screen.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/services/permission_service.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend_merallin/my_trip_screen.dart';
import 'package:frontend_merallin/history_screen.dart';

import 'driver_history_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final String? userRole = user?.roles.isNotEmpty ?? false ? user!.roles.first : null;

    // FIX: Buat widget history secara dinamis berdasarkan role
    Widget historyScreen;
    // FIX: Gunakan '==' untuk perbandingan, bukan '='
    if (userRole == 'driver') {
      historyScreen = const DriverHistoryScreen(); // Ganti dengan halaman riwayat driver Anda
    } else {
      // Default untuk 'karyawan' atau role lainnya
      historyScreen = const HistoryScreen();
    }
    final List<Widget> widgetOptions = [
      const HomeScreenContent(),
      historyScreen, // Masukkan halaman riwayat yang sudah ditentukan
      const PlaceholderScreen(title: 'Pengaturan'),
      const ProfilePage(),
    ];
    return Scaffold(
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  final PermissionService _permissionService = PermissionService();

  Future<void> _startAttendance(BuildContext context, String type) async {
    final bool permissionsGranted = await _permissionService.requestAttendancePermissions();
    if (!mounted) return;

    if (!permissionsGranted) {
      showErrorSnackBar(context, 'Izin kamera dan lokasi dibutuhkan untuk absensi.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.token == null) {
      showErrorSnackBar(context, "Sesi tidak valid, silakan login ulang.");
      return;
    }

    final imageFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (imageFile == null) return;
    if (!mounted) return;

    if (type == 'in') {
      await attendanceProvider.clockIn(
          File(imageFile.path), authProvider.token!);
    } else {
      await attendanceProvider.clockOut(
          File(imageFile.path), authProvider.token!);
    }

    if (mounted) {
      final status = attendanceProvider.status;
      final message = attendanceProvider.message ?? "Terjadi kesalahan";

      if (status == AttendanceStatus.success) {
        showInfoSnackBar(context, message);
      } else if (status == AttendanceStatus.error) {
        showErrorSnackBar(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = context.watch<AuthProvider>().user;
    final String? userRole = user?.roles.isNotEmpty ?? false ? user!.roles.first : null;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(user?.name ?? 'User'),
            _buildTimeCard(),
            _buildMenuGrid(context, userRole, attendanceProvider),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context, String? role,
      AttendanceProvider attendanceProvider) {
    if (role == 'driver') {
      return _buildDriverMenuGrid();
    }
    return _buildEmployeeMenuGrid(context, attendanceProvider);
  }

  Widget _buildEmployeeMenuGrid(
      BuildContext context, AttendanceProvider attendanceProvider) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          AnimatedMenuItem(
            icon: Icons.work_outline,
            label: 'Datang',
            onTap: () {
              if (attendanceProvider.status == AttendanceStatus.processing)
                return;

              // Logika Waktu untuk Absen Datang (07:00 - 23:59)
              final now = DateTime.now();
              final startTime =
                  DateTime(now.year, now.month, now.day, 7, 0); // 07:00
              final endTime = DateTime(
                  now.year, now.month, now.day, 23, 59); // 23:59 (Tengah Malam)

              if (now.isBefore(startTime)) {
                showInfoSnackBar(
                    context, 'Belum waktunya absen (mulai 07:00).');
                return;
              }
              if (now.isAfter(endTime)) {
                showInfoSnackBar(
                    context, 'Waktu absen untuk hari ini sudah habis.');
                return;
              }

              if (attendanceProvider.hasClockedIn) {
                showInfoSnackBar(context, 'Anda sudah absen datang hari ini.');
              } else {
                _startAttendance(context, 'in');
              }
            },
          ),
          AnimatedMenuItem(
            icon: Icons.home_work_outlined,
            label: 'Pulang',
            onTap: () {
              if (attendanceProvider.status == AttendanceStatus.processing)
                return;

              final now = DateTime.now();
              final startTime =
                  DateTime(now.year, now.month, now.day, 17, 0); // 17:00
              final endTime =
                  DateTime(now.year, now.month, now.day, 23, 59); // 23:59

              if (now.isBefore(startTime)) {
                showInfoSnackBar(context, 'Belum waktunya absen pulang.');
                return;
              }
              if (now.isAfter(endTime)) {
                showInfoSnackBar(context, 'Waktu absen pulang sudah habis.');
                return;
              }

              if (!attendanceProvider.hasClockedIn) {
                showErrorSnackBar(
                    context, 'Anda harus absen datang terlebih dahulu.');
              } else if (attendanceProvider.hasClockedOut) {
                showInfoSnackBar(context, 'Anda sudah absen pulang hari ini.');
              } else {
                _startAttendance(context, 'out');
              }
            },
          ),
          AnimatedMenuItem(
              icon: Icons.calendar_today_outlined,
              label: 'Jadwal',
              onTap: () {}),
          AnimatedMenuItem(
              icon: Icons.note_alt_outlined, label: 'Izin', onTap: () {}),
          AnimatedMenuItem(
              icon: Icons.timer_outlined, label: 'Lembur', onTap: () {}),
          AnimatedMenuItem(
              icon: Icons.description_outlined, label: 'Catatan', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildDriverMenuGrid() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          AnimatedMenuItem(
              icon: Icons.local_shipping_outlined,
              label: 'Mulai Trip',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyTripScreen()),
                );
              }),
          AnimatedMenuItem(
              icon: Icons.flag_outlined, label: 'Selesai Trip', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=56'),
          ),
          const SizedBox(width: 12),
          Text(
            'Hello, $userName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 30),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.blue[600],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '16:50 WIB', // Ganti dengan data waktu live
            style: TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Kamis, 7 Agustus 2025', // Ganti dengan data tanggal live
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 20),
          Divider(color: Colors.white54),
          SizedBox(height: 10),
          Text(
            'Jadwal Anda Hari Ini',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            '08:00 WIB - 16:00 WIB',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue[700],
      ),
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}

class AnimatedMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const AnimatedMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<AnimatedMenuItem> createState() => _AnimatedMenuItemState();
}

class _AnimatedMenuItemState extends State<AnimatedMenuItem> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 1.15 : 1.0;
    final backgroundColor = _isPressed ? Colors.blue[700]! : Colors.white;
    final contentColor = _isPressed ? Colors.white : Colors.blue[700]!;
    final textColor = _isPressed ? Colors.white : Colors.black87;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(15.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 30, color: contentColor),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: _isPressed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}