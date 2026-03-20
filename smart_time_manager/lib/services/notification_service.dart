import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/reminder_settings_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> rescheduleAll({
    required List<PlanEvent> events,
    required ReminderSettingsState settings,
  }) async {
    await initialize();
    await _plugin.cancelAll();

    final now = DateTime.now();
    for (final event in events) {
      if (event.isCompleted) continue;
      if (event.startTime == null) continue;
      if (event.isCountdown) continue;

      final quadrant = _quadrantTypeOf(event);
      final rule = settings.rules[quadrant];
      if (rule == null || !rule.enabled) continue;

      final triggerTime = event.startTime!.subtract(Duration(minutes: rule.minutesBefore));
      if (!triggerTime.isAfter(now)) continue;

      final notificationId = _notificationIdFor(event.id);
      final androidDetails = const AndroidNotificationDetails(
        'event_reminder_channel',
        '事件提醒',
        channelDescription: '四象限事件开始前提醒',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.zonedSchedule(
        notificationId,
        '事件提醒',
        '【${_quadrantTitle(quadrant)}】${event.title} 将在 ${rule.minutesBefore} 分钟后开始',
        tz.TZDateTime.from(triggerTime, tz.local),
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  QuadrantType _quadrantTypeOf(PlanEvent event) {
    if (event.isImportant && event.isUrgent) return QuadrantType.importantUrgent;
    if (event.isImportant && !event.isUrgent) return QuadrantType.importantNotUrgent;
    if (!event.isImportant && event.isUrgent) return QuadrantType.urgentNotImportant;
    return QuadrantType.notImportantNotUrgent;
  }

  String _quadrantTitle(QuadrantType type) {
    switch (type) {
      case QuadrantType.importantUrgent:
        return '重要且紧急';
      case QuadrantType.importantNotUrgent:
        return '重要不紧急';
      case QuadrantType.urgentNotImportant:
        return '紧急不重要';
      case QuadrantType.notImportantNotUrgent:
        return '不重要不紧急';
    }
  }

  int _notificationIdFor(String eventId) {
    return eventId.hashCode & 0x7fffffff;
  }
}
