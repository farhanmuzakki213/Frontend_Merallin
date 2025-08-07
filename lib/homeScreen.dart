import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend_merallin/services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PermissionService _permissionService = PermissionService(); 

  void _onItemTapped(int index) {
    if (index == 3) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Apakah Anda yakin ingin keluar?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child:
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _startAttendance() async {
    final bool permissionsGranted = await _permissionService.requestAttendancePermissions();
    if (!permissionsGranted && mounted) {
      showErrorSnackBar(context, 'Izin kamera dan lokasi dibutuhkan untuk absensi.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.token == null) {
      showErrorSnackBar(context, "Sesi tidak valid, silakan login ulang.");
      return;
    }

    final XFile? imageFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );

    if (imageFile == null) return;

    await attendanceProvider.clockIn(File(imageFile.path), authProvider.token!);

    if (mounted) {
      final status = attendanceProvider.status;
      final message = attendanceProvider.message ?? "Terjadi kesalahan";
      if (status == AttendanceStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else if (status == AttendanceStatus.error) {
        showErrorSnackBar(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceStatus = context.watch<AttendanceProvider>().status;
    final user = context.watch<AuthProvider>().user;
    final String? userRole = user?.roles.isNotEmpty ?? false ? user!.roles.first : null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(user?.name ?? 'User'),
              _buildTimeCard(),
              _buildMenuGrid(userRole),
              const SizedBox(height: 20),
              _buildAttendanceButton(attendanceStatus),
            ],
          ),
        ),
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
            '09:41 WIB',
            style: TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Rabu, 6 Agustus 2025',
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

  Widget _buildMenuGrid(String? role) {
    if (role == 'driver') {
      return _buildDriverMenuGrid();
    }
    return _buildEmployeeMenuGrid();
  }

  Widget _buildEmployeeMenuGrid() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          AnimatedMenuItem(icon: Icons.work_outline, label: 'Datang', onTap: () {}),
          AnimatedMenuItem(icon: Icons.home_work_outlined, label: 'Pulang', onTap: () {}),
          AnimatedMenuItem(icon: Icons.calendar_today_outlined, label: 'Jadwal', onTap: () {}),
          AnimatedMenuItem(icon: Icons.note_alt_outlined, label: 'Izin', onTap: () {}),
          AnimatedMenuItem(icon: Icons.timer_outlined, label: 'Lembur', onTap: () {}),
          AnimatedMenuItem(icon: Icons.description_outlined, label: 'Catatan', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildDriverMenuGrid() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: 2, // Hanya 2 item, jadi 2 kolom lebih baik
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          AnimatedMenuItem(icon: Icons.local_shipping_outlined, label: 'Mulai Trip', onTap: () {}),
          AnimatedMenuItem(icon: Icons.flag_outlined, label: 'Selesai Trip', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton(AttendanceStatus attendanceStatus) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: Colors.blue[300],
        ),
        onPressed: attendanceStatus == AttendanceStatus.processing ? null : _startAttendance,
        child: attendanceStatus == AttendanceStatus.processing
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_retouching_natural, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Attendance Using Face ID',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
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
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  _AnimatedMenuItemState createState() => _AnimatedMenuItemState();
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
