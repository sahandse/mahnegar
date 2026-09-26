import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.showDate,
    required this.showOccasion,
    required this.showMoonPhase,
    required this.showScorpio,
    required this.showNextEvent,
    required this.morningSummary,
    required this.morningHour,
  });

  final bool enabled;
  final bool showDate;
  final bool showOccasion;
  final bool showMoonPhase;
  final bool showScorpio;
  final bool showNextEvent;
  final bool morningSummary;
  final int morningHour;

  static const defaults = NotificationPreferences(
    enabled: false,
    showDate: true,
    showOccasion: true,
    showMoonPhase: false,
    showScorpio: true,
    showNextEvent: true,
    morningSummary: false,
    morningHour: 8,
  );

  NotificationPreferences copyWith({
    bool? enabled,
    bool? showDate,
    bool? showOccasion,
    bool? showMoonPhase,
    bool? showScorpio,
    bool? showNextEvent,
    bool? morningSummary,
    int? morningHour,
  }) => NotificationPreferences(
        enabled: enabled ?? this.enabled,
        showDate: showDate ?? this.showDate,
        showOccasion: showOccasion ?? this.showOccasion,
        showMoonPhase: showMoonPhase ?? this.showMoonPhase,
        showScorpio: showScorpio ?? this.showScorpio,
        showNextEvent: showNextEvent ?? this.showNextEvent,
        morningSummary: morningSummary ?? this.morningSummary,
        morningHour: morningHour ?? this.morningHour,
      );
}

class MahNegarNotificationService {
  MahNegarNotificationService._();

  static final instance = MahNegarNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _notificationId = 1404;
  static const _morningId = 1405;
  static const _channelId = 'mahnegar_today';
  static const _channelName = 'ماه‌نگار امروز';
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_mahnegar');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    tz.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // timezone package keeps its safe default if OS timezone lookup fails.
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<NotificationPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      enabled: prefs.getBool('status_notification_enabled') ?? NotificationPreferences.defaults.enabled,
      showDate: prefs.getBool('status_notification_date') ?? NotificationPreferences.defaults.showDate,
      showOccasion: prefs.getBool('status_notification_occasion') ?? NotificationPreferences.defaults.showOccasion,
      showMoonPhase: prefs.getBool('status_notification_moon') ?? NotificationPreferences.defaults.showMoonPhase,
      showScorpio: prefs.getBool('status_notification_scorpio') ?? NotificationPreferences.defaults.showScorpio,
      showNextEvent: prefs.getBool('status_notification_event') ?? NotificationPreferences.defaults.showNextEvent,
      morningSummary: prefs.getBool('morning_summary_enabled') ?? NotificationPreferences.defaults.morningSummary,
      morningHour: prefs.getInt('morning_summary_hour') ?? NotificationPreferences.defaults.morningHour,
    );
  }

  Future<void> savePreferences(NotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('status_notification_enabled', value.enabled),
      prefs.setBool('status_notification_date', value.showDate),
      prefs.setBool('status_notification_occasion', value.showOccasion),
      prefs.setBool('status_notification_moon', value.showMoonPhase),
      prefs.setBool('status_notification_scorpio', value.showScorpio),
      prefs.setBool('status_notification_event', value.showNextEvent),
      prefs.setBool('morning_summary_enabled', value.morningSummary),
      prefs.setInt('morning_summary_hour', value.morningHour.clamp(0, 23)),
    ]);
  }

  Future<void> showStatus({required String title, required String body}) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'نمایش اختیاری تاریخ، مناسبت، وضعیت ماه و برنامه بعدی در نوار اعلان',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.reminder,
      icon: '@drawable/ic_stat_mahnegar',
      visibility: NotificationVisibility.public,
    );
    await _plugin.show(
      _notificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> scheduleMorningSummary({
    required int hour,
    required String body,
  }) async {
    await initialize();
    await _plugin.cancel(_morningId);
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour.clamp(0, 23));
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    const details = AndroidNotificationDetails(
      'mahnegar_morning',
      'خلاصه صبحگاهی ماه‌نگار',
      channelDescription: 'خلاصه اختیاری برنامه، مناسبت و وضعیت آسمان در شروع روز',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_stat_mahnegar',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    await _plugin.zonedSchedule(
      _morningId,
      'صبح بخیر 🌙',
      body,
      next,
      const NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelMorningSummary() async {
    await initialize();
    await _plugin.cancel(_morningId);
  }

  Future<void> hideStatus() async {
    await initialize();
    await _plugin.cancel(_notificationId);
  }
}
