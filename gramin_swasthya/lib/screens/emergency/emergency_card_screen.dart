import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/family_provider.dart';

class EmergencyCardScreen extends ConsumerStatefulWidget {
  const EmergencyCardScreen({super.key});

  @override
  ConsumerState<EmergencyCardScreen> createState() =>
      _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends ConsumerState<EmergencyCardScreen> {
  final PageController _pageController = PageController();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveAsImage(String memberId, String memberName) async {
    try {
      final key = _cardKeys[memberId];
      if (key == null) return;

      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          await File('${tempDir.path}/emergency_card_$memberId.png').create();
      await file.writeAsBytes(pngBytes);

      final success = await GallerySaver.saveImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success == true
                ? '$memberName का कार्ड गैलरी में सहेजा गया ✓'
                : 'सहेजने में विफल'),
            backgroundColor: success == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareOnWhatsApp(FamilyMember member) async {
    final text = """
🆘 *आपातकालीन स्वास्थ्य कार्ड* 🆘
नाम: ${member.name}
रक्त समूह: ${member.bloodGroup}
बीमारियां: ${member.diseases.join(", ")}
आपातकालीन संपर्क: ${member.emergencyContactName} (${member.emergencyPhone})
""";

    final whatsappUrl =
        Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      await Share.share(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final members = ref.watch(familyProvider);

    return Scaffold(
      backgroundColor: colorScheme.errorContainer,
      appBar: AppBar(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        centerTitle: true,
        title: const Text('🆘 आपातकालीन कार्ड'),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: members.isEmpty
          ? const Center(child: Text('कोई सदस्य नहीं मिला'))
          : Column(
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      _cardKeys[member.id] ??= GlobalKey();
                      return _buildEmergencyCard(
                          context, member, theme, colorScheme);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SmoothPageIndicator(
                  controller: _pageController,
                  count: members.length,
                  effect: WormEffect(
                    activeDotColor: colorScheme.error,
                    dotColor: colorScheme.error.withOpacity(0.3),
                    dotHeight: 10,
                    dotWidth: 10,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          final currentIndex =
                              _pageController.page?.round() ?? 0;
                          _shareOnWhatsApp(members[currentIndex]);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onError,
                          foregroundColor: colorScheme.error,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Text("💬", style: TextStyle(fontSize: 20)),
                        label: const Text("WhatsApp पर शेयर करें",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          final currentIndex =
                              _pageController.page?.round() ?? 0;
                          _saveAsImage(members[currentIndex].id,
                              members[currentIndex].name);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.error, width: 2),
                          foregroundColor: colorScheme.error,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text("छवि (Image) सहेजें",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context, FamilyMember member,
      ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: RepaintBoundary(
        key: _cardKeys[member.id],
        child: Card(
          elevation: 8,
          shadowColor: Colors.black26,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Red Accent Bar
              Container(
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header: Avatar & Name
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            member.name[0],
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              Text(
                                '${member.relation} • ${member.bloodGroup}', // Simplified bio
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 48, thickness: 1),
                    // Main Data: Blood Group & Diseases
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("रक्त समूह / BLOOD GROUP",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text(
                                member.bloodGroup,
                                style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        Container(
                            width: 1, height: 60, color: Colors.grey.shade200),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("बीमारियां / CONDITIONS",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: member.diseases
                                    .map((d) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.red.shade100),
                                          ),
                                          child: Text(d,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold)),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 48, thickness: 1),
                    // Contact Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("आपातकालीन संपर्क / EMERGENCY CONTACT",
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.grey.shade500,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text(
                              member.emergencyContactName ?? 'Contact',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                        FloatingActionButton(
                          onPressed: () => launchUrl(Uri.parse(
                              "tel:${member.emergencyPhone}")), // In a real app use emergency field
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          mini: true,
                          child: const Icon(Icons.call),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
