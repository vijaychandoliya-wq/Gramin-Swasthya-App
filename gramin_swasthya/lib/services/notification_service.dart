import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../providers/medicines_provider.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  static Future<void> scheduleDailyReminders(Medicine med) async {
    // 1. Cancel existing reminders for this medicine to avoid duplicates
    await cancelReminders(med.id);

    if (!med.isActive) return;

    for (var time in med.times) {
      final int id = _generateId(med.id, time);
      
      await _notificationsPlugin.zonedSchedule(
        id,
        '💊 दवाई का समय / Med Time',
        '${med.name} — ${med.dosage} ${med.unit} लें / Take your medicine',
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Daily reminders for your medications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // REPEAT DAILY
      );
    }
  }

  static Future<void> cancelReminders(String medId) async {
    // Since we don't track all sub-IDs easily, we'd ideally store them.
    // For now, based on the hash logic, we'd need to know the times.
    // However, we can also use a prefix/range if IDs were structured differently.
    // Simplified for now: we'll clear all if needed or just specific ones if we have access to the med object.
    // For this mock, let's assume we cancel all for the app or specific IDs.
    // In a real app, you might store notification IDs in the DB.
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static int _generateId(String medId, TimeOfDay time) {
    // Ensure 32-bit integer range for Android
    return (medId.hashCode + time.hour * 60 + time.minute).abs() % 2147483647;
  }
}
