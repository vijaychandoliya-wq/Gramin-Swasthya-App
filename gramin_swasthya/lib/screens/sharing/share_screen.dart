import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/family_provider.dart';

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final Map<String, bool> _sharedTypes = {
    'BP इतिहास': false,
    'शुगर इतिहास': false,
    'वजन इतिहास': false,
    'मेडिकल रिपोर्ट': false,
  };

  int _expiryDays = 3;
  bool _isGenerating = false;

  bool get _canGenerate => _sharedTypes.values.any((v) => v);

  Future<void> _generateQR() async {
    if (!_canGenerate) return;

    setState(() => _isGenerating = true);

    try {
      final selectedMember = ref.read(selectedFamilyMemberProvider);
      if (selectedMember == null) return;

      final tokenId = const Uuid().v4();
      final expiryDate = DateTime.now().add(Duration(days: _expiryDays));

      final selectedList = _sharedTypes.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFirestore.instance.collection('shares').doc(tokenId).set({
        'memberId': selectedMember.id,
        'memberName': selectedMember.name,
        'dataTypes': selectedList,
        'expiry': Timestamp.fromDate(expiryDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.push('/share/qr', extra: tokenId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _revokeShare(String tokenId) async {
    try {
      await FirebaseFirestore.instance.collection('shares').doc(tokenId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('लिंक हटा दिया गया / Link Revoked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMember = ref.watch(selectedFamilyMemberProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('डॉक्टर को शेयर करें / Share'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Member Card
            if (selectedMember != null)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Text(selectedMember.name.isNotEmpty ? selectedMember.name[0] : '?', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(selectedMember.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${selectedMember.relation} • Blood: ${selectedMember.bloodGroup}'),
                  trailing: TextButton(
                    onPressed: () => _showMemberPicker(context, ref),
                    child: const Text('बदलें (Change)'),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Section 2: Data Selection
            Text('क्या शेयर करें / What to Share', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._sharedTypes.keys.map((type) => CheckboxListTile(
                  title: Text(type),
                  secondary: Icon(_getIconForType(type), color: colorScheme.primary),
                  value: _sharedTypes[type],
                  onChanged: (val) => setState(() => _sharedTypes[type] = val!),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                )),

            const SizedBox(height: 24),

            // Section 3: Expiry
            Text('लिंक की वैधता / Link Validity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1 दिन')),
                ButtonSegment(value: 3, label: Text('3 दिन')),
                ButtonSegment(value: 7, label: Text('7 दिन')),
              ],
              selected: {_expiryDays},
              onSelectionChanged: (val) => setState(() => _expiryDays = val.first),
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: (_canGenerate && !_isGenerating) ? _generateQR : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isGenerating 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('QR कोड बनाएं / Generate QR', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 48),

            // Section 4: Active Shares
            Text('सक्रिय रिंक / Active Links', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (selectedMember != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shares')
                    .where('memberId', isEqualTo: selectedMember.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('कोई सक्रिय लिंक नहीं / No active links', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final expiry = (data['expiry'] as Timestamp).toDate();
                      final isExpired = expiry.isBefore(DateTime.now());

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          title: Text('लिंक ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('समाप्ति: ${DateFormat('dd MMM, hh:mm a').format(expiry)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isExpired ? colorScheme.surfaceContainerHighest : colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(isExpired ? "समाप्त" : "सक्रिय", style: const TextStyle(fontSize: 10)),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.link_off, color: colorScheme.onSurfaceVariant),
                                onPressed: () => _revokeShare(doc.id),
                                tooltip: 'Revoke Link',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'BP इतिहास': return Icons.monitor_heart;
      case 'शुगर इतिहास': return Icons.bloodtype;
      case 'वजन इतिहास': return Icons.scale;
      case 'मेडिकल रिपोर्ट': return Icons.folder;
      default: return Icons.share;
    }
  }

  void _showMemberPicker(BuildContext context, WidgetRef ref) {
    final members = ref.read(familyProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('सदस्य चुनें / Select Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...members.map((m) => ListTile(
              leading: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0] : '?')),
              title: Text(m.name),
              onTap: () {
                ref.read(selectedFamilyMemberProvider.notifier).state = m;
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
