import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tambahkan package intl: flutter pub add intl

class AjukanLemburScreen extends StatefulWidget {
  const AjukanLemburScreen({super.key});

  @override
  State<AjukanLemburScreen> createState() => _AjukanLemburScreenState();
}

class _AjukanLemburScreenState extends State<AjukanLemburScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pekerjaanController = TextEditingController();

  // State untuk menyimpan data form
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _pekerjaanController.dispose();
    super.dispose();
  }

  // Fungsi untuk menampilkan date picker
  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Fungsi untuk menampilkan time picker
  Future<void> _selectTime({required bool isStartTime}) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        if (isStartTime) {
          _startTime = pickedTime;
        } else {
          _endTime = pickedTime;
        }
      });
    }
  }
  
  // Fungsi untuk memformat waktu (misal: 17:30)
  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Pilih Jam';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  // Fungsi untuk menghitung durasi
  String _calculateDuration() {
    if (_startTime == null || _endTime == null) {
      return '-- Jam -- Menit';
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    
    if (endMinutes < startMinutes) {
      return 'Jam tidak valid';
    }

    final difference = endMinutes - startMinutes;
    final hours = difference ~/ 60;
    final minutes = difference % 60;

    return '$hours Jam $minutes Menit';
  }

  void _submitForm() {
    // Validasi semua input
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal lembur harus diisi.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai dan selesai harus diisi.'), backgroundColor: Colors.red),
      );
      return;
    }
     if (!_formKey.currentState!.validate()) {
       return; // Validasi form alasan
     }

    // TODO: Kirim data ke API/Provider
    print('Tanggal: $_selectedDate');
    print('Jam Mulai: $_startTime');
    print('Jam Selesai: $_endTime');
    print('Alasan: ${_pekerjaanController.text}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengajuan lembur berhasil dikirim.'), backgroundColor: Colors.green),
    );
    Navigator.of(context).pop();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Pengajuan Lembur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input Tanggal
              _buildDateTimePicker(
                label: 'Tanggal Lembur',
                value: _selectedDate == null ? 'Pilih Tanggal' : DateFormat('EEEE, d MMMM y', 'id_ID').format(_selectedDate!),
                icon: Icons.calendar_today_outlined,
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              
              // Input Jam Mulai & Selesai
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'Jam Mulai',
                      value: _formatTime(_startTime),
                      icon: Icons.access_time_outlined,
                      onTap: () => _selectTime(isStartTime: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateTimePicker(
                      label: 'Jam Selesai',
                      value: _formatTime(_endTime),
                      icon: Icons.access_time_filled_outlined,
                      onTap: () => _selectTime(isStartTime: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tampilan Durasi
              _buildDurationDisplay(),
              const SizedBox(height: 24),

              // Input Alasan Lembur
              TextFormField(
                controller: _pekerjaanController,
                decoration: const InputDecoration(
                  labelText: 'Pekerjaan / Alasan Lembur',
                  hintText: 'Cth: Menyelesaikan laporan bulanan...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Alasan lembur tidak boleh kosong.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // Tombol Kirim
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('KIRIM PENGAJUAN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget pembantu untuk input tanggal & jam
  Widget _buildDateTimePicker({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Widget pembantu untuk menampilkan durasi
  Widget _buildDurationDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           const Text(
            'Total Durasi Lembur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Text(
            _calculateDuration(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }
}