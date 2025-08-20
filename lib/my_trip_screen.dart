// lib/my_trip_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_model.dart';
import '../services/trip_service.dart'; // Import ApiException
import '../providers/auth_provider.dart';
import 'laporan_perjalanan_screen.dart';

class MyTripScreen extends StatefulWidget {
  const MyTripScreen({super.key});

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  final TripService _tripService = TripService();

  bool _isLoading = true;
  String? _error;
  List<Trip> _trips = [];
  bool _hasActiveTrip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadData();
    });
  }

  Future<void> _reloadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      if (mounted) {
        setState(() {
          _error = 'Token tidak ditemukan. Silakan login kembali.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final trips = await _tripService.getTrips(authProvider.token!);
      if (mounted) {
        setState(() {
          _trips = trips;
          _hasActiveTrip = _trips.any((trip) => trip.statusTrip == 'proses');
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data: ${e.toString()}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Terjadi kesalahan tidak terduga: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showTakeTripConfirmation(Trip trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Pengambilan Tugas'),
          content: Text('Apakah Anda yakin akan mengambil perjalanan ke ${trip.destination}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Ya, Ambil Tugas'),
              onPressed: () {
                Navigator.of(context).pop();
                _handleTakeTrip(trip.id);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleTakeTrip(int tripId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengambil tugas...')),
    );

    try {
      await _tripService.acceptTrip(authProvider.token!, tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil diambil! Memuat ulang...'),
            backgroundColor: Colors.green,
          ),
        );
        _reloadData();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil tugas: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan tidak terduga: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fungsi untuk menampilkan pop-up edit trip
  void _showEditTripPopup(Trip trip) {
    final formKey = GlobalKey<FormState>();
    final projectNameController = TextEditingController(text: trip.projectName);
    final originController = TextEditingController(text: trip.origin);
    final destinationController = TextEditingController(text: trip.destination);
    bool isSubmitting = false;

    showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStatePopup) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 16,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Edit Trip',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: projectNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Proyek',
                            hintText: 'Masukkan nama proyek',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.business_center),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama proyek tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: originController,
                          decoration: InputDecoration(
                            labelText: 'Lokasi keberangkatan',
                            hintText: 'Lokasi Awal keberangkatan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.my_location),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lokasi Keberangkatan tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: destinationController,
                          decoration: InputDecoration(
                            labelText: 'Tujuan',
                            hintText: 'Lokasi tujuan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.location_on),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tujuan tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setStatePopup(() {
                                      isSubmitting = true;
                                    });
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    try {
                                      await _tripService.updateTrip(
                                        token: authProvider.token!,
                                        tripId: trip.id,
                                        projectName: projectNameController.text,
                                        origin: originController.text,
                                        destination: destinationController.text,
                                      );
                                      if (mounted) {
                                        Navigator.of(context).pop(true);
                                      }
                                    } on ApiException catch (e) {
                                      if (mounted) {
                                        Navigator.of(context).pop(e);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        Navigator.of(context).pop(e);
                                      }
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (mounted) {
        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadData();
        } else if (result is ApiException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (result is Exception) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _showDeleteConfirmation(Trip trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Hapus Trip', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus trip ke ${trip.destination}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                try {
                  await _tripService.deleteTrip(
                    Provider.of<AuthProvider>(context, listen: false).token!,
                    trip.id,
                  );
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                } on ApiException catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(e);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(e);
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((result) {
      if (mounted) {
        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip berhasil dihapus!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadData();
        } else if (result is ApiException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (result is Exception) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _showCreateTripPopup() {
    final formKey = GlobalKey<FormState>();
    final projectNameController = TextEditingController();
    final originController = TextEditingController();
    final destinationController = TextEditingController();
    bool isSubmitting = false;

    showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStatePopup) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 16,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Buat Trip Baru',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: projectNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Proyek',
                            hintText: 'Masukkan nama proyek',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.business_center),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama proyek tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: originController,
                          decoration: InputDecoration(
                            labelText: 'Lokasi keberangkatan',
                            hintText: 'Lokasi awal keberangkatan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.my_location),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lokasi keberangkatan tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: destinationController,
                          decoration: InputDecoration(
                            labelText: 'Tujuan',
                            hintText: 'Lokasi tujuan',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.location_on),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tujuan tidak boleh kosong.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setStatePopup(() {
                                      isSubmitting = true;
                                    });
                                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                    try {
                                      await _tripService.createTrip(
                                        token: authProvider.token!,
                                        projectName: projectNameController.text,
                                        origin: originController.text,
                                        destination: destinationController.text,
                                      );
                                      if (mounted) {
                                        Navigator.of(context).pop(true);
                                      }
                                    } on ApiException catch (e) {
                                      if (mounted) {
                                        Navigator.of(context).pop(e);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        Navigator.of(context).pop(e);
                                      }
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.add_circle, color: Colors.white),
                          label: Text(
                            isSubmitting ? 'Memproses...' : 'Buat Trip',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (mounted) {
        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip berhasil dibuat!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadData();
        } else if (result is ApiException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuat trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (result is Exception) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuat trip: ${result.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perjalanan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadData,
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadData,
      child: _buildTripList(),
    );
  }

  Widget _buildTripList() {
    if (_trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Saat ini tidak ada tugas untuk Anda.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              _buildCreateTripButton(context),
            ],
          ),
        ),
      );
    }

    final activeTrip = _trips.firstOrNullWhere((trip) => trip.statusTrip == 'proses');
    final availableTrips = _trips.where((trip) => trip.statusTrip == 'tersedia').toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (activeTrip != null) ...[
          const Text('Tugas Aktif Anda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTripCard(activeTrip),
        ],
        if (activeTrip == null && availableTrips.isNotEmpty) ...[
          const Text('Tugas Tersedia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...availableTrips.map((trip) => _buildTripCard(trip)).toList(),
        ],
        const SizedBox(height: 24),
        if (activeTrip == null)
          _buildCreateTripButton(context),
      ],
    );
  }

  Widget _buildCreateTripButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      label: const Text('Buat Trip Baru', style: TextStyle(color: Colors.white)),
      onPressed: _hasActiveTrip
          ? null // Menonaktifkan tombol jika ada trip aktif
          : _showCreateTripPopup,
      style: ElevatedButton.styleFrom(
        backgroundColor: _hasActiveTrip ? Colors.grey : Colors.blue[600],
        minimumSize: const Size(double.infinity, 50),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Perubahan di sini: Menambahkan tombol Edit dan Delete ke Card
  Widget _buildTripCard(Trip trip) {
    bool isAvailable = trip.statusTrip == 'tersedia';
    String statusText = isAvailable ? 'Tersedia untuk Diambil' : 'Dalam Perjalanan';
    Color statusColor = isAvailable ? Colors.green : Colors.orange;

    final canEditOrDelete = trip.userId != null && trip.statusTrip == 'proses' && trip.startKm == null;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (isAvailable) {
            _showTakeTripConfirmation(trip);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LaporanDriverScreen(trip: trip),
              ),
            ).then((result) {
              if (result == true) {
                _reloadData();
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(trip.projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (canEditOrDelete)
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        if (value == 'edit') {
                          _showEditTripPopup(trip);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(trip);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Hapus', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.my_location, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.origin)),
              ]),
              const Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: SizedBox(height: 15, child: VerticalDivider(thickness: 1)),
              ),
              Row(children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.destination)),
              ]),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor.withOpacity(0.3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension FirstOrNullExtension<E> on Iterable<E> {
  E? firstOrNullWhere(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}