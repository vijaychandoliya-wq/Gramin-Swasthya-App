import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/family_provider.dart';
import '../../providers/language_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _notifEnabled = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _lastSynced = "आज, 10:30 AM";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      setState(() => _biometricAvailable = canCheck && isSupported);
    } catch (e) {
      debugPrint("Biometric check error: $e");
    }
  }

  Future<void> _toggleNotif(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', val);
    setState(() => _notifEnabled = val);
  }

  Future<void> _toggleBiometric(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', val);
    setState(() => _biometricEnabled = val);
  }

  Future<void> _manualSync() async {
    // Mock sync
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('डेटा बैकअप हो रहा है... / Syncing data...')),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _lastSynced = "अभी-अभी / Just now");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('बैकअप सफल! / Backup successful ✓')),
      );
    }
  }

  Future<void> _showLanguageDialog() async {
    final currentCode = ref.read(languageProvider).languageCode;

    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('भाषा चुनें / Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'hi',
              groupValue: currentCode,
              title: const Text('हिंदी (Hindi)'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: currentCode,
              title: const Text('English'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द / Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      await ref.read(languageProvider.notifier).setLanguage(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('भाषा बदल दी गई / Language changed')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('लॉग आउट करें? / Logout?'),
        content: const Text('क्या आप वाकई लॉग आउट करना चाहते हैं? आपका डेटा सुरक्षित रहेगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('लॉग आउट'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);
      if (mounted) context.go('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final members = ref.watch(familyProvider);
    final currentLangCode = ref.watch(languageProvider).languageCode;
    final langSubtitle = currentLangCode == 'en' ? 'English' : 'हिन्दी (Hindi)';

    if (members.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final primaryMember = members.firstWhere((m) => m.isPrimary, orElse: () => members.first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('सेटिंग्स / Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Account Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              onTap: () => context.push('/family'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(primaryMember.name[0], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryMember.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${primaryMember.age} वर्ष · ${primaryMember.bloodGroup} · ${primaryMember.gender}",
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                      tooltip: 'प्रोफाइल संपादित करें',
                      onPressed: () => context.push('/add-family-member', extra: primaryMember),
                    ),
                    Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          _buildSection(
            "प्राथमिकताएँ / Preferences",
            [
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: const Text("ऐप की भाषा / Language"),
                subtitle: Text(langSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text("दवाई अनुस्मारक / Reminders"),
                subtitle: const Text("दवाइयों के लिए सूचनाएं प्राप्त करें"),
                value: _notifEnabled,
                onChanged: _toggleNotif,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text("फिंगरप्रिंट लॉगिन"),
                subtitle: Text(_biometricAvailable ? "सुरक्षित लॉगिन के लिए" : "उपलब्ध नहीं है"),
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
              ),
            ],
            colorScheme,
          ),

          _buildSection(
            "सुरक्षा और डेटा / Security",
            [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text("PIN बदलें / Change PIN"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/pin-setup'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text("डेटा बैकअप / Sync"),
                subtitle: Text("पिछला बैकअप: $_lastSynced"),
                trailing: IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _manualSync,
                ),
              ),
            ],
            colorScheme,
          ),

          _buildSection(
            "ऐप के बारे में / About App",
            [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("ऐप वर्शन / Version"),
                trailing: Text("v1.0.0", style: theme.textTheme.bodySmall),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: "ग्रामीण स्वास्थ्य",
                  applicationVersion: "1.0.0",
                ),
              ),
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text("गोपनीयता नीति / Privacy"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => launchUrl(Uri.parse("https://graminsw.app/privacy")),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text("मदद / Help"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => launchUrl(Uri.parse("https://graminsw.app/help")),
              ),
            ],
            colorScheme,
          ),

          const SizedBox(height: 24),

          TextButton.icon(
            onPressed: _logout,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.logout),
            label: const Text("लॉग आउट / Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  const Divider(height: 0, indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
