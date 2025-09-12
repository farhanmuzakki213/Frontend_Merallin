// lib/widgets/in_app_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:frontend_merallin/bbm_progress_screen.dart';
import 'package:frontend_merallin/models/bbm_model.dart';
import 'package:frontend_merallin/models/vehicle_model.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/bbm_provider.dart';
import 'package:frontend_merallin/utils/image_absen_helper.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

// ===== WIDGET NOTIFIKASI (TETAP SAMA) =====
class AttendanceNotificationBanner extends StatelessWidget {
  const AttendanceNotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final now = DateTime.now();

    final bool shouldShow = !attendanceProvider.hasClockedIn &&
        now.weekday >= DateTime.monday &&
        now.weekday <= DateTime.friday &&
        now.hour >= 7;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return SizeTransition(sizeFactor: animation, child: child);
      },
      child: shouldShow
          ? Container(
              key: const ValueKey('notification-banner'),
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.shade700,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Anda belum ambil absen hari ini!",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty-banner')),
    );
  }
}

// ===== WIDGET MENU MENGAMBANG YANG BISA DIGESER (DraggableSpeedDial) =====

class DraggableSpeedDial extends StatefulWidget {
  final bool showBbmOption;
  final Vehicle? currentVehicle;

  const DraggableSpeedDial({
    super.key,
    this.showBbmOption = true,
    this.currentVehicle,
  });

  @override
  State<DraggableSpeedDial> createState() => _DraggableSpeedDialState();
}

class _DraggableSpeedDialState extends State<DraggableSpeedDial> {
  Offset _position = const Offset(20, 100);
  final GlobalKey _fabKey = GlobalKey();
  Size _fabSize = const Size(56, 56);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_fabKey.currentContext != null) {
        setState(() {
          _fabSize = _fabKey.currentContext!.size!;
        });
      }
    });
  }

  Future<void> _handleAttendance(BuildContext context) async {
    final attendanceProvider = context.read<AttendanceProvider>();

    if (attendanceProvider.hasClockedIn) {
      showInfoSnackBar(context, 'Anda sudah absen hari ini.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;
    final imageResult = await ImageHelper.takePhotoWithLocation(context);
    // Tambahkan pengecekan mounted setelah async gap
    if (!context.mounted || imageResult?.position == null) return;

    await attendanceProvider.performClockInWithLocation(
        context: context,
        image: imageResult!.file,
        token: authProvider.token!,
        position: imageResult.position!);
  }

  Future<void> _handleBbm(BuildContext context) async {
    final bbmProvider = context.read<BbmProvider>();
    final authProvider = context.read<AuthProvider>();

    final bool hasOngoing = bbmProvider.bbmRequests
        .any((bbm) => bbm.derivedStatus != BbmStatus.selesai);
    if (hasOngoing) {
      showInfoSnackBar(context,
          'Tidak bisa membuat permintaan baru. Masih ada proses BBM yang sedang berjalan.');
      return;
    }

    if (widget.currentVehicle == null) {
      showErrorSnackBar(context,
          'Data kendaraan tidak ditemukan untuk membuat permintaan BBM.');
      return;
    }

    showInfoSnackBar(context,
        'Membuat permintaan BBM untuk ${widget.currentVehicle!.licensePlate}...');
    final newRequest = await bbmProvider.createBbmRequest(
        context: context,
        token: authProvider.token!,
        vehicleId: widget.currentVehicle!.id);

    if (!context.mounted || newRequest == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BbmProgressScreen(bbmId: newRequest.id),
      ),
    );

    if (context.mounted) {
      await bbmProvider.fetchBbmRequests(
        context: context,
        token: authProvider.token!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaPadding = MediaQuery.of(context).padding;

    // Tentukan apakah FAB berada di sisi kiri atau kanan layar
    final bool isLeftHalf = _position.dx < (screenSize.width / 2 - _fabSize.width / 2);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newX = _position.dx + details.delta.dx;
            double newY = _position.dy + details.delta.dy;

            newX = newX.clamp(0, screenSize.width - _fabSize.width);
            newY = newY.clamp(safeAreaPadding.top,
                screenSize.height - _fabSize.height - safeAreaPadding.bottom);

            _position = Offset(newX, newY);
          });
        },
        child: SpeedDial(
          key: _fabKey,
          icon: Icons.menu,
          activeIcon: Icons.close,
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          overlayColor: Colors.black,
          overlayOpacity: 0.5,
          spacing: 10,
          spaceBetweenChildren: 8,
          
          // Nama properti untuk kecepatan animasi mungkin 'animatedIconTheme' atau serupa,
          // atau bisa dihilangkan jika tidak terlalu penting.
          // Untuk amannya, kita hilangkan dulu.
          
          direction: _position.dy < screenSize.height / 2
              ? SpeedDialDirection.down
              : SpeedDialDirection.up,
              
          // ===== PERBAIKAN UTAMA DI SINI =====
          // Daripada menggunakan properti yang tidak ada, kita bungkus labelnya
          // dengan widget di dalam `SpeedDialChild` itu sendiri.
          children: [
            _buildSpeedDialChild(
              context: context,
              isLeftHalf: isLeftHalf,
              onTap: () => _handleAttendance(context),
              label: 'Absen',
              icon: Icons.work_outline,
              backgroundColor: Colors.blue,
            ),
            if (widget.showBbmOption)
              _buildSpeedDialChild(
                context: context,
                isLeftHalf: isLeftHalf,
                onTap: () => _handleBbm(context),
                label: 'Isi BBM',
                icon: Icons.local_gas_station,
                backgroundColor: Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  // BUAT FUNGSI HELPER UNTUK MEMBANGUN SpeedDialChild DENGAN LOGIKA BARU
  SpeedDialChild _buildSpeedDialChild({
    required BuildContext context,
    required bool isLeftHalf,
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    required Color backgroundColor,
  }) {
    // Tentukan widget label dengan gaya dan posisi
    final labelWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      margin: const EdgeInsets.only(right: 18), // Memberi jarak dari tombol utama
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return SpeedDialChild(
      child: Icon(icon),
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      onTap: onTap,
      
      // Properti 'labelWidget' biasanya tersedia
      labelWidget: labelWidget,

      // Atur 'label' menjadi string kosong agar tidak tumpang tindih
      label: '', 
      
      // Atur 'labelStyle' menjadi null
      labelStyle: null,
      
      // 'labelBackgroundColor' juga tidak diperlukan lagi
      labelBackgroundColor: null,
    );
  }
}