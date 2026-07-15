import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';

import '../../providers/family_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, FamilyMember member) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('${member.name} को हटाएं?'),
        content: const LocalizedText(
            'क्या आप वाकई इस प्रोफाइल को हटाना चाहते हैं? इससे उनका सारा स्वास्थ्य डेटा भी हट जाएगा।\nWarning: This will delete all associated health data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalizedText('रद्द / Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const LocalizedText('हटाएं / Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(familyProvider.notifier).deleteMember(member.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('${member.name} को हटा दिया गया')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final members = ref.watch(familyProvider);

    final primary = members.isEmpty
        ? null
        : members.firstWhere((m) => m.isPrimary, orElse: () => members.first);
    final nameParts = primary?.name.trim().split(RegExp(r'\s+')) ?? const [];
    final lastName = nameParts.length > 1 ? nameParts.last : null;
    final familyName = lastName == null
        ? AppLanguage.text('Family')
        : '$lastName परिवार / $lastName Family';

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-family-member'),
        backgroundColor: colorScheme.primaryContainer,
        child: const Icon(Icons.person_add_alt),
      ),
      body: CustomScrollView(
        slivers: [
          // --- SliverAppBar ---
          SliverAppBar.medium(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: LocalizedText(
                familyName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(color: colorScheme.surface),
            ),
          ),

          // --- Member List ---
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildMemberCard(
                      context, ref, theme, colorScheme, member),
                );
              },
            ),
          ),

          // Extra padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, WidgetRef ref, ThemeData theme,
      ColorScheme colorScheme, FamilyMember member) {
    final initials = member.name.isNotEmpty ? member.name[0] : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.push('/add-family-member', extra: member),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar with Hero
              Hero(
                tag: 'avatar_${member.id}',
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: member.isPrimary
                      ? colorScheme.primary
                      : colorScheme.primaryContainer,
                  child: member.photoPath != null
                      ? ClipOval(
                          child: Image.file(
                            File(member.photoPath!),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                      : member.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                member.photoUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            )
                          : LocalizedText(
                              initials,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: member.isPrimary
                                    ? colorScheme.onPrimary
                                    : colorScheme.onPrimaryContainer,
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LocalizedText(
                          member.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (member.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const LocalizedText("मुख्य",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    LocalizedText(
                      "${member.age} वर्ष · ${member.gender} · ${member.bloodGroup}",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    // Diseases
                    if (member.diseases.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...member.diseases
                              .take(2)
                              .map((d) => _buildMiniChip(d, colorScheme)),
                          if (member.diseases.length > 2)
                            _buildMiniChip(
                                "+${member.diseases.length - 2} अधिक",
                                colorScheme,
                                isOverflow: true),
                        ],
                      ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                      context.push('/add-family-member', extra: member);
                      break;
                    case 'emergency':
                      context.push('/emergency-card');
                      break;
                    case 'delete':
                      _confirmDelete(context, ref, member);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: LocalizedText('संपादित करें / Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'emergency',
                    child: ListTile(
                      leading: Icon(Icons.emergency_outlined,
                          color: colorScheme.error),
                      title: LocalizedText('आपातकालीन कार्ड',
                          style: TextStyle(color: colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading:
                          Icon(Icons.delete_outline, color: colorScheme.error),
                      title: LocalizedText('हटाएं / Delete',
                          style: TextStyle(color: colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, ColorScheme colorScheme,
      {bool isOverflow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverflow
            ? colorScheme.surfaceContainerHighest
            : colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LocalizedText(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isOverflow
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
