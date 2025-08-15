// lib/home_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// FIX: Mengubah 'package.' menjadi 'package:'
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:frontend_merallin/profile_screen.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/services/permission_service.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'package:frontend_merallin/my_trip_screen.dart';
import 'package:frontend_merallin/history_screen.dart';
import 'package:frontend_merallin/leave_request_screen.dart';
import 'driver_history_screen.dart';
import 'lembur_screen.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
    final String? userRole =
        user?.roles.isNotEmpty ?? false ? user!.roles.first : null;

    Widget historyScreen;
    if (userRole == 'driver') {
      historyScreen = const DriverHistoryScreen();
    } else {
      historyScreen = const HistoryScreen();
    }
    final List<Widget> widgetOptions = [
      const HomeScreenContent(),
      historyScreen,
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

  @override
  void initState() {
    super.initState();
    // Panggil fungsi untuk cek status saat widget pertama kali dibuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<AttendanceProvider>(context, listen: false)
            .checkTodayAttendanceStatus(authProvider.token!);
      }
    });
  }

  Future<File?> _compressImage(File file) async {
    // Tentukan path untuk menyimpan file hasil kompresi
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    // Kompres file
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Kualitas gambar (0-100), 70 sudah cukup bagus
      minWidth: 1024, // Perkecil lebar gambar jika terlalu besar
      minHeight: 1024, // Perkecil tinggi gambar jika terlalu besar
    );

    if (result == null) return null;

    // Ubah XFile menjadi File
    return File(result.path);
  }

  Future<void> _startAttendance(BuildContext context, String type) async {
    final bool permissionsGranted =
        await _permissionService.requestAttendancePermissions();
    if (!mounted) return;

    if (!permissionsGranted) {
      showErrorSnackBar(context, 'Izin kamera dan lokasi dibutuhkan.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Sedang memproses..."),
              ],
            ),
          ),
        );
      },
    );
    try {
      // Jalankan proses kompresi gambar
      final compressedImageFile = await _compressImage(File(imageFile.path));

      if (compressedImageFile == null) {
        throw Exception("Gagal memproses gambar.");
      }

      // Jalankan proses unggah dan absensi
      if (type == 'in') {
        await attendanceProvider.performClockIn(
            compressedImageFile, authProvider.token!);
      } else {
        await attendanceProvider.performClockOut(
            compressedImageFile, authProvider.token!);
      }

      // Ambil status dan pesan dari provider setelah selesai
      final status = attendanceProvider.status;
      final message = attendanceProvider.message ?? "Terjadi kesalahan";

      // Tutup dialog loading
      Navigator.of(context).pop();

      // Tampilkan hasil akhir ke pengguna
      if (status == AttendanceProcessStatus.success) {
        showInfoSnackBar(context, message);
      } else if (status == AttendanceProcessStatus.error) {
        showErrorSnackBar(context, message);
      }
    } catch (e) {
      // Jika terjadi error di tengah jalan (misal kompresi gagal)
      Navigator.of(context).pop(); // Pastikan dialog loading ditutup
      showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = context.watch<AuthProvider>().user;
    final String? userRole =
        user?.roles.isNotEmpty ?? false ? user!.roles.first : null;

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
              if (attendanceProvider.status ==
                  AttendanceProcessStatus.processing) {
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
              if (attendanceProvider.status ==
                  AttendanceProcessStatus.processing) {
                return;
              }
              final now = DateTime.now();
              final clockOutTime =
                  DateTime(now.year, now.month, now.day, 17, 0);
              if (!attendanceProvider.hasClockedIn) {
                showErrorSnackBar(context, 'Anda harus absen datang dahulu.');
              } else if (now.isBefore(clockOutTime)) {
                showInfoSnackBar(
                    context, 'Belum waktunya absen pulang (setelah 17:00).');
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
              icon: Icons.note_alt_outlined,
              label: 'Izin',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LeaveRequestScreen()),
                );
              }),
          AnimatedMenuItem(
              icon: Icons.timer_outlined, label: 'Lembur', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LemburScreen()),
                );
              }),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Selamat datang kembali!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 20, 171, 247),
            Color.fromARGB(74, 19, 171, 247),
          ],
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final timeString = DateFormat('HH:mm:ss').format(now);
            final dateString =
                DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timeString, // Data waktu live
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  dateString, // Data tanggal live
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white54),
                const SizedBox(height: 10),
                const Text(
                  'Jadwal Anda Hari Ini',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '08:00 WIB - 17:00 WIB',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
              ],
            );
          }),
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
        title: Text(title, style: const TextStyle(color: Colors.white)),
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
