// lib/screens/ajukan_lembur_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/lembur_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/lembur_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AjukanLemburScreen extends StatefulWidget {
  const AjukanLemburScreen({super.key});

  @override
  State<AjukanLemburScreen> createState() => _AjukanLemburScreenState();
}

class _AjukanLemburScreenState extends State<AjukanLemburScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tanggalController = TextEditingController();
  final _mulaiController = TextEditingController();
  final _selesaiController = TextEditingController();
  final _pekerjaanController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // --- PERUBAHAN 1: Menyesuaikan Opsi dengan Model Data (Enum) ---
  DepartmentLembur? _selectedDepartement;
  JenisHariLembur? _selectedJenis;

  // Opsi ini sekarang diambil dari enum untuk konsistensi data
  final List<DepartmentLembur> _departementOptions = DepartmentLembur.values;
  final List<JenisHariLembur> _jenisOptions = JenisHariLembur.values;

  // State untuk loading
  bool _isLoading = false;

  @override
  void dispose() {
    _tanggalController.dispose();
    _mulaiController.dispose();
    _selesaiController.dispose();
    _pekerjaanController.dispose();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI LOGIKA ---
  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('id', 'ID'),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _tanggalController.text =
            DateFormat('EEEE, d MMMM y', 'id_ID').format(_selectedDate!);
      });
    }
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        if (isStartTime) {
          _startTime = pickedTime;
          _mulaiController.text = _formatTime(_startTime);
        } else {
          _endTime = pickedTime;
          _selesaiController.text = _formatTime(_endTime);
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // --- PERUBAHAN 2: Logika Kalkulasi Durasi Diperbaiki ---
  String _calculateDuration() {
    if (_startTime == null || _endTime == null) {
      return '-- Jam -- Menit';
    }

    final now = DateTime.now();
    var startDateTime = DateTime(
        now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
    var endDateTime = DateTime(
        now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    final difference = endDateTime.difference(startDateTime);
    if (difference.isNegative) {
      return 'Jam tidak valid';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return '$hours Jam $minutes Menit';
  }

  // --- PERUBAHAN 3: Implementasi Logika Submit ke Provider ---
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap lengkapi semua data yang wajib diisi.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lemburProvider = Provider.of<LemburProvider>(context, listen: false);

    try {
      await lemburProvider.submitOvertime(
        token: authProvider.token!,
        jenisHari: _selectedJenis!,
        department: _selectedDepartement!,
        tanggalLembur: _selectedDate!,
        keteranganLembur: _pekerjaanController.text.trim(),
        mulaiJamLembur: _formatTime(_startTime),
        selesaiJamLembur: _formatTime(_endTime),
      );

      if (lemburProvider.submissionStatus == DataStatus.success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Pengajuan lembur berhasil dikirim.'),
              backgroundColor: Colors.green),
        );
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content:
                  Text(lemburProvider.submissionMessage ?? 'Terjadi kesalahan'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Pengajuan Lembur'),
        // backgroundColor: Colors.transparent,
        // elevation: 0,
        // foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Utama',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Tanggal Lembur',
                        child: TextFormField(
                          controller: _tanggalController,
                          readOnly: true,
                          decoration: _inputDecoration(
                              hint: 'Pilih Tanggal',
                              icon: Icons.calendar_today_outlined),
                          onTap: _selectDate,
                          validator: (v) =>
                              v!.isEmpty ? 'Tanggal harus diisi' : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Departement',
                        child: DropdownButtonFormField<DepartmentLembur>(
                          value: _selectedDepartement,
                          decoration: _inputDecoration(
                              hint: 'Pilih Departement',
                              icon: Icons.business_center_outlined),
                          items: _departementOptions
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text(v.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedDepartement = v),
                          validator: (v) =>
                              v == null ? 'Departement harus dipilih' : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Jenis Hari',
                        child: DropdownButtonFormField<JenisHariLembur>(
                          value: _selectedJenis,
                          decoration: _inputDecoration(
                              hint: 'Pilih Jenis Hari',
                              icon: Icons.work_history_outlined),
                          items: _jenisOptions
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text(v.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedJenis = v),
                          validator: (v) =>
                              v == null ? 'Jenis hari harus dipilih' : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail Waktu & Pekerjaan',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Jam Mulai',
                              child: TextFormField(
                                controller: _mulaiController,
                                readOnly: true,
                                decoration: _inputDecoration(
                                    hint: '00:00',
                                    icon: Icons.access_time_outlined),
                                onTap: () => _selectTime(isStartTime: true),
                                validator: (v) =>
                                    v!.isEmpty ? 'Wajib diisi' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              label: 'Jam Selesai',
                              child: TextFormField(
                                controller: _selesaiController,
                                readOnly: true,
                                decoration: _inputDecoration(
                                    hint: '00:00', icon: Icons.update_outlined),
                                onTap: () => _selectTime(isStartTime: false),
                                validator: (v) =>
                                    v!.isEmpty ? 'Wajib diisi' : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildDurationDisplay(),
                      const SizedBox(height: 24),
                      _buildFormField(
                        label: 'Pekerjaan / Alasan Lembur',
                        child: TextFormField(
                          controller: _pekerjaanController,
                          decoration: _inputDecoration(
                              hint: 'Cth: Menyelesaikan laporan bulanan...'),
                          maxLines: 4,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Alasan tidak boleh kosong.'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- PERUBAHAN 4: Tombol dinamis berdasarkan state loading ---
              FilledButton(
                onPressed: _isLoading ? null : _submitForm,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ))
                    : const Text('KIRIM PENGAJUAN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- BAGIAN BUILD METHOD (BANYAK PERUBAHAN DI SINI) ---


  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    );
  }

  Widget _buildDurationDisplay() {
    final durationText = _calculateDuration();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Total Durasi Lembur',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              durationText,
              key: ValueKey<String>(durationText),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
