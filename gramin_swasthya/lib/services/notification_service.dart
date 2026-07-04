import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../providers/medicines_provider.dart';

// Top-level entry point for the background alarm callback on Android. This runs
// in a separate isolate, so it speaks the medicine name even when the app is
// closed.
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('alarm_id_to_med_name_$id') ?? "दवाई";

  final flutterTts = FlutterTts();
  // The background isolate is torn down as soon as this callback returns. Without
  // awaitSpeakCompletion the async speak() returns immediately and the isolate
  // dies before any audio plays — this is the main reason the voice didn't fire
  // when the app was closed.
  await flutterTts.awaitSpeakCompletion(true);
  await flutterTts.setLanguage("hi-IN");
  await flutterTts.setSpeechRate(0.85);
  await flutterTts.setVolume(1.0);

  // Hindi TTS: "Aap ke medicine lene ka time ho gaya hai, dawai ka naam hai <name>"
  await flutterTts.speak("आप के मेडिसिन लेने का टाइम हो गया है, दवाई का नाम है $name");
}

// Top-level entry point for notification action buttons (Taken / Snooze) tapped
// while the app is in the background or terminated. Must be a top-level function
// annotated with @pragma so it survives tree-shaking in release builds.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == NotificationService.snoozeActionId) {
    final name = response.payload ?? 'दवाई';
    // The background isolate has its own plugin registry, so initialise a fresh
    // plugin + timezone data before scheduling the snoozed reminder.
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(initSettings);
    NotificationService._ensureTimezoneSync();
    await NotificationService._scheduleSnoozeWith(plugin, name);
  }
  // The "Taken" action sets cancelNotification: true, so it dismisses itself and
  // needs no further work here.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FlutterTts _flutterTts = FlutterTts();

  // New channel id (v2) so the full-screen / alarm-audio settings actually take
  // effect — Android caches channel config under its id for the life of the
  // install, so changing settings on the old id would be ignored.
  static const String _channelId = 'medication_reminders_v2';
  static const String takenActionId = 'TAKEN';
  static const String snoozeActionId = 'SNOOZE';

  static Future<void> init() async {
    await _initTimezone();

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions for Android 13+ (notifications) and full-screen intent.
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  // Handle taps and action buttons while the app is in the foreground.
  static void _onNotificationResponse(NotificationResponse details) {
    switch (details.actionId) {
      case snoozeActionId:
        if (details.payload != null) {
          _scheduleSnoozeWith(_notificationsPlugin, details.payload!);
        }
        break;
      case takenActionId:
        _flutterTts.stop();
        break;
      default:
        // Tapping the body of the notification re-announces the medicine name.
        if (details.payload != null) playTts(details.payload!);
    }
  }

  // Set tz.local to the device timezone (main isolate). Without this it defaults
  // to UTC, so every zonedSchedule reminder would fire at the wrong wall-clock
  // time (e.g. ~5.5h off in IST). Falls back to Asia/Kolkata if detection fails.
  static Future<void> _initTimezone() async {
    tz.initializeTimeZones();
    try {
      final String localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone));
    } catch (e) {
      debugPrint('Local timezone detection failed, defaulting to Asia/Kolkata: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}
    }
  }

  // Synchronous timezone init for the background isolate, where the
  // platform-channel timezone lookup may be unavailable. Defaults to IST.
  static void _ensureTimezoneSync() {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}
  }

  // Shared alarm-style notification config: full-screen intent (shows over the
  // lock screen like an alarm), alarm audio stream, and Taken / Snooze buttons.
  static NotificationDetails _alarmDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Medication Reminders',
        channelDescription: 'Daily reminders for your medications',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(takenActionId, 'ली / Taken', cancelNotification: true),
          AndroidNotificationAction(snoozeActionId, '10 मिनट / Snooze', cancelNotification: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  static Future<void> playTts(String medicineName) async {
    await _flutterTts.awaitSpeakCompletion(true);
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

      // Schedule Local Notification.
      // Exact alarms are revocable on Android 12+ and denied by default on
      // Android 14+. Probe the capability and fall back to inexact scheduling,
      // and wrap the call so a denied permission can't abort the save flow.
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      bool canExact = true;
      try {
        canExact = (await androidImpl?.requestExactAlarmsPermission()) ?? true;
      } catch (_) {}
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          'दवाई का समय / Med Time',
          '${med.name} — ${med.dosage} ${med.unit} लें / Take your medicine',
          _nextInstanceOfTime(time),
          _alarmDetails(),
          androidScheduleMode: canExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: med.name,
        );
      } catch (e) {
        debugPrint("zonedSchedule error: $e");
      }

      // Schedule repeating alarm with Android Alarm Manager (drives the spoken
      // announcement in a background isolate even when the app is closed).
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

  // Re-show the reminder ~10 minutes later. Used by both the foreground and
  // background "Snooze" handlers (the latter passes its own plugin instance).
  static Future<void> _scheduleSnoozeWith(
      FlutterLocalNotificationsPlugin plugin, String name) async {
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    final int snoozeId = 900000 + (name.hashCode.abs() % 90000);
    try {
      await plugin.zonedSchedule(
        snoozeId,
        'दवाई का समय / Med Time',
        '$name — दवाई लेना न भूलें / Take your medicine',
        when,
        _alarmDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: name,
      );
    } catch (e) {
      debugPrint("snooze schedule error: $e");
    }
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
