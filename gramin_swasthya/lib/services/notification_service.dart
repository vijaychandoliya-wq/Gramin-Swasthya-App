import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../providers/medicines_provider.dart';

// Top-level entry point for background alarm callback on Android
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('alarm_id_to_med_name_$id') ?? "दवाई";
  
  final flutterTts = FlutterTts();
  await flutterTts.setLanguage("hi-IN");
  await flutterTts.setSpeechRate(0.85);
  await flutterTts.setVolume(1.0);
  
  // Hindi TTS: "Aap ke medicine lene ka time ho gaya hai, dawai ka naam hai <name>"
  await flutterTts.speak("आप के मेडिसिन लेने का टाइम हो गया है, दवाई का नाम है $name");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FlutterTts _flutterTts = FlutterTts();

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
      macOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          playTts(details.payload!);
        }
      },
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> playTts(String medicineName) async {
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setSpeechRate(0.85);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak("आप के मेडिसिन लेने का टाइम हो गया है, दवाई का नाम है $medicineName");
  }

  static Future<void> scheduleDailyReminders(Medicine med) async {
    // 1. Cancel existing reminders for this medicine first
    await cancelReminders(med.id);

    if (!med.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> scheduledIds = [];

    for (var time in med.times) {
      final int id = _generateId(med.id, time);
      scheduledIds.add(id.toString());
      
      // Save medicine name for background alarm callback query
      await prefs.setString('alarm_id_to_med_name_$id', med.name);

      // Schedule Local Notification
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
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: med.name,
      );

      // Schedule repeating alarm with Android Alarm Manager
      try {
        final scheduledTime = _nextInstanceOfTime(time);
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
          exact: true,
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
    final List<String> idStrings = prefs.getStringList('med_notification_ids_$medId') ?? [];
    for (final idStr in idStrings) {
      final int id = int.parse(idStr);
      await _notificationsPlugin.cancel(id);
      try {
        await AndroidAlarmManager.cancel(id);
      } catch (_) {}
      await prefs.remove('alarm_id_to_med_name_$id');
    }
    await prefs.remove('med_notification_ids_$medId');
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
    return (medId.hashCode + time.hour * 60 + time.minute).abs() % 2147483647;
  }
}
