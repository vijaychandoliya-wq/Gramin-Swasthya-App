import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/family_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/medicines_provider.dart';
import '../../widgets/quick_add_sheet.dart';
import '../../widgets/global_search_delegate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  bool _isExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && _isExtended) {
      setState(() => _isExtended = false);
    } else if (_scrollController.offset <= 100 && !_isExtended) {
      setState(() => _isExtended = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final familyMembers = ref.watch(familyProvider);
    final selectedMember = ref.watch(selectedFamilyMemberProvider);
    final healthSummary = ref.watch(healthSummaryProvider);
    final todayMedicines = ref.watch(todayMedicinesProvider);
    final familyBranding = ref.watch(familyBrandingProvider);

    // --- Empty state ---
    if (familyMembers.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.family_restroom, size: 64, color: colorScheme.primary),
                ),
                const SizedBox(height: 24),
                Text('परिवार का सदस्य जोड़ें', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'शुरू करने के लिए अपना पहला सदस्य जोड़ें\nAdd your first family member to get started',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.push('/add-family-member'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('सदस्य जोड़ें / Add Member'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentMember = selectedMember ?? familyMembers.first;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddBottomSheet(context),
        isExtended: _isExtended,
        icon: const Icon(Icons.add_rounded),
        label: const Text('रिकॉर्ड जोड़ें'),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── AppBar with Family Branding ──
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            floating: false,
            backgroundColor: colorScheme.surface,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  familyBranding,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'नमस्ते, ${currentMember.name.split(' ').first}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              const GlobalSearchAnchor(),
              IconButton(
                icon: Badge(
                  label: Text(todayMedicines.where((m) => !m.isTaken).length.toString()),
                  isLabelVisible: todayMedicines.any((m) => !m.isTaken),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Family Member Chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: familyMembers.map((member) {
                    final isSelected = member.id == currentMember.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(member.name.split(' ').first),
                        avatar: CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                          child: Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (bool selected) {
                          if (selected) {
                            ref.read(selectedFamilyMemberProvider.notifier).state = member;
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Health Summary Cards ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'आज का स्वास्थ्य / Health Today',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _HealthMetricCard(
                          icon: Icons.monitor_heart_outlined,
                          title: 'BP',
                          value: healthSummary.latestBp,
                          subtitle: healthSummary.bpCategory,
                          accentColor: healthSummary.bpColor ?? Colors.redAccent,
                          onTap: () => context.push('/health?tab=bp'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HealthMetricCard(
                          icon: Icons.water_drop_outlined,
                          title: 'Sugar',
                          value: healthSummary.latestSugar,
                          accentColor: Colors.blueAccent,
                          onTap: () => context.push('/health?tab=sugar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HealthMetricCard(
                          icon: Icons.scale_outlined,
                          title: 'Weight',
                          value: healthSummary.latestWeight,
                          accentColor: Colors.teal,
                          onTap: () => context.push('/health?tab=weight'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Medicines Section ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'दवाइयाँ / Medicines',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (todayMedicines.isNotEmpty)
                        TextButton(
                          onPressed: () => context.go('/medicines'),
                          child: const Text('सभी देखें →'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (todayMedicines.isEmpty)
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      child: InkWell(
                        onTap: () => context.push('/add-medicine'),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.medication_outlined, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text(
                                'दवाई जोड़ें / Add Medicine',
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...todayMedicines.take(5).map((med) => _MedicineReminderTile(
                      reminder: med,
                      onMarkTaken: () {
                        ref.read(medicinesRepoProvider).markAsTaken(med.id);
                      },
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddBottomSheet(BuildContext context) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const QuickAddSheet(),
    );

    if (saved == true) {
      ref.invalidate(healthSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('रिकॉर्ड सफलतापूर्वक जोड़ा गया / Record Added')),
        );
      }
    }
  }
}

// ── M3 Health Metric Card ──
class _HealthMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _HealthMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEmpty = value == '--';

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with tinted container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── M3 Medicine Reminder Tile ──
class _MedicineReminderTile extends StatelessWidget {
  final MedicineReminder reminder;
  final VoidCallback onMarkTaken;

  const _MedicineReminderTile({
    required this.reminder,
    required this.onMarkTaken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: reminder.isTaken
          ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: reminder.isTaken
              ? Colors.green.withOpacity(0.3)
              : colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: reminder.isTaken
                ? Colors.green.withOpacity(0.1)
                : colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            reminder.isTaken ? Icons.check_circle : Icons.medication_outlined,
            color: reminder.isTaken ? Colors.green : colorScheme.primary,
          ),
        ),
        title: Text(
          reminder.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: reminder.isTaken ? TextDecoration.lineThrough : null,
            color: reminder.isTaken ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${reminder.dosage}  •  ${reminder.time}',
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: reminder.isTaken
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('ली गई', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
              )
            : FilledButton.tonal(
                onPressed: onMarkTaken,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('लें', style: TextStyle(fontSize: 13)),
              ),
      ),
    );
  }
}
