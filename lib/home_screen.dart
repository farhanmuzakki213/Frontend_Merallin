// lib/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/id_card_screen.dart';
import 'package:frontend_merallin/bbm_list_screen.dart';
import 'package:frontend_merallin/bbm_progress_screen.dart';
import 'package:frontend_merallin/laporan_perjalanan_screen.dart';
import 'package:frontend_merallin/providers/trip_provider.dart';
import 'package:frontend_merallin/utils/image_absen_helper.dart';
import 'package:frontend_merallin/vehicle_location_list_screen.dart';
import 'package:frontend_merallin/vehicle_location_progress_screen.dart';
import 'package:intl/intl.dart';
import 'package:frontend_merallin/providers/dashboard_provider.dart';
import 'package:frontend_merallin/profile_screen.dart';
import 'package:frontend_merallin/providers/attendance_provider.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'package:frontend_merallin/my_trip_screen.dart';
import 'package:frontend_merallin/history_screen.dart';
import 'package:frontend_merallin/leave_request_screen.dart';
import 'package:frontend_merallin/payslip_list_screen.dart';
import 'driver_history_screen.dart';
import 'lembur_screen.dart';

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

    String? userRole;
    if (user != null && user.roles.isNotEmpty) {
      userRole = user.roles.first;
    }

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingTasks();
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      Provider.of<AttendanceProvider>(context, listen: false)
          .checkTodayAttendanceStatus(
              context: context, token: authProvider.token!);

      // DashboardProvider dipanggil lewat ProxyProvider di main.dart,
      // tapi kita bisa panggil lagi di sini untuk memastikan refresh.
      Provider.of<DashboardProvider>(context, listen: false)
          .fetchDashboardData(context: context);

      if (authProvider.user?.roles.contains('driver') ?? false) {
        Provider.of<TripProvider>(context, listen: false)
            .fetchTrips(context: context, token: authProvider.token!);
      }
    }
  }

  Future<void> _checkPendingTasks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);


    if (authProvider.pendingBbmId != null) {
      final bbmId = authProvider.pendingBbmId!;
      final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            BbmProgressScreen(bbmId: bbmId, resumeVerification: true),
      ));
      if (result == true) {
        await authProvider.clearPendingBbmForVerification();
      }
    } else if (authProvider.pendingTripId != null) {
      final tripId = authProvider.pendingTripId!;
      final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LaporanDriverScreen(
          tripId: tripId,
          resumeVerification: true,
        ),
      ));

      if (result == true) {
        await authProvider.clearPendingTripForVerification();
      }
    } else if (authProvider.pendingVehicleLocationId != null) {
      final locationId = authProvider.pendingVehicleLocationId!;
      final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VehicleLocationProgressScreen(
          locationId: locationId,
          resumeVerification: true,
        ),
      ));
      if (result == true) {
        await authProvider.clearPendingVehicleLocationForVerification();
      }
    }
  }

  Future<void> _startStampedClockIn(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);

    if (authProvider.token == null) {
      showErrorSnackBar(context, "Sesi tidak valid, silakan login ulang.");
      return;
    }

    final imageResult = await ImageHelper.takePhotoWithLocation(context);

    if (imageResult == null || !mounted) return;

    if (imageResult.position == null) {
      showErrorSnackBar(
          context, "Gagal mendapatkan data lokasi. Mohon coba lagi.");
      return;
    }

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
    await attendanceProvider.performClockInWithLocation(
        context: context,
        image: imageResult.file,
        token: authProvider.token!,
        position: imageResult.position!);

  } catch (e) {
    debugPrint("Terjadi error tak terduga: $e");
  } finally {
    
    if (mounted) {
      final status = attendanceProvider.status;
      final message = attendanceProvider.message;

      if (status == AttendanceProcessStatus.success) {
        await dashboardProvider.fetchDashboardData(context: context);
      }

      Navigator.of(context).pop();

      if (status == AttendanceProcessStatus.success) {
        showInfoSnackBar(context, message ?? 'Absen berhasil direkam!');
      } else if (status == AttendanceProcessStatus.error) {
        showErrorSnackBar(context, message ?? 'Terjadi kesalahan saat absen.');
      }
      attendanceProvider.resetStatus();
    }
  }
}

  Future<void> _startStampedClockOut(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.token == null) {
      showErrorSnackBar(context, "Sesi tidak valid, silakan login ulang.");
      return;
    }

    final imageResult = await ImageHelper.takePhotoWithLocation(context);

    if (imageResult == null || !mounted) return;

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
    await attendanceProvider.performClockOut(
      context: context,
      image: imageResult.file,
      token: authProvider.token!,
    );
  } catch (e) {
    debugPrint("Terjadi error tak terduga saat clock-out: $e");
  } finally {
    if (mounted) {
      Navigator.of(context).pop();

      final status = attendanceProvider.status;
      final message = attendanceProvider.message;

      if (status == AttendanceProcessStatus.success) {
        showInfoSnackBar(context, message ?? 'Absen pulang berhasil!');
      } else if (status == AttendanceProcessStatus.error) {
        showErrorSnackBar(context, message ?? 'Gagal absen pulang.');
      }

      attendanceProvider.resetStatus();
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    String? userRole;
    if (user != null && user.roles.isNotEmpty) {
      userRole = user.roles.first;
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(user?.name ?? 'User'),
              _buildTimeCard(),
              _buildDashboardStats(),
              if (userRole == 'driver') const _TripCalculatorCard(),
              _buildMenuGrid(context, userRole),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(
                'Gagal memuat statistik: ${provider.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                context,
                'Hadir',
                provider.hadirCount.toString(),
                Icons.check_circle_outline,
                Colors.green,
              ),
              _buildStatCard(
                context,
                'Izin',
                provider.izinCount.toString(),
                Icons.info_outline,
                Colors.orange,
              ),
              _buildStatCard(
                context,
                'Sakit',
                provider.sakitCount.toString(),
                Icons.local_hospital_outlined,
                Colors.red,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String count,
      IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context, String? role) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    if (role == 'driver') {
      return _buildDriverMenuGrid(context, attendanceProvider);
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
                  AttendanceProcessStatus.processing) return;
              if (attendanceProvider.hasClockedIn) {
                showInfoSnackBar(context, 'Anda sudah absen datang hari ini.');
              } else {
                _startStampedClockIn(context);
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
                _startStampedClockOut(context);
              }
            },
          ),
          AnimatedMenuItem(
            icon: Icons.badge_outlined,
            label: 'ID Karyawan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IdCardScreen()),
              );
            },
          ),
          AnimatedMenuItem(
              icon: Icons.note_alt_outlined,
              label: 'Izin',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LeaveRequestScreen()),
                );
                if (mounted) {
                  Provider.of<DashboardProvider>(context, listen: false)
                      .fetchDashboardData(context: context);
                }
              }),
          AnimatedMenuItem(
              icon: Icons.timer_outlined,
              label: 'Lembur',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LemburScreen()),
                );
              }),
          AnimatedMenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Slip Gaji',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PayslipListScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDriverMenuGrid(
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
            label: 'Absensi',
            onTap: () {
              if (attendanceProvider.status ==
                  AttendanceProcessStatus.processing) {
                return;
              }
              if (attendanceProvider.hasClockedIn) {
                showInfoSnackBar(context, 'Anda sudah absen datang hari ini.');
              } else {
                _startStampedClockIn(context);
              }
            },
          ),
          AnimatedMenuItem(
            icon: Icons.local_shipping_outlined,
            label: 'Mulai Trip',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyTripScreen()),
              );
              if (result == true && mounted) {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.token != null) {
                  Provider.of<TripProvider>(context, listen: false)
                      .fetchTrips(context: context, token: authProvider.token!);
                }
              }
            },
          ),
          AnimatedMenuItem(
            icon: Icons.alt_route,
            label: 'Trip Geser',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VehicleLocationListScreen()),
              );
            },
          ),
          AnimatedMenuItem(
            icon: Icons.badge_outlined,
            label: 'ID Karyawan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IdCardScreen()),
              );
            },
          ),
          AnimatedMenuItem(
              icon: Icons.note_alt_outlined,
              label: 'Izin',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LeaveRequestScreen()),
                );
                if (mounted) {
                  Provider.of<DashboardProvider>(context, listen: false)
                      .fetchDashboardData(context: context);
                }
              }),
          AnimatedMenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Slip Gaji',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PayslipListScreen()),
              );
            },
          ),
          
          AnimatedMenuItem(
            icon: Icons.local_gas_station_outlined,
            label: 'Isi BBM',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BbmListScreen()),
              );
            },
          ),
          
        ],
      ),
    );
  }

  Widget _buildHeader(String userName) {
    final user = context.watch<AuthProvider>().user;
    final String? photoPath = user?.profilePhotoUrl;
    final String baseUrl =
        dotenv.env['API_BASE_URL']?.replaceAll('/api', '') ?? '';
    
    final String? finalPhotoUrl = (photoPath != null && photoPath.isNotEmpty)
        ? (photoPath.startsWith('http') ? photoPath : '$baseUrl$photoPath')
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.blue[100], // Warna fallback jika tidak ada gambar
            // vvv GUNAKAN finalPhotoUrl DI SINI vvv
            backgroundImage: finalPhotoUrl != null
                ? NetworkImage(finalPhotoUrl)
                : null,
            // Jika tidak ada foto, tampilkan ikon
            child: finalPhotoUrl == null
                ? const Icon(Icons.person, size: 25, color: Colors.white)
                : null,
            onBackgroundImageError: (exception, stackTrace) {
              // Handle error, mungkin dengan menampilkan inisial
            },
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
            Color.fromARGB(255, 73, 191, 252),
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
                  timeString,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  dateString,
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

class _TripCalculatorCard extends StatelessWidget {
  const _TripCalculatorCard();

  void _showTripDetails(
      BuildContext context, int companyTrips, int driverTrips) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Trip Bulan Ini',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                  Icons.business, 'Muatan Perusahaan', '$companyTrips Trip'),
              const SizedBox(height: 12),
              _buildDetailRow(
                  Icons.person, 'Muatan Driver', '$driverTrips Trip'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Consumer<TripProvider>(
        builder: (context, tripProvider, child) {
          if (tripProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tripProvider.errorMessage != null) {
            return Center(child: Text(tripProvider.errorMessage!));
          }

          final int totalTrips = tripProvider.totalTrips;
          final int companyTrips = tripProvider.companyTrips;
          final int driverTrips = tripProvider.driverTrips;
          const int minTrips = 26;
          const int maxTrips = 90;

          final now = DateTime.now();
          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
          final isWarningPeriod = (lastDayOfMonth - now.day) <= 3;
          final needsAttention = totalTrips < minTrips && isWarningPeriod;

          final Color progressColor =
              needsAttention ? Colors.red.shade700 : Colors.green.shade600;

          return GestureDetector(
            onTap: () => _showTripDetails(context, companyTrips, driverTrips),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      needsAttention
                          ? Colors.red.shade100
                          : Colors.green.shade50,
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.show_chart, color: progressColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Performa Trip Bulanan',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalTrips/$maxTrips',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Target Minimum'),
                            Text(
                              '$minTrips Trip',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: totalTrips / maxTrips,
                        minHeight: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (needsAttention)
                      const Text(
                        'Performa di bawah target! Sisa 3 hari.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
