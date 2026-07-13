import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/localized_text.dart';
import '../../providers/medicines_provider.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(medicinesStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const LocalizedText('सूचनाएँ / Notifications'),
      ),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: LocalizedText(
              'सूचनाएँ लोड नहीं हो सकीं / Unable to load notifications'),
        ),
        data: (medicines) {
          final active =
              medicines.where((medicine) => medicine.isActive).toList();
          if (active.isEmpty) {
            return const _EmptyNotifications();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final medicine = active[index];
              final times = medicine.times
                  .map((time) => DateFormat('h:mm a').format(DateTime(
                        2000,
                        1,
                        1,
                        time.hour,
                        time.minute,
                      )))
                  .join(', ');
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: LocalizedText(medicine.name),
                  subtitle: Text(
                    '${medicine.dosage} ${medicine.unit} • $times',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            const LocalizedText(
              'कोई सक्रिय सूचना नहीं / No active notifications',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
