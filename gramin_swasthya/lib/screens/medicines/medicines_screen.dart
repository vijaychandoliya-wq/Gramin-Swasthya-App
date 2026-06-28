import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/family_provider.dart';
import '../../providers/medicines_provider.dart';

class MedicinesScreen extends ConsumerStatefulWidget {
  const MedicinesScreen({super.key});

  @override
  ConsumerState<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends ConsumerState<MedicinesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 50 && _isFabExtended) {
      setState(() => _isFabExtended = false);
    } else if (_scrollController.offset <= 50 && !_isFabExtended) {
      setState(() => _isFabExtended = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final familyMembers = ref.watch(familyProvider);
    final selectedMember = ref.watch(selectedFamilyMemberProvider) ?? 
                          (familyMembers.isNotEmpty ? familyMembers.first : null);
    
    final medicinesAsync = ref.watch(filteredMedicinesProvider(selectedMember?.id));
    final adherence = ref.watch(dailyAdherenceProvider(selectedMember?.id));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-medicine'),
        icon: const Icon(Icons.add),
        label: const Text('दवाई जोड़ें / Add Med'),
        isExtended: _isFabExtended,
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // --- AppBar ---
          const SliverAppBar.medium(
            centerTitle: true,
            title: Text('दवाइयाँ / Medicines'),
            pinned: true,
          ),

          // --- Member Picker ---
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: familyMembers.map((member) {
                  final isSelected = member.id == selectedMember?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelected ? colorScheme.onPrimaryContainer : colorScheme.outline,
                        child: Text(member.name.isNotEmpty ? member.name[0] : '?', style: TextStyle(fontSize: 10, color: isSelected ? colorScheme.primaryContainer : colorScheme.surface)),
                      ),
                      label: Text(member.name.split(' ').first),
                      onSelected: (val) {
                        if (val) ref.read(selectedFamilyMemberProvider.notifier).state = member;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // --- Adherence Card ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAdherenceCard(theme, colorScheme, adherence),
            ),
          ),

          // --- Medicine List ---
          medicinesAsync.when(
            data: (medicines) {
              if (medicines.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('कोई दवाई नहीं / No Medicines'),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final med = medicines[index];
                      return _buildMedicineItem(context, ref, theme, colorScheme, med);
                    },
                    childCount: medicines.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ))),
            error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard(ThemeData theme, ColorScheme colorScheme, AdherenceData adherence) {
    final bool allTaken = adherence.total > 0 && adherence.taken == adherence.total;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Donut Chart
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 64,
                  width: 64,
                  child: CircularProgressIndicator(
                    value: adherence.fraction,
                    strokeWidth: 8,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${adherence.taken}/${adherence.total}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Progress Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'आज की दवाइयाँ / Today\'s Meds',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allTaken 
                      ? 'शाबाश! सभी ली गईं ✓ / Well done!' 
                      : '${adherence.total - adherence.taken} बाकी हैं / remaining',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: allTaken ? Colors.green : colorScheme.onSurfaceVariant,
                      fontWeight: allTaken ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineItem(
    BuildContext context, 
    WidgetRef ref, 
    ThemeData theme, 
    ColorScheme colorScheme, 
    Medicine med
  ) {
    return Dismissible(
      key: Key(med.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('दवाई हटाएं? / Delete Medicine?'),
            content: const Text('क्या आप इसे हटाना चाहते हैं? रिमाइंडर्स बंद हो जाएंगे।\nAre you sure you want to delete this medication? Reminders will be cancelled.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('वापस / Back')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('हटाएं / Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(medicinesRepoProvider).deleteMedicine(med.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${med.name} हटा दी गई / Deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => ref.read(medicinesRepoProvider).addMedicine(med),
            ),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.error),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Medicine Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.medication, size: 32, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              // Name & Dose
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${med.dosage} ${med.unit}',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    // Times
                    Wrap(
                      spacing: 4,
                      children: med.times.map((t) {
                        final timeStr = _formatTime(context, t);
                        // Check if taken today (simplified mock check)
                        final isTaken = med.takenHistory.any((dt) => 
                          dt.hour == t.hour && dt.minute == t.minute && _isToday(dt)
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isTaken ? Colors.green.withOpacity(0.1) : colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: isTaken ? Border.all(color: Colors.green.withOpacity(0.5)) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTaken) const Icon(Icons.check, size: 12, color: Colors.green),
                              if (isTaken) const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isTaken ? Colors.green : colorScheme.onSecondaryContainer,
                                  fontWeight: isTaken ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Toggle & Action
              Column(
                children: [
                  Switch(
                    value: med.isActive,
                    onChanged: (_) => ref.read(medicinesRepoProvider).toggleActive(med.id),
                    activeColor: colorScheme.primary,
                  ),
                  IconButton(
                    onPressed: med.isActive ? () => ref.read(medicinesRepoProvider).markAsTaken(med.id) : null,
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Mark as Taken',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}
