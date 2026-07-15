import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/family_provider.dart';
import '../l10n/localized_text.dart';

/// One consistent, horizontally scrollable family selector used by all tabs.
class FamilyMemberSelector extends ConsumerWidget {
  const FamilyMemberSelector(
      {super.key, this.padding = const EdgeInsets.all(16)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyProvider);
    final selected = ref.watch(selectedFamilyMemberProvider);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: ValueKey('member_chip_${member.id}'),
                selected: member.id == selected?.id,
                showCheckmark: false,
                avatar: CircleAvatar(
                  radius: 14,
                  backgroundColor: member.id == selected?.id
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    member.name.trim().isEmpty
                        ? '?'
                        : member.name.trim()[0].toUpperCase(),
                    style: TextStyle(
                      color: member.id == selected?.id
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                label: LocalizedText(member.name.split(' ').first),
                onSelected: (_) => ref
                    .read(selectedFamilyMemberProvider.notifier)
                    .state = member,
              ),
            ),
        ],
      ),
    );
  }
}
