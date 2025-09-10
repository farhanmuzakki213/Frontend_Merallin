// lib/leave_request_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/izin_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/leave_provider.dart';
import 'package:frontend_merallin/utils/image_helper.dart';
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
              _tabController.animateTo(1);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.token != null) {
                // ===== PERUBAHAN DI SINI =====
                Provider.of<LeaveProvider>(context, listen: false)
                    .fetchLeaveHistory(
                  context: context,
                  token: authProvider.token!,
                );
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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (await file.length() > 2048 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ukuran file tidak boleh melebihi 2MB.'),
              backgroundColor: Colors.red,),);
        }
        return;
      }
      setState(() {
        _pickedFile = file;
      });
    }
  }

  Future<void> _handleTakePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
    });

    final newPhoto = await ImageHelper.takeGeotaggedPhoto(context);

    if (!mounted) return;

    if (newPhoto != null) {
      setState(() {
        _pickedFile = newPhoto;
      });
    }

    setState(() {
      _isLoadingPhoto = false;
    });
  }

  Future<void> _submitLeaveNotification() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Tanggal mulai dan selesai wajib diisi.'),
          backgroundColor: Colors.red,),);
      return;
    }
    if (_pickedFile == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Bukti izin wajib diunggah.'),
          backgroundColor: Colors.red,),);
      return;
    }

    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Sesi Anda berakhir, silakan login ulang.'),
          backgroundColor: Colors.red,),);
      return;
    }

    // ===== PERUBAHAN DI SINI =====
    await leaveProvider.submitLeave(
      context: context,
      token: authProvider.token!,
      jenisIzin: _selectedLeaveType!,
      tanggalMulai: _startDate!,
      tanggalSelesai: _endDate!,
      alasan: _reasonController.text.trim(),
      fileBukti: _pickedFile,
    );

    if (leaveProvider.submissionStatus == DataStatus.success) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('Pemberitahuan izin berhasil dikirim.'),
          backgroundColor: Colors.green,),);
      widget.onSuccess();
    } else {
      scaffoldMessenger.showSnackBar(SnackBar(
          content:
              Text(leaveProvider.submissionMessage ?? 'Terjadi kesalahan.'),
          backgroundColor: Colors.red,),);
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
                if (_selectedLeaveType == LeaveType.kepentinganKeluarga) ...[
                  _buildReasonSection(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                ],
                if (_selectedLeaveType == LeaveType.sakit)
                  _buildUploadSection(),
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

  // WIDGET FOTO DENGAN PREVIEW INTERAKTIF
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
                // FIX: Dibungkus dengan GestureDetector agar bisa diklik
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

  Widget _buildUploadSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle('Bukti Izin (Wajib)'),
        _buildCard(
            child: _buildPickerTile(
                icon: Icons.attach_file,
                title: 'File Bukti',
                value: _pickedFile != null ? _pickedFile!.path.split('/').last : 'Upload File',
                onTap: _pickFile)),
        if (_pickedFile != null)
          Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16),
              child: Row(children: [
                Expanded(
                    child: Text(_pickedFile!.path.split('/').last,
                        style: const TextStyle(color: Colors.black54),
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Colors.redAccent),
                    onPressed: () => setState(() {
                          _pickedFile = null;
                        }))
              ]))
      ]);
}

// --- BAGIAN RIWAYAT IZIN (WIDGET TERPISAH) ---
class LeaveHistoryList extends StatelessWidget {
  const LeaveHistoryList({super.key});
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
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.leaveHistory.length,
          itemBuilder: (context, index) {
            final Izin item = provider.leaveHistory[index];
            final dateRange =
                '${DateFormat('d MMM yyyy', 'id_ID').format(item.tanggalMulai)} - ${DateFormat('d MMM yyyy', 'id_ID').format(item.tanggalSelesai)}';
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.history, color: Colors.blue[700]),
                title: Text(item.jenisIzin.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Tanggal: $dateRange'),
                trailing: const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}