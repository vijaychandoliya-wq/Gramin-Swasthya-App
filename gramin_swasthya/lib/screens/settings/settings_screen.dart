import 'package:flutter/material.dart';
import '../../utils/snackbar_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/family_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../services/google_drive_service.dart';
import '../../db/database_helper.dart';

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

  bool _isGoogleLinked = false;
  String? _googleUserEmail;
  List<Map<String, String>> _googleBackupFolders = [];
  bool _isLoadingBackups = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final linked = await GoogleDriveService.instance.isSignedIn();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _isGoogleLinked = linked;
      _googleUserEmail = GoogleDriveService.instance.currentUser?.email;
    });
    if (linked) {
      _fetchGoogleBackups();
    }
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

  Future<void> _toggleGoogleLink() async {
    if (_isGoogleLinked) {
      await GoogleDriveService.instance.signOut();
      if (!mounted) return;
      setState(() {
        _isGoogleLinked = false;
        _googleUserEmail = null;
        _googleBackupFolders = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google खाता हटाया गया / Google account unlinked')),
      );
    } else {
      try {
        final account = await GoogleDriveService.instance.signIn();
        if (!mounted) return;
        if (account != null) {
          setState(() {
            _isGoogleLinked = true;
            _googleUserEmail = account.email;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google खाता जोड़ा गया / Google account linked')),
          );
          _fetchGoogleBackups();
        } else {
          // account == null means the user dismissed the picker.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लिंक रद्द किया गया / Linking cancelled')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        // Surface the real failure (e.g. DEVELOPER_ERROR / ApiException: 10 when
        // the signing SHA-1 isn't registered in Firebase) instead of a generic
        // message, so the problem is diagnosable.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('लिंक करने में विफल / Failed to link: $e')),
        );
      }
    }
  }

  Future<void> _fetchGoogleBackups() async {
    if (!mounted) return;
    setState(() => _isLoadingBackups = true);
    try {
      final folders = await GoogleDriveService.instance.listBackupFolders();
      if (!mounted) return;
      setState(() {
        _googleBackupFolders = folders;
      });
    } catch (e) {
      debugPrint("Failed to fetch backups: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBackups = false);
    }
  }

  /// Restores ALL profiles + their data from Google Drive into local SQLite.
  /// Per the chosen behavior this only runs when the phone has no profiles yet
  /// (so it's safe right after a reinstall and never creates duplicates).
  Future<void> _loadAllFromGoogle() async {
    // Make sure we're signed in first (a fresh install won't be linked yet).
    if (!_isGoogleLinked) {
      try {
        final account = await GoogleDriveService.instance.signIn();
        if (!mounted) return;
        if (account == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लिंक रद्द किया गया / Linking cancelled')),
          );
          return;
        }
        setState(() {
          _isGoogleLinked = true;
          _googleUserEmail = account.email;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('लिंक करने में विफल / Failed to link: $e')),
        );
        return;
      }
    }

    // Only restore into an empty phone, to avoid duplicating existing data.
    if (ref.read(familyProvider).isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('डेटा पहले से मौजूद है / Data already present'),
          content: const Text(
              'आपके फ़ोन में पहले से प्रोफ़ाइल मौजूद हैं, इसलिए डुप्लिकेट से बचने के लिए लोड नहीं किया गया। एक विशिष्ट प्रोफ़ाइल लाने के लिए "प्रोफ़ाइल आयात करें" का उपयोग करें।\n\nThis phone already has profiles, so a full restore was skipped to avoid duplicates. Use "Import Profile" to fetch a specific one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ठीक है / OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('गूगल ड्राइव से डेटा लोड हो रहा है... / Loading data from Drive...')),
    );
    try {
      final count = await GoogleDriveService.instance.importAllProfiles();
      ref.invalidate(familyProvider);
      ref.invalidate(selectedFamilyMemberProvider);
      if (!mounted) return;
      if (count > 0) {
        ref.read(notificationsProvider.notifier).add(
          type: AppNotificationType.restore,
          title: 'डेटा बहाल किया गया / Data restored',
          body: '$count प्रोफ़ाइल / profiles from Google Drive',
        );
        showSuccessSnackBar(context, '$count प्रोफ़ाइल लोड हुईं / profiles restored');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('कोई बैकअप नहीं मिला / No backup found on Drive')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('लोड करने में विफल / Restore failed: $e')),
      );
    }
  }

  Future<void> _backupToGoogle() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('गूगल ड्राइव पर बैकअप हो रहा है... / Uploading backup to Drive...')),
    );
    try {
      await GoogleDriveService.instance.backupProfiles(context);
      _fetchGoogleBackups();
      if (mounted) {
        setState(() => _lastSynced = "अभी-अभी / Just now");
        ref.read(notificationsProvider.notifier).add(
          type: AppNotificationType.backup,
          title: 'बैकअप पूरा हुआ / Backup completed',
          body: 'Google Drive',
        );
        showSuccessSnackBar(context, 'बैकअप पूरा हुआ! / Backup completed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('बैकअप त्रुटि: $e / Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _showImportDialog() async {
    if (_googleBackupFolders.isEmpty) {
      await _fetchGoogleBackups();
    }
    
    if (!mounted) return;
    
    if (_googleBackupFolders.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('कोई बैकअप नहीं / No Backups'),
          content: const Text('गूगल ड्राइव पर कोई भी प्रोफाइल बैकअप नहीं मिला। / No profile backups found on Google Drive.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ठीक है / OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('प्रोफ़ाइल आयात करें / Import Profile'),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoadingBackups
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _googleBackupFolders.length,
                  itemBuilder: (context, index) {
                    final folder = _googleBackupFolders[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(folder['name'] ?? ''),
                      subtitle: const Text('गूगल ड्राइव से आयात करें / Import from Drive'),
                      onTap: () async {
                        Navigator.pop(context);
                        _importFolder(folder['id']!, folder['name']!);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द / Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFolder(String folderId, String profileName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$profileName आयात किया जा रहा है... / Importing $profileName...')),
    );
    try {
      await GoogleDriveService.instance.importProfile(folderId);
      ref.invalidate(familyProvider);
      ref.invalidate(selectedFamilyMemberProvider);
      if (mounted) {
        showSuccessSnackBar(context, '$profileName सफलतापूर्वक आयात किया गया! / Imported successfully');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('आयात त्रुटि: $e / Import failed: $e')),
        );
      }
    }
  }

  Future<void> _eraseAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('सभी डेटा हटाएं? / Erase All Data?'),
        content: const Text(
          'क्या आप वाकई सभी डेटा हटाना चाहते हैं? यह क्रिया आपके फ़ोन से सभी प्रोफ़ाइल, स्वास्थ्य रिकॉर्ड और दवाइयों की सूची को स्थायी रूप से हटा देगी।\n\nAre you sure you want to delete all data? This will permanently erase all profiles, records, and medicines from your phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('रद्द / Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('सब कुछ हटाएं / Erase All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.eraseAllData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Invalidate local providers
      ref.invalidate(familyProvider);
      ref.invalidate(selectedFamilyMemberProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सभी डेटा मिटा दिया गया है / All data has been erased')),
        );
        context.go('/splash');
      }
    }
  }

  Future<void> _showLanguageDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String current = prefs.getString('language') ?? 'hi';

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
              groupValue: current,
              title: const Text('हिंदी (Hindi)'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
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
      await prefs.setString('language', selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('भाषा बदल दी गई / Language changed')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('लिंक नहीं खोल सका / Could not open link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('लिंक नहीं खोल सका / Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final family = ref.watch(familyProvider);
    // Don't call .first inside orElse — it throws StateError when the family
    // list is empty. Resolve to a nullable member and fall back gracefully.
    final primaryMember = family.where((m) => m.isPrimary).isNotEmpty
        ? family.firstWhere((m) => m.isPrimary)
        : (family.isNotEmpty ? family.first : null);

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
                      child: Text((primaryMember == null || primaryMember.name.isEmpty) ? '?' : primaryMember.name[0], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "चंदोलिया परिवार / Chandoliya Family",
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "+91 ••••• 54321", // Mock masked phone
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
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
                subtitle: const Text("हिन्दी (Hindi)"),
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
            "क्लाउड बैकअप / Cloud Backup",
            [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text("गूगल ड्राइव लिंक / Google Drive Link"),
                subtitle: Text(_isGoogleLinked
                    ? "संबद्ध / Linked: $_googleUserEmail"
                    : "बैकअप के लिए साइन इन करें / Sign in to backup"),
                trailing: Text(
                  _isGoogleLinked ? "हटाएं / Unlink" : "लिंक करें / Link",
                  style: TextStyle(
                    color: _isGoogleLinked ? colorScheme.error : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _toggleGoogleLink,
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text("गूगल ड्राइव से डेटा लोड करें / Load data from Google Drive"),
                subtitle: const Text("नए फ़ोन/इंस्टॉल पर सारा पुराना डेटा बहाल करें"),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loadAllFromGoogle,
              ),
              if (_isGoogleLinked) ...[
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text("गूगल ड्राइव बैकअप / Google Drive Backup"),
                  subtitle: Text("पिछला बैकअप: $_lastSynced"),
                  trailing: IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: _backupToGoogle,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text("प्रोफ़ाइल आयात करें / Import Profile"),
                  subtitle: const Text("गूगल ड्राइव से प्रोफ़ाइल बहाल करें"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showImportDialog,
                ),
              ],
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
                onTap: () => _openUrl("https://graminsw.app/privacy"),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text("मदद / Help"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openUrl("https://graminsw.app/help"),
              ),
            ],
            colorScheme,
          ),

          const SizedBox(height: 24),

          TextButton.icon(
            onPressed: _eraseAllData,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text("सब कुछ मिटाएं / Erase All Data", style: TextStyle(fontWeight: FontWeight.bold)),
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
