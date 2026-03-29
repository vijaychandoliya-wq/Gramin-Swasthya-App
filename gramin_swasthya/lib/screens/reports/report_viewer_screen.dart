import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/reports_provider.dart';

class ReportViewerScreen extends ConsumerWidget {
  final MedicalReport report;
  const ReportViewerScreen({super.key, required this.report});

  Future<void> _shareReport(BuildContext context) async {
    if (report.imagePath == null) return;

    if (report.imagePath!.startsWith('http')) {
      // For network images, in a real app we'd download to a temp file first.
      // For mock, we'll share the URL.
      await Share.share(
          'Medical Report: ${report.type} from ${report.doctorName}\n${report.imagePath}');
    } else {
      await Share.shareXFiles([XFile(report.imagePath!)],
          text: 'Medical Report: ${report.type}');
    }
  }

  Future<void> _downloadReport(BuildContext context) async {
    if (report.imagePath == null) return;

    try {
      final success = await GallerySaver.saveImage(report.imagePath!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success == true
                  ? 'गैलरी में सहेजा गया ✓'
                  : 'सहेजने में विफल')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('रिपोर्ट हटाएं? / Delete Report?'),
        content: const Text(
            'क्या आप वाकई इस रिपोर्ट को स्थायी रूप से हटाना चाहते हैं?\nAre you sure you want to delete this report permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('रद्द / Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('हटाएं / Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(reportsRepoProvider).deleteReport(report.id);
      context.pop(); // Close viewer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('रिपोर्ट हटा दी गई ✓ / Report Deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('dd MMM yyyy').format(report.date);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.type,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(dateStr,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(20),
        child: Center(
          child: Hero(
            tag: 'report_${report.id}',
            child: _buildImage(),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black.withOpacity(0.8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomAction(
              icon: Icons.share_outlined,
              label: 'शेयर',
              onTap: () => _shareReport(context),
            ),
            _BottomAction(
              icon: Icons.download_outlined,
              label: 'सहेजें',
              onTap: () => _downloadReport(context),
            ),
            _BottomAction(
              icon: Icons.delete_outline,
              label: 'हटाएं',
              color: Colors.redAccent,
              onTap: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (report.imagePath == null) {
      return const Icon(Icons.broken_image, size: 80, color: Colors.white54);
    }

    if (report.imagePath!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: report.imagePath!,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const CircularProgressIndicator(color: Colors.white),
        errorWidget: (context, url, error) => const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.white54),
            SizedBox(height: 8),
            Text('लोड करने में असमर्थ',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    } else {
      return Image.file(
        File(report.imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 48, color: Colors.white54),
      );
    }
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
