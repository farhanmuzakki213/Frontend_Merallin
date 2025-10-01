// lib/leave_request_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/leave_provider.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'utils/image_absen_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// --- BAGIAN KELAS UTAMA DENGAN TAB ---
class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});
  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<LeaveProvider>(context, listen: false).fetchLeaveHistory(
          context: context,
          token: authProvider.token!,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Izin'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Ajukan Izin'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LeaveRequestForm(
            onSuccess: () {
              if (mounted) {
                // Navigator.of(context).pop();
                _tabController.animateTo(1);
              }
            },
          ),
          const LeaveHistoryList(),
        ],
      ),
    );
  }
}

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const LeaveRequestForm({super.key, required this.onSuccess});
  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  LeaveType? _selectedLeaveType;
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  File? _pickedFile;
  bool _isLoadingPhoto = false;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: isStartDate ? DateTime(2020) : (_startDate ?? DateTime(2020)),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleTakePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
    });

    final imageResult = await ImageHelper.takePhotoWithLocation(context);

    if (!mounted) return;

    if (imageResult != null) {
      setState(() {
        _pickedFile = imageResult.file;
      });
    }

    setState(() {
      _isLoadingPhoto = false;
    });
  }

  Future<void> _submitLeaveNotification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      showErrorSnackBar(context, 'Tanggal mulai dan selesai wajib diisi.');
      return;
    }
    if (_pickedFile == null) {
      showWarningSnackBar(context, 'Bukti izin wajib diunggah.');
      return;
    }

    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      showErrorSnackBar(context, 'Sesi Anda berakhir, silakan login ulang.');
      return;
    }

    await leaveProvider.submitLeave(
      context: context,
      token: authProvider.token!,
      jenisIzin: _selectedLeaveType!,
      tanggalMulai: _startDate!,
      tanggalSelesai: _endDate!,
      alasan: _reasonController.text.trim(),
      fileBukti: _pickedFile,
    );

    if (!mounted) return;

    if (leaveProvider.submissionStatus == DataStatus.success) {
      showSuccessSnackBar(context, 'Pemberitahuan izin berhasil dikirim.');
      widget.onSuccess();
    } else {
      showErrorSnackBar(context, leaveProvider.submissionMessage ?? 'Terjadi kesalahan.');
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, child) {
        final isSubmitting = provider.submissionStatus == DataStatus.loading;
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Detail Izin'),
                _buildCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<LeaveType>(
                        value: _selectedLeaveType,
                        hint: const Text('Pilih jenis izin'),
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.category_outlined),
                            border: InputBorder.none),
                        items: LeaveType.values.map((LeaveType type) {
                          return DropdownMenuItem(
                              value: type, child: Text(type.name));
                        }).toList(),
                        onChanged: (LeaveType? newValue) {
                          setState(() {
                            _pickedFile = null;
                            _selectedLeaveType = newValue;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Jenis izin wajib dipilih' : null,
                      ),
                      const Divider(height: 1),
                      _buildPickerTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'Tanggal Mulai',
                        value: _startDate != null
                            ? DateFormat('d MMM yyyy', 'id_ID')
                                .format(_startDate!)
                            : 'Pilih Tanggal',
                        onTap: () => _selectDate(context, true),
                      ),
                      const Divider(height: 1),
                      _buildPickerTile(
                        icon: Icons.calendar_today,
                        title: 'Tanggal Selesai',
                        value: _endDate != null
                            ? DateFormat('d MMM yyyy', 'id_ID')
                                .format(_endDate!)
                            : 'Pilih Tanggal',
                        onTap: () => _selectDate(context, false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_selectedLeaveType == LeaveType.kepentinganKeluarga ||
                    _selectedLeaveType == LeaveType.sakit) ...[
                  _buildReasonSection(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting || _isLoadingPhoto
                        ? null
                        : _submitLeaveNotification,
                    icon: isSubmitting || _isLoadingPhoto
                        ? Container()
                        : const Icon(Icons.send),
                    label: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ))
                        : const Text('Kirim Pemberitahuan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 8.0),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900])));
  Widget _buildCard({required Widget child}) => Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: child);
  Widget _buildPickerTile(
          {required IconData icon,
          required String title,
          required String value,
          required VoidCallback onTap}) =>
      ListTile(
          onTap: onTap,
          leading: Icon(icon, color: Colors.blue[700]),
          title: Text(title),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey)
          ]));

  Widget _buildReasonSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle('Alasan Izin (Wajib)'),
        _buildCard(
            child: TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Tuliskan alasan lengkap Anda di sini...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16)),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Alasan wajib diisi'
                    : null))
      ]);

  Widget _buildPhotoSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle('Bukti Foto (Wajib)'),
        _buildCard(
            child: _buildPickerTile(
                icon: Icons.camera_alt_outlined,
                title: 'Bukti Foto',
                value: _pickedFile != null ? 'Foto Diambil' : 'Ambil Foto',
                onTap: _handleTakePhoto)),
        if (_isLoadingPhoto)
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_pickedFile != null && !_isLoadingPhoto)
          Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Stack(alignment: Alignment.topRight, children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.file(_pickedFile!),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_pickedFile!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover)),
                ),
                IconButton(
                    icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child:
                            Icon(Icons.close, size: 20, color: Colors.white)),
                    onPressed: () => setState(() {
                          _pickedFile = null;
                        }))
              ]))
      ]);
}

class LeaveHistoryList extends StatelessWidget {
  const LeaveHistoryList({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    // Ambil provider yang dibutuhkan (tanpa listen)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

    if (authProvider.token != null) {
      await leaveProvider.fetchLeaveHistory(
        context: context,
        token: authProvider.token!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, child) {
        if (provider.historyStatus == DataStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.historyStatus == DataStatus.error) {
          return Center(
              child: Text(provider.historyMessage ?? 'Gagal memuat riwayat.'));
        }
        if (provider.leaveHistory.isEmpty) {
          return const Center(child: Text('Belum ada riwayat izin.'));
        }
        return RefreshIndicator(
          onRefresh: () => _handleRefresh(context),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: provider.leaveHistory.length,
            itemBuilder: (context, index) {
              final Izin item = provider.leaveHistory[index];
              return _ExpandableLeaveCard(izin: item);
            },
          ),
        );
      },
    );
  }
}

class _ExpandableLeaveCard extends StatefulWidget {
  final Izin izin;
  const _ExpandableLeaveCard({required this.izin});

  @override
  State<_ExpandableLeaveCard> createState() => __ExpandableLeaveCardState();
}

class __ExpandableLeaveCardState extends State<_ExpandableLeaveCard> {
  bool _isExpanded = false;

  void _showNetworkImagePreview(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _NetworkImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${DateFormat('d MMM yyyy', 'id_ID').format(widget.izin.tanggalMulai)} - ${DateFormat('d MMM yyyy', 'id_ID').format(widget.izin.tanggalSelesai)}';
    final cardColor = Colors.blue.shade800;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.izin.jenisIzin.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cardColor,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateRange,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: cardColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            child:
                _isExpanded ? _buildExpandedDetails() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 20, thickness: 1.5),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Tanggal Mulai',
            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(widget.izin.tanggalMulai)
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today,
            'Tanggal Selesai',
            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(widget.izin.tanggalSelesai)
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.notes_rounded,
            'Alasan',
            (widget.izin.alasan == null || widget.izin.alasan!.trim().isEmpty)
                ? 'Tidak ada alasan'
                : widget.izin.alasan!
          ),
          const SizedBox(height: 24),
          if (widget.izin.fullUrlBukti != null)
            _buildPhotoSection("Bukti Foto", widget.izin.fullUrlBukti!),
        ],
      ),
    );
  }


 Widget _buildPhotoSection(String title, String imageUrl) {
  final String baseUrl = dotenv.env['API_BASE_URL']?.replaceAll('/api', '') ?? '';
  final String finalImageUrl = '$baseUrl$imageUrl';

  print('URL Gambar Izin Final: $finalImageUrl');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle(title, Colors.blue.shade800),
      GestureDetector(
        onTap: () => _showNetworkImagePreview(context, imageUrl),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(top: 4.0),
          child: Image.network( // <--- PASTIKAN HANYA SEPERTI INI
            finalImageUrl, // Langsung gunakan URL dari API
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Jika error, kita bisa lihat penyebabnya di sini
              print('Error memuat gambar: $error'); 
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    ],
  );
}

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 15,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  const _NetworkImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}