import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _nikCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      showErrorSnackBar(context, 'Anda harus menyetujui kebijakan privasi & ketentuan layanan.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmPasswordCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      nik: _nikCtrl.text,
    );

    if (mounted) {
      if (success) {
        showSuccessSnackBar(context, 'Registrasi berhasil! Silakan login.');
        Navigator.of(context).pop();
      } else {
        showErrorSnackBar(
          context,
          authProvider.errorMessage ?? 'Registrasi gagal.',
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black),
      filled: true,
      fillColor: Colors.grey.shade200,
      prefixIcon: Icon(icon, color: Colors.black),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthProvider>().authStatus;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Create an account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join us!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Enter your name',
                      icon: Icons.person_outline,
                    ),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nikCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration( // Modifikasi di sini
                      hintText: 'Enter your NIK',
                      icon: Icons.credit_card_outlined,
                    ),
                    validator: (v) {
                      if (v!.isEmpty) {
                        return 'NIK is required';
                      }
                      if (v.length != 16) {
                        return 'NIK must be 16 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Enter your phone number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Phone number is required';
                      }
                      if (v.length < 10) {
                        return 'minimal 10 digit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _addressCtrl,
                    keyboardType: TextInputType.streetAddress,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Enter your address',
                      icon: Icons.location_on_outlined,
                    ),
                    // UBAH BAGIAN INI
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Address is required';
                      }
                      if (v.length < 10) {
                        return 'Alamat minimal 10 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Enter your email',
                      icon: Icons.email_outlined,
                    ),
                    validator: (v) => v!.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Enter your password',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v!.length < 8 ? 'Min 8 characters' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.black),
                    decoration: _inputDecoration(
                      hintText: 'Confirm Password',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) => v! != _passwordCtrl.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Checkbox(value: _agreeToTerms, onChanged: (v) => setState(() => _agreeToTerms = v!)),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(color: Colors.grey[700]),
                            children: [
                              TextSpan(text: 'Privacy Policy', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff039be5)), recognizer: TapGestureRecognizer()..onTap = () {}),
                              const TextSpan(text: ' and '),
                              TextSpan(text: 'Terms of Service', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff039be5)), recognizer: TapGestureRecognizer()..onTap = () {}),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authStatus == AuthStatus.authenticating || !_agreeToTerms ? null : _submitRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff039be5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: authStatus == AuthStatus.authenticating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: Colors.grey[700])),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff039be5))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
