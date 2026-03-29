import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrShareScreen extends StatelessWidget {
  const QrShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mock URL that the QR code will represent
    const String mockShareUrl = 'https://graminswasthya.web.app/share/session-ab12cd34';

    return Scaffold(
      appBar: AppBar(title: const Text('Scan to Share')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Show this code to your doctor',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'They can scan it to view your selected health records securely.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: mockShareUrl,
                    version: QrVersions.auto,
                    size: 250.0,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              OutlinedButton.icon(
                onPressed: () {
                  // Direct link share implementation
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Opening Share Sheet...'))
                   );
                },
                icon: const Icon(Icons.link),
                label: const Text('Share Link Instead'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'This link will expire in 24 hours.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
