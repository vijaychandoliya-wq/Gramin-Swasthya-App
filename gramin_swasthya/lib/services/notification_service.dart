import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../db/database_helper.dart';
import '../l10n/app_language.dart';
import '../providers/medicines_provider.dart';

String englishMedicineReminder(String personName, String medicineName) =>
    '$personName, your $medicineName medicine time is now. Please take $medicineName.';

String hindiMedicineReminder(String personName, String medicineName) =>
    '$personName जी, आपकी $medicineName लेने का समय हो गया है। कृपया $medicineName लें।';

// Top-level entry point for background alarm callback on Android
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final medicineName =
      prefs.getString('alarm_id_to_med_name_$id') ?? 'medicine';
  final personName = prefs.getString('alarm_id_to_person_name_$id') ?? 'Hello';

  final flutterTts = FlutterTts();
  await NotificationService.speakReminder(
    flutterTts,
    personName: personName,
    medicineName: medicineName,
  );
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _flutterTts = FlutterTts();

  static Future<void> init() async {
    tz.initializeTimeZones();

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

  static Future<void> scheduleDailyReminders(Medicine med) async {
    // 1. Cancel existing reminders for this medicine first
    await cancelReminders(med.id);

    if (!med.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    final personName = await _personNameFor(med.memberId);
    final canScheduleExactly = await _requestExactAlarmPermission();
    final List<String> scheduledIds = [];

    for (var time in med.times) {
      final int id = _generateId(med.id, time);
      scheduledIds.add(id.toString());

      // Save medicine name for background alarm callback query
      await prefs.setString('alarm_id_to_med_name_$id', med.name);
      await prefs.setString('alarm_id_to_person_name_$id', personName);

      final payload = jsonEncode({
        'personName': personName,
        'medicineName': med.name,
      });

      // Schedule Local Notification
      await _notificationsPlugin.zonedSchedule(
        id,
        AppLanguage.text('💊 $personName, दवाई का समय / Medicine time'),
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

      // Schedule repeating alarm with Android Alarm Manager
      try {
        final scheduledTime = _nextInstanceOfTime(time, med.startDate);
        await AndroidAlarmManager.periodic(
          const Duration(days: 1),
          id,
          alarmCallback,
          startAt: DateTime(
            scheduledTime.year,
            scheduledTime.month,
            scheduledTime.day,
            scheduledTime.hour,
            scheduledTime.minute,
          ),
          exact: canScheduleExactly,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      } catch (e) {
        debugPrint("AndroidAlarmManager schedule error: $e");
      }
    }

    // Save scheduled IDs in SharedPreferences to allow easy canceling later
    await prefs.setStringList('med_notification_ids_${med.id}', scheduledIds);
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
    }
    await prefs.remove('med_notification_ids_$medId');
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  static Future<bool> _requestExactAlarmPermission() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    var allowed = await android.canScheduleExactNotifications() ?? true;
    if (!allowed) {
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
