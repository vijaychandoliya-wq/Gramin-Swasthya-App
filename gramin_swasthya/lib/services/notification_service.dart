import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../db/database_helper.dart';
import '../l10n/app_language.dart';
import '../providers/medicines_provider.dart';

String englishMedicineReminder(String personName, String medicineName) =>
    '$personName, your $medicineName medicine time is now. Please take $medicineName.';

String hindiMedicineReminder(String personName, String medicineName) =>
    '$personName जी, आपकी $medicineName लेने का समय हो गया है। कृपया $medicineName लें।';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      // tz.local remains a safe fallback; log the device-specific failure.
      debugPrint('Unable to resolve device timezone: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          playTtsPayload(details.payload!);
        }
      },
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> playTtsPayload(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      await speakReminder(
        _flutterTts,
        personName: data['personName'] as String? ?? 'Hello',
        medicineName: data['medicineName'] as String? ?? 'medicine',
      );
    } catch (_) {
      await speakReminder(
        _flutterTts,
        personName: 'Hello',
        medicineName: payload,
      );
    }
  }

  static Future<void> speakReminder(
    FlutterTts flutterTts, {
    required String personName,
    required String medicineName,
  }) async {
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setPitch(1.0);
    await flutterTts.setVolume(1.0);

    final englishAvailable =
        await flutterTts.isLanguageAvailable('en-IN') == true;
    if (englishAvailable) {
      await flutterTts.setLanguage('en-IN');
      await flutterTts.speak(
        englishMedicineReminder(personName, medicineName),
      );
    }

    final hindiAvailable =
        await flutterTts.isLanguageAvailable('hi-IN') == true;
    if (hindiAvailable) {
      await flutterTts.setLanguage('hi-IN');
      await flutterTts.speak(
        hindiMedicineReminder(personName, medicineName),
      );
    }

    if (!englishAvailable && !hindiAvailable) {
      await flutterTts.setLanguage('en-US');
      await flutterTts.speak(
        englishMedicineReminder(personName, medicineName),
      );
    }
  }

  static Future<void> scheduleDailyReminders(
    Medicine med, {
    bool requestExactPermission = true,
  }) async {
    // 1. Cancel existing reminders for this medicine first
    await cancelReminders(med.id);

    if (!med.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_enabled') ?? true)) return;
    final personName = await _personNameFor(med.memberId);
    final canScheduleExactly = await _requestExactAlarmPermission(
      requestPermission: requestExactPermission,
    );
    final List<String> scheduledIds = [];

    for (var time in med.times) {
      final int id = _generateId(med.id, time);
      scheduledIds.add(id.toString());

      // Save medicine name for background alarm callback query
      await prefs.setString('alarm_id_to_med_name_$id', med.name);
      await prefs.setString('alarm_id_to_person_name_$id', personName);
      await prefs.setInt('alarm_id_to_hour_$id', time.hour);
      await prefs.setInt('alarm_id_to_minute_$id', time.minute);

      final payload = jsonEncode({
        'personName': personName,
        'medicineName': med.name,
      });

      // Schedule Local Notification
      await _notificationsPlugin.zonedSchedule(
        id,
        AppLanguage.text('$personName, दवाई का समय / Medicine time'),
        AppLanguage.text(
          '${med.name} — ${med.dosage} ${med.unit} लें / Take ${med.name}',
        ),
        _nextInstanceOfTime(time, med.startDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Daily reminders for your medications',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: canScheduleExactly
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      // Do not start Dart/Flutter plugins from an Android Alarm Manager
      // isolate. flutter_local_notifications owns the native alarm and can
      // deliver this notification without waking a Flutter UI isolate.
      // Legacy alarm IDs are cancelled below when a medicine is rescheduled.
    }

    // Save scheduled IDs in SharedPreferences to allow easy canceling later
    await prefs.setStringList('med_notification_ids_${med.id}', scheduledIds);
  }

  /// Rebuild schedules on startup so app upgrades, timezone changes, and
  /// vendor-specific reboot behavior cannot silently orphan active reminders.
  static Future<void> restoreActiveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_enabled') ?? true)) return;

    final db = await DatabaseHelper.instance.database;
    final rows =
        await db.query('medicines', where: 'is_active = ?', whereArgs: [1]);
    for (final row in rows) {
      final medicine = Medicine(
        id: row['id'].toString(),
        memberId: row['member_id'].toString(),
        name: row['name']?.toString() ?? 'medicine',
        dosage: row['dosage']?.toString() ?? '',
        unit: row['unit']?.toString() ?? '',
        times: Medicine.timesFromJson(row['times_json']?.toString() ?? '[]'),
        isActive: true,
        durationDays: row['duration_days'] as int? ?? -1,
        startDate: DateTime.tryParse(row['start_date']?.toString() ?? '') ??
            DateTime.now(),
      );
      if (medicine.times.isNotEmpty) {
        await scheduleDailyReminders(medicine, requestExactPermission: false);
      }
    }
  }

  static Future<void> cancelReminders(String medId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> idStrings =
        prefs.getStringList('med_notification_ids_$medId') ?? [];
    for (final idStr in idStrings) {
      final int id = int.parse(idStr);
      await _notificationsPlugin.cancel(id);
      try {
        await AndroidAlarmManager.cancel(id);
      } catch (_) {}
      await prefs.remove('alarm_id_to_med_name_$id');
      await prefs.remove('alarm_id_to_person_name_$id');
      await prefs.remove('alarm_id_to_hour_$id');
      await prefs.remove('alarm_id_to_minute_$id');
    }
    await prefs.remove('med_notification_ids_$medId');
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    final medicineKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('med_notification_ids_'))
        .toList();
    for (final key in medicineKeys) {
      await cancelReminders(key.substring('med_notification_ids_'.length));
    }
  }

  static Future<bool> _requestExactAlarmPermission({
    bool requestPermission = true,
  }) async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    var allowed = await android.canScheduleExactNotifications() ?? true;
    if (!allowed && requestPermission) {
      allowed = await android.requestExactAlarmsPermission() ?? false;
    }
    return allowed;
  }

  static Future<String> _personNameFor(String memberId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'family_members',
      where: 'id = ?',
      whereArgs: [int.tryParse(memberId) ?? memberId],
      limit: 1,
    );
    if (rows.isEmpty) return 'Hello';
    final name = rows.first['name']?.toString().trim();
    return name == null || name.isEmpty ? 'Hello' : name;
  }

  static tz.TZDateTime _nextInstanceOfTime(
    TimeOfDay time,
    DateTime startDate,
  ) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final startsTodayOrEarlier = !DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).isAfter(DateTime(now.year, now.month, now.day));

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      startsTodayOrEarlier ? now.year : startDate.year,
      startsTodayOrEarlier ? now.month : startDate.month,
      startsTodayOrEarlier ? now.day : startDate.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static int _generateId(String medId, TimeOfDay time) {
    return (medId.hashCode + time.hour * 60 + time.minute).abs() % 2147483647;
  }
}
