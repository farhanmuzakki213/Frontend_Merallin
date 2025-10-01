// lib/payslip_list_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/models/payslip_model.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:frontend_merallin/providers/payslip_provider.dart';
import 'package:frontend_merallin/services/download_service.dart';
import 'package:frontend_merallin/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PayslipListScreen extends StatefulWidget {
  const PayslipListScreen({super.key});

  @override
  State<PayslipListScreen> createState() => _PayslipListScreenState();
}

class _PayslipListScreenState extends State<PayslipListScreen> {
  final DownloadService _downloadService = DownloadService();
  int? _processingIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ===== PERUBAHAN DI SINI =====
      Provider.of<PayslipProvider>(context, listen: false)
          .fetchPayslipSummaries(context: context);
    });
  }

  Future<void> _handleDownload(PayslipSummary summary, int index) async {
    final payslipProvider = context.read<PayslipProvider>();

    if (payslipProvider.downloadedSlipIds.contains(summary.id)) {
      final bool? reDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text(
              'File ini sudah pernah di-download. Apakah Anda ingin men-download ulang?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Tidak')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ya')),
          ],
        ),
      );
      if (!mounted || reDownload != true) return;
    }

    _showSaveOptions(summary, index);
  }

  Future<void> _showSaveOptions(PayslipSummary summary, int index) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan File'),
        content: const Text('Pilih cara Anda ingin menyimpan slip gaji ini.'),
        actions: <Widget>[
          // TextButton(
          //   child: const Text('Pilih Folder Lain...'),
          //   onPressed: () {
          //     Navigator.of(context).pop();
          //     _startDownloadProcess(summary, index, isQuickDownload: false);
          //   },
          // ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Download Cepat',
                style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(context).pop();
              _startDownloadProcess(summary, index, isQuickDownload: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startDownloadProcess(PayslipSummary summary, int index,
      {required bool isQuickDownload}) async {
    if (_processingIndex != null) return;
    setState(() => _processingIndex = index);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) {
      scaffoldMessenger
          .showSnackBar(const SnackBar(content: Text('Sesi tidak valid.')));
      setState(() => _processingIndex = null);
      return;
    }

    try {
      final fileName =
          'slip-gaji-${DateFormat('MMMM-yyyy', 'id_ID').format(summary.period)}';
      scaffoldMessenger
          .showSnackBar(SnackBar(content: Text('Mengunduh $fileName...')));

      final fileBytes = await _downloadService.fetchFileBytes(
          url: summary.fileUrl, token: token);
      if (!mounted) return;

      String savedPath;
      if (isQuickDownload) {
        savedPath = await _downloadService.saveToDownloads(
          filename: fileName,
          fileBytes: fileBytes,
        );
      } else {
        final String? selectedDirectory =
            await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          savedPath = await _downloadService.saveToCustomDirectory(
            filename: fileName,
            fileBytes: fileBytes,
          );
        } else {
          throw Exception('Pemilihan folder dibatalkan.');
        }
      }

      context.read<PayslipProvider>().addDownloadedSlipId(summary.id);

      scaffoldMessenger.removeCurrentSnackBar();
      scaffoldMessenger
          .showSnackBar(const SnackBar(content: Text('DOWNLOAD BERHASIL.')));

      await NotificationService().showDownloadCompleteNotification(
        filePath: savedPath,
        fileName: '$fileName.pdf',
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.removeCurrentSnackBar();
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(
                'Gagal: ${e.toString().replaceFirst('Exception: ', '')}')));
      }
    } finally {
      if (mounted) setState(() => _processingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slip Gaji'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: Consumer<PayslipProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.summaries.isEmpty)
            return const Center(child: CircularProgressIndicator());
          if (provider.errorMessage != null)
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Gagal memuat data: ${provider.errorMessage}',
                        textAlign: TextAlign.center)));
          if (provider.summaries.isEmpty)
            return const Center(
                child: Text('Belum ada riwayat slip gaji.',
                    style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: provider.summaries.length,
            itemBuilder: (context, index) {
              final summary = provider.summaries[index];
              final monthName =
                  DateFormat('MMMM yyyy', 'id_ID').format(summary.period);
              final isCurrentlyProcessing = _processingIndex == index;
              final bool hasBeenDownloaded =
                  provider.downloadedSlipIds.contains(summary.id);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  leading: CircleAvatar(
                      backgroundColor:
                          hasBeenDownloaded ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      child: Icon(hasBeenDownloaded
                          ? Icons.check_circle_outline
                          : Icons.picture_as_pdf_outlined)),
                  title: Text(monthName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(hasBeenDownloaded
                          ? 'Sudah di-download. Ketuk untuk opsi simpan.'
                          : 'Ketuk untuk menyimpan')),
                  trailing: isCurrentlyProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.download_for_offline_outlined,
                          color: Colors.grey),
                  onTap: () => _handleDownload(summary, index),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
