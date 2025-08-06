import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/utils/snackbar_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _registerFace() async {
    if (_imageFile == null) {
      showErrorSnackBar(context, 'Silakan ambil foto wajah Anda terlebih dahulu.');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.registerFace(_imageFile!);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran wajah berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
        // Provider akan otomatis mengarahkan ke HomeScreen karena user object sudah update
      } else {
        showErrorSnackBar(context, authProvider.errorMessage ?? 'Pendaftaran wajah gagal.');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Wajah'),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.face_retouching_natural, size: 100, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Satu Langkah Lagi!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Untuk keamanan, daftarkan wajah Anda untuk absensi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Center(
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_imageFile == null ? 'Ambil Foto Wajah' : 'Ambil Ulang Foto'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: Colors.blue[700]!),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _registerFace,
              icon: _isLoading
                  ? const SizedBox()
                  : const Icon(Icons.app_registration),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Daftarkan Wajah Saya'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
