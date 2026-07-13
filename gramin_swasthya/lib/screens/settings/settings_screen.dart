import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/family_provider.dart';
import '../../services/google_drive_service.dart';
import '../../db/database_helper.dart';
import '../../l10n/app_language.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifEnabled = true;
  String _lastSynced = "आज, 10:30 AM";

  bool _isGoogleLinked = false;
  String? _googleUserEmail;
  List<Map<String, String>> _googleBackupFolders = [];
  bool _isLoadingBackups = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final linked = await GoogleDriveService.instance.isSignedIn();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _isGoogleLinked = linked;
      _googleUserEmail = GoogleDriveService.instance.currentUser?.email;
    });
    if (linked) {
      _fetchGoogleBackups();
    }
  }

  Future<void> _toggleNotif(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', val);
    setState(() => _notifEnabled = val);
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
        const SnackBar(
            content: LocalizedText(
                'Google खाता हटाया गया / Google account unlinked')),
      );
    } else {
      final account = await GoogleDriveService.instance.signIn();
      if (!mounted) return;
      if (account != null) {
        setState(() {
          _isGoogleLinked = true;
          _googleUserEmail = account.email;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: LocalizedText(
                  'Google खाता जोड़ा गया / Google account linked')),
        );
        _fetchGoogleBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  LocalizedText('लिंक करने में विफल / Failed to link account')),
        );
      }
    }
  }

  Future<void> _fetchGoogleBackups() async {
    setState(() => _isLoadingBackups = true);
    try {
      final folders = await GoogleDriveService.instance.listBackupFolders();
      setState(() {
        _googleBackupFolders = folders;
      });
    } catch (e) {
      debugPrint("Failed to fetch backups: $e");
    } finally {
      setState(() => _isLoadingBackups = false);
    }
  }

  Future<void> _backupToGoogle() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: LocalizedText(
              'गूगल ड्राइव पर बैकअप हो रहा है... / Uploading backup to Drive...')),
    );
    try {
      await GoogleDriveService.instance.backupProfiles(context);
      _fetchGoogleBackups();
      if (mounted) {
        setState(() => _lastSynced = "अभी-अभी / Just now");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: LocalizedText('बैकअप पूरा हुआ! / Backup completed ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: LocalizedText('बैकअप त्रुटि: $e / Backup failed: $e')),
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
          title: const LocalizedText('कोई बैकअप नहीं / No Backups'),
          content: const LocalizedText(
              'गूगल ड्राइव पर कोई भी प्रोफाइल बैकअप नहीं मिला। / No profile backups found on Google Drive.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LocalizedText('ठीक है / OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText('प्रोफ़ाइल आयात करें / Import Profile'),
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
                      title: LocalizedText(folder['name'] ?? ''),
                      subtitle: const LocalizedText(
                          'गूगल ड्राइव से आयात करें / Import from Drive'),
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
            child: const LocalizedText('रद्द / Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFolder(String folderId, String profileName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: LocalizedText(
              '$profileName आयात किया जा रहा है... / Importing $profileName...')),
    );
    try {
      await GoogleDriveService.instance.importProfile(folderId);
      ref.invalidate(familyProvider);
      ref.invalidate(selectedFamilyMemberProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: LocalizedText(
                  '$profileName सफलतापूर्वक आयात किया गया! / Imported successfully ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: LocalizedText('आयात त्रुटि: $e / Import failed: $e')),
        );
      }
    }
  }

  Future<void> _eraseAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText('सभी डेटा हटाएं? / Erase All Data?'),
        content: const LocalizedText(
          'क्या आप वाकई सभी डेटा हटाना चाहते हैं? यह क्रिया आपके फ़ोन से सभी प्रोफ़ाइल, स्वास्थ्य रिकॉर्ड और दवाइयों की सूची को स्थायी रूप से हटा देगी।\n\nAre you sure you want to delete all data? This will permanently erase all profiles, records, and medicines from your phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalizedText('रद्द / Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('सब कुछ हटाएं / Erase All'),
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
          const SnackBar(
              content: LocalizedText(
                  'सभी डेटा मिटा दिया गया है / All data has been erased')),
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
        title: const LocalizedText('भाषा चुनें / Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'hi',
              groupValue: current,
              title: const LocalizedText('हिंदी (Hindi)'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              title: const LocalizedText('English'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LocalizedText('रद्द / Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      await AppLanguage.setLanguage(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: LocalizedText('भाषा बदल दी गई / Language changed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryMember = ref.watch(familyProvider).firstWhere(
        (m) => m.isPrimary,
        orElse: () => ref.read(familyProvider).first);

    return Scaffold(
      appBar: AppBar(
        title: const LocalizedText('सेटिंग्स / Settings'),
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
                      backgroundImage: primaryMember.photoUrl != null
                          ? NetworkImage(primaryMember.photoUrl!)
                          : null,
                      child: primaryMember.photoUrl == null
                          ? LocalizedText(primaryMember.name[0],
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            primaryMember.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          LocalizedText(
                            primaryMember.phone != null
                                ? '+91 ${primaryMember.phone}'
                                : (primaryMember.email ?? ''),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant),
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
                title: const LocalizedText("ऐप की भाषा / Language"),
                subtitle: LocalizedText(
                  AppLanguage.current.value == 'hi' ? 'हिंदी' : 'English',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const LocalizedText("दवाई अनुस्मारक / Reminders"),
                subtitle:
                    const LocalizedText("दवाइयों के लिए सूचनाएं प्राप्त करें"),
                value: _notifEnabled,
                onChanged: _toggleNotif,
              ),
            ],
            colorScheme,
          ),

          _buildSection(
            "क्लाउड बैकअप / Cloud Backup",
            [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title:
                    const LocalizedText("गूगल ड्राइव लिंक / Google Drive Link"),
                subtitle: LocalizedText(_isGoogleLinked
                    ? "संबद्ध / Linked: $_googleUserEmail"
                    : "बैकअप के लिए साइन इन करें / Sign in to backup"),
                trailing: LocalizedText(
                  _isGoogleLinked ? "हटाएं / Unlink" : "लिंक करें / Link",
                  style: TextStyle(
                    color: _isGoogleLinked
                        ? colorScheme.error
                        : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _toggleGoogleLink,
              ),
              if (_isGoogleLinked) ...[
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const LocalizedText(
                      "गूगल ड्राइव बैकअप / Google Drive Backup"),
                  subtitle: LocalizedText("पिछला बैकअप: $_lastSynced"),
                  trailing: IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: _backupToGoogle,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const LocalizedText(
                      "प्रोफ़ाइल आयात करें / Import Profile"),
                  subtitle:
                      const LocalizedText("गूगल ड्राइव से प्रोफ़ाइल बहाल करें"),
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
                title: const LocalizedText("ऐप वर्शन / Version"),
                trailing:
                    LocalizedText("v1.0.0", style: theme.textTheme.bodySmall),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: "   ग्रामीण स्वास्थ्य",
                  applicationVersion: "1.0.0",
                  applicationIcon: SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: 48,
                    width: 48,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const LocalizedText("गोपनीयता नीति / Privacy"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    launchUrl(Uri.parse("https://graminsw.app/privacy")),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const LocalizedText("मदद / Help"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => launchUrl(Uri.parse("https://graminsw.app/help")),
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
            label: const LocalizedText("सब कुछ मिटाएं / Erase All Data",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, List<Widget> tiles, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: LocalizedText(
            title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
                if (i < tiles.length - 1) const Divider(height: 0, indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
