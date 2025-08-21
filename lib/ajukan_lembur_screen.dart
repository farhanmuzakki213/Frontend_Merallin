import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String? _selectedDepartement;
  String? _selectedJenis;
  final List<String> _departementOptions = [
    'Keuangan',
    'SDM',
    'Pemasaran',
    'Penjualan',
    'Produksi',
    'IT',
    'Pengembangan'
  ];
  final List<String> _jenisOptions = ['Kerja', 'Libur', 'Libur Nasional'];

  @override
  void dispose() {
    _tanggalController.dispose();
    _mulaiController.dispose();
    _selesaiController.dispose();
    _pekerjaanController.dispose();
    super.dispose();
  }

  // --- FUNGSI-FUNGSI LOGIKA (TIDAK ADA PERUBAHAN) ---
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
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _calculateDuration() {
    if (_startTime == null || _endTime == null) {
      return '-- Jam -- Menit';
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      return 'Jam tidak valid';
    }
    final difference = endMinutes - startMinutes;
    final hours = difference ~/ 60;
    final minutes = difference % 60;
    return '$hours Jam $minutes Menit';
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      print('Form Valid. Mengirim data...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pengajuan lembur berhasil dikirim.'),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap lengkapi semua data yang wajib diisi.'),
            backgroundColor: Colors.red),
      );
    }
  }

  // --- BAGIAN BUILD METHOD (BANYAK PERUBAHAN DI SINI) ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Pengajuan Lembur'),
        backgroundColor: Colors.transparent, //inisss
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- DIUBAH: Menggunakan Card dengan style berbeda ---
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
                      // --- BARU: Section Header untuk pengelompokan ---
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedDepartement,
                          decoration: _inputDecoration(
                              hint: 'Pilih Departement',
                              icon: Icons.business_center_outlined),
                          items: _departementOptions
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedJenis,
                          decoration: _inputDecoration(
                              hint: 'Pilih Jenis Hari',
                              icon: Icons.work_history_outlined),
                          items: _jenisOptions
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
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

              FilledButton(
                onPressed: _submitForm,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('KIRIM PENGAJUAN',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

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
