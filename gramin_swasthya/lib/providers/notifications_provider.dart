import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories of in-app activity, used to pick an icon/color in the UI.
enum AppNotificationType { medicine, bp, sugar, weight, report, backup, restore, general }

/// A single entry in the in-app notification / activity feed (the bell icon).
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final int timestamp; // millisecondsSinceEpoch
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'timestamp': timestamp,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String? ?? '',
        type: AppNotificationType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => AppNotificationType.general,
        ),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        timestamp: j['timestamp'] as int? ?? 0,
        isRead: j['isRead'] as bool? ?? false,
      );
}

/// Persists the activity feed in SharedPreferences (no DB migration needed) and
/// exposes it reactively so the bell badge and the Notifications screen update
/// live whenever something happens in the app.
class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super([]) {
    _load();
  }

  static const _key = 'app_notifications';
  static const _maxItems = 50;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = <AppNotification>[];
    for (final s in raw) {
      try {
        items.add(AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = items;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.map((n) => jsonEncode(n.toJson())).toList());
  }

  /// Record a new activity event. Newest first, capped to [_maxItems].
  Future<void> add({
    required AppNotificationType type,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = AppNotification(
      id: '$now-${state.length}-${title.hashCode}',
      type: type,
      title: title,
      body: body,
      timestamp: now,
    );
    var next = [entry, ...state];
    if (next.length > _maxItems) next = next.sublist(0, _maxItems);
    state = next;
    await _persist();
  }

  Future<void> markAllRead() async {
    if (state.every((n) => n.isRead)) return;
    state = [for (final n in state) n.copyWith(isRead: true)];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
  }

  Future<void> clearAll() async {
    state = [];
    await _persist();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
        (ref) => NotificationsNotifier());

/// Unread count for the bell badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});
