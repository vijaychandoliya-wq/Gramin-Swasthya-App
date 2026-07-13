import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_language.dart';

class QRScreen extends StatefulWidget {
  final String tokenId;
  const QRScreen({super.key, required this.tokenId});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isExpired = false;
  Map<String, dynamic>? _shareData;

  @override
  void initState() {
    super.initState();
    _fetchAndStartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAndStartTimer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shares')
          .doc(widget.tokenId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final expiry = (data['expiry'] as Timestamp).toDate();

        setState(() {
          _shareData = data;
          _updateRemaining(expiry);
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            _updateRemaining(expiry);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching share data: $e');
    }
  }

  void _updateRemaining(DateTime expiry) {
    final now = DateTime.now();
    final diff = expiry.difference(now);

    if (diff.isNegative) {
      _timer?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _isExpired = true;
      });
    } else {
      setState(() {
        _remaining = diff;
        _isExpired = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _shareLink() async {
    final url = "https://graminsw.app/share/${widget.tokenId}";
    await Share.share(
      AppLanguage.isHindi
          ? 'डॉक्टर के लिए मेरा स्वास्थ्य रिकॉर्ड लिंक: $url'
          : 'My health record link for the doctor: $url',
      subject: AppLanguage.isHindi
          ? 'स्वास्थ्य रिकॉर्ड की पहुँच'
          : 'Health Record Access',
    );
  }

  Future<void> _launchWhatsApp() async {
    final url = "https://graminsw.app/share/${widget.tokenId}";
    final text = AppLanguage.isHindi
        ? 'नमस्ते डॉक्टर, मेरे स्वास्थ्य रिकॉर्ड को देखने के लिए इस लिंक का उपयोग करें: $url'
        : 'Hello Doctor, use this link to view my health records: $url';
    final whatsappUrl =
        Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: LocalizedText('WhatsApp शुरू करने में असमर्थ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shareUrl = "https://graminsw.app/share/${widget.tokenId}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const LocalizedText('QR कोड',
            style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareLink,
          ),
        ],
      ),
      body: _shareData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  LocalizedText("डॉक्टर को दिखाएं",
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary)),
                  const SizedBox(height: 8),
                  const LocalizedText("यह कोड scan करने दें",
                      style: TextStyle(color: Colors.grey)),

                  const SizedBox(height: 32),

                  // QR Card
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: shareUrl,
                                version: QrVersions.auto,
                                size: 240.0,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF6750A4),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF1C1B1F),
                                ),
                              ),
                              if (_isExpired)
                                ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: 240,
                                      height: 240,
                                      alignment: Alignment.center,
                                      color: Colors.white.withOpacity(0.4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.timer_off_outlined,
                                              size: 48, color: Colors.red),
                                          const SizedBox(height: 8),
                                          const LocalizedText(
                                              "समाप्त / Expired",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red)),
                                          const SizedBox(height: 12),
                                          FilledButton.tonal(
                                            onPressed: () => context.pop(),
                                            child: const LocalizedText(
                                                "नया बनाएं"),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          LocalizedText(
                            _shareData?['memberName'] ?? 'Member',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          LocalizedText(
                            (_shareData?['dataTypes'] as List? ?? [])
                                .join(" • "),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),

                          // Countdown Chip
                          Chip(
                            label: LocalizedText(
                              _isExpired
                                  ? "समाप्त / Expired"
                                  : _formatDuration(_remaining),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            avatar: Icon(
                                _isExpired
                                    ? Icons.timer_off
                                    : Icons.timer_outlined,
                                size: 16),
                            backgroundColor: _isExpired
                                ? Colors.grey.shade200
                                : colorScheme.tertiaryContainer,
                            side: BorderSide.none,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Share Options
                  FilledButton.tonal(
                    onPressed: _shareLink,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link),
                        SizedBox(width: 12),
                        LocalizedText("लिंक शेयर करें / Share Link"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _launchWhatsApp,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 18),
                        SizedBox(width: 12),
                        LocalizedText("WhatsApp पर भेजें"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
