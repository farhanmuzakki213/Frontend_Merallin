// lib/camera_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/camera_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
      } else {
        debugPrint("Tidak ada kamera yang ditemukan.");
      }
    } catch (e) {
      debugPrint("Gagal menginisialisasi kamera: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera belum siap.')),
      );
      return;
    }

    try {
      // 1. Ambil gambar
      final XFile image = await _controller!.takePicture();
      if (!mounted) return;

      // 2. Tampilkan halaman preview
      final bool? sendImage = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPreviewScreen(image: image),
        ),
      );

      // 3. Jika pengguna menekan "Kirim", kembalikan gambar
      if (sendImage == true) {
        Navigator.of(context).pop(image);
      }
      // Jika tidak, pengguna akan kembali ke halaman kamera untuk mengambil ulang.
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text("Kamera Desktop")),
        body: const Center(
          child: Text(
            'Gagal mengakses kamera. Pastikan kamera terhubung dan izin telah diberikan.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Ambil Foto")),
      body: Center(
        child: CameraPreview(_controller!),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}