import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notifications_provider.dart';

/// In-app activity feed shown from the home bell icon. Pure Material 3:
/// AppBar actions, ListTile rows, tonal unread highlight, Dismissible to delete.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('सूचनाएँ / Notifications'),
        centerTitle: true,
        actions: [
          if (items.any((n) => !n.isRead))
            IconButton(
              tooltip: 'सभी पढ़ी हुई / Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: notifier.markAllRead,
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'सभी साफ़ करें / Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, notifier),
            ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyState(colorScheme: colorScheme, theme: theme)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
              itemBuilder: (context, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => notifier.remove(n.id),
                  child: ListTile(
                    tileColor: n.isRead ? null : colorScheme.primaryContainer.withOpacity(0.18),
                    leading: CircleAvatar(
                      backgroundColor: _typeColor(n.type, colorScheme).withOpacity(0.15),
                      foregroundColor: _typeColor(n.type, colorScheme),
                      child: Icon(_typeIcon(n.type)),
                    ),
                    title: Text(
                      n.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(n.body),
                    trailing: Text(
                      _relativeTime(n.timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, NotificationsNotifier notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('सभी सूचनाएँ हटाएं? / Clear all?'),
        content: const Text('सभी सूचनाएँ स्थायी रूप से हटा दी जाएंगी।\nThis removes all notifications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द / Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('हटाएं / Clear')),
        ],
      ),
    );
    if (ok == true) notifier.clearAll();
  }

  static IconData _typeIcon(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.medicine:
        return Icons.medication_outlined;
      case AppNotificationType.bp:
        return Icons.monitor_heart_outlined;
      case AppNotificationType.sugar:
        return Icons.water_drop_outlined;
      case AppNotificationType.weight:
        return Icons.monitor_weight_outlined;
      case AppNotificationType.report:
        return Icons.description_outlined;
      case AppNotificationType.backup:
        return Icons.cloud_done_outlined;
      case AppNotificationType.restore:
        return Icons.cloud_download_outlined;
      case AppNotificationType.general:
        return Icons.notifications_outlined;
    }
  }

  static Color _typeColor(AppNotificationType t, ColorScheme cs) {
    switch (t) {
      case AppNotificationType.bp:
      case AppNotificationType.medicine:
        return cs.primary;
      case AppNotificationType.report:
      case AppNotificationType.backup:
      case AppNotificationType.restore:
        return cs.tertiary;
      default:
        return cs.secondary;
    }
  }

  static String _relativeTime(int ms) {
    if (ms == 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'अभी / now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  const _EmptyState({required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'कोई सूचना नहीं / No notifications yet',
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ऐप में होने वाली गतिविधियाँ यहाँ दिखेंगी',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
