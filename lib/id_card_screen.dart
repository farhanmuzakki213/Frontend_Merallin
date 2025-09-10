// lib/id_card_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/id_card_provider.dart';
import 'package:frontend_merallin/services/download_service.dart';
import 'package:frontend_merallin/services/notification_service.dart';
import 'package:provider/provider.dart';

class IdCardScreen extends StatefulWidget {
  const IdCardScreen({super.key});

  @override
  State<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends State<IdCardScreen> {
  final DownloadService _downloadService = DownloadService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ===== PERUBAHAN DI SINI =====
      Provider.of<IdCardProvider>(context, listen: false)
          .fetchIdCard(context: context);
    });
  }
  
  Future<void> _handleDownload(String? tempPdfPath) async {
    if (tempPdfPath == null || _isSaving) return;

    final idCardProvider = context.read<IdCardProvider>();

    if (idCardProvider.hasBeenDownloaded) {
      final bool? reDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text('File ini sudah pernah di-download. Apakah Anda ingin men-download ulang?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Tidak')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ya')),
          ],
        ),
      );
      if (!mounted || reDownload != true) return;
    }
    _showSaveOptions(tempPdfPath);
  }

  Future<void> _showSaveOptions(String tempPdfPath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan File'),
        content: const Text('Pilih cara Anda ingin menyimpan ID Card ini.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Pilih Lokasi...'),
            onPressed: () {
              Navigator.of(context).pop();
              _startDownloadProcess(tempPdfPath, isQuickDownload: false);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Download Cepat', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).pop();
              _startDownloadProcess(tempPdfPath, isQuickDownload: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startDownloadProcess(String tempPdfPath, {required bool isQuickDownload}) async {
    setState(() => _isSaving = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final userName = context.read<AuthProvider>().user?.name ?? 'user';
    final fileName = 'ID-Card-$userName';

    try {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Mempersiapkan file...')));
      
      final fileBytes = await File(tempPdfPath).readAsBytes();
      if (!mounted) return;

      String savedPath;
      if (isQuickDownload) {
        savedPath = await _downloadService.saveToDownloads(filename: fileName, fileBytes: fileBytes);
      } else {
        final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          savedPath = await _downloadService.saveToCustomDirectory(directoryPath: selectedDirectory, filename: fileName, fileBytes: fileBytes);
        } else {
          throw Exception('Pemilihan folder dibatalkan.');
        }
      }
      
      context.read<IdCardProvider>().setAsDownloaded();
      
      scaffoldMessenger.removeCurrentSnackBar();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('DOWNLOAD BERHASIL.')));

      await NotificationService.showDownloadCompleteNotification(filePath: savedPath, fileName: '$fileName.pdf');

    } catch (e) {
      if(mounted) {
        scaffoldMessenger.removeCurrentSnackBar();
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}')));
      }
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idCardProvider = context.watch<IdCardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Karyawan'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (idCardProvider.status == IdCardStatus.success && idCardProvider.pdfPath != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.download_rounded),
              tooltip: 'Simpan ke Perangkat',
              onPressed: () => _handleDownload(idCardProvider.pdfPath),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          switch (idCardProvider.status) {
            case IdCardStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case IdCardStatus.error:
              return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(idCardProvider.errorMessage ?? 'Terjadi kesalahan.', textAlign: TextAlign.center)));
            case IdCardStatus.success:
              if (idCardProvider.pdfPath != null) {
                return PDFView(filePath: idCardProvider.pdfPath!);
              }
              return const Center(child: Text('Gagal memuat file PDF.'));
            default:
              return const Center(child: Text('Memuat ID Card...'));
          }
        },
      ),
    );
  }
}