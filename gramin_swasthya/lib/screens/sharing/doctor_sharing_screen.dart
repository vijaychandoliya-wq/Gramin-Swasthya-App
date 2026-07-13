import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:go_router/go_router.dart';

class DoctorSharingScreen extends StatefulWidget {
  const DoctorSharingScreen({super.key});

  @override
  State<DoctorSharingScreen> createState() => _DoctorSharingScreenState();
}

class _DoctorSharingScreenState extends State<DoctorSharingScreen> {
  final Map<String, bool> _shareOptions = {
    'Basic Profile (Age, Blood Group)': true,
    'Recent Vitals (BP, Sugar, Weight)': true,
    'Current Medicines': true,
    'Medical Reports (Last 6 Months)': false,
  };

  void _generateQr() {
    context.push('/share/qr');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const LocalizedText('Share with Doctor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              'Select what you want to share',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _shareOptions.keys.map((String key) {
                  return CheckboxListTile(
                    title: LocalizedText(key),
                    value: _shareOptions[key],
                    onChanged: (bool? value) {
                      setState(() {
                        _shareOptions[key] = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _generateQr,
              icon: const Icon(Icons.qr_code_2),
              label: const LocalizedText('Generate QR Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Direct link share implementation
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: LocalizedText('Opening Share Sheet...')));
              },
              icon: const Icon(Icons.share),
              label: const LocalizedText('Share Link Directly'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
