import 'package:flutter/material.dart';

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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildTimeCard(),
              _buildMenuGrid(),
              const SizedBox(height: 20),
              _buildAttendanceButton(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=hera'),
          ),
          const SizedBox(width: 12),
          const Text(
            'Hello, Hera',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            'Sabtu, 2 Maret 2024',
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

  // PERUBAHAN: Menggunakan widget baru `AnimatedMenuItem`
  Widget _buildMenuGrid() {
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
              icon: Icons.work_outline, label: 'Datang', onTap: () {}),
          AnimatedMenuItem(
              icon: Icons.home_work_outlined, label: 'Pulang', onTap: () {}),
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

  Widget _buildAttendanceButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {},
        child: const Row(
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

// WIDGET BARU: Widget untuk item menu dengan animasi
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

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 1.15 : 1.0;

    // Tentukan warna berdasarkan state _isPressed
    final Color backgroundColor = _isPressed ? Colors.blue[700]! : Colors.white;
    final Color contentColor = _isPressed ? Colors.white : Colors.blue[700]!;
    final Color textColor = _isPressed ? Colors.white : Colors.black87;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        // Ganti Card dengan AnimatedContainer untuk animasi warna
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
                  color: textColor, // Gunakan warna teks yang sudah ditentukan
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
