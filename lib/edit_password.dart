// lib/edit_password.dart

import 'package:flutter/material.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:provider/provider.dart'; // <-- JANGAN LUPA IMPORT
import '../providers/auth_provider.dart'; // <-- JANGAN LUPA IMPORT

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({super.key});

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- FUNGSI _submit DIUBAH TOTAL ---
  // --- FUNGSI _submit DIUBAH TOTAL ---
  void _submit() async {
    // 1. Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Cek apakah password baru dan konfirmasi cocok
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Konfirmasi password baru tidak cocok.');
      return;
    }

    // 3. Panggil AuthProvider untuk update password
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // ===== PERBAIKAN DI SINI =====
    final error = await authProvider.updatePassword(
      context: context, // <-- TAMBAHKAN BARIS INI
      currentPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      newPasswordConfirmation: _confirmPasswordController.text,
    );
    
    if (!mounted) return;

    // 4. Handle hasil dari provider
    if (error == null) {
      // Sukses
      showSuccessSnackBar(context, 'Password berhasil diperbarui.');
      Navigator.of(context).pop();
    } else {
      // Gagal
      showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil state isUpdating dari provider
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Ubah Password'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keamanan Akun',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'Untuk melindungi akun Anda, pastikan password Anda kuat dan mudah diingat.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              // Nama field di backend adalah 'current_password'
              _buildPasswordField(
                controller: _oldPasswordController,
                labelText: 'Password Lama',
                obscureText: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
              ),
              const SizedBox(height: 14),
              // Nama field di backend adalah 'password'
              _buildPasswordField(
                controller: _newPasswordController,
                labelText: 'Password Baru',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 14),
              // Nama field di backend adalah 'password_confirmation'
              _buildPasswordField(
                controller: _confirmPasswordController,
                labelText: 'Konfirmasi Password Baru',
                obscureText: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff039be5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  // Nonaktifkan tombol saat sedang loading
                  onPressed: authProvider.isUpdating ? null : _submit,
                  child: authProvider.isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Konfirmasi Password',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildPasswordField ini tidak perlu diubah, sudah bagus.
  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required String labelText,
  }) {
    IconData prefixIcon;
    if (labelText.contains('Lama')) {
      prefixIcon = Icons.lock_outline;
    } else if (labelText.contains('Baru') &&
        !labelText.contains('Konfirmasi')) {
      prefixIcon = Icons.lock;
    } else {
      prefixIcon = Icons.lock_reset;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Field tidak boleh kosong';
          }
          if (labelText.contains('Baru') && value.length < 8) {
            return 'Minimal 8 karakter';
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, size: 20, color: Colors.black45),
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.black, fontSize: 13),
          errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.black45,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}