import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.showDate,
    required this.showOccasion,
    required this.showMoonPhase,
    required this.showScorpio,
    required this.showNextEvent,
  });

  final bool enabled;
  final bool showDate;
  final bool showOccasion;
  final bool showMoonPhase;
  final bool showScorpio;
  final bool showNextEvent;

  static const defaults = NotificationPreferences(
    enabled: false,
    showDate: true,
    showOccasion: true,
    showMoonPhase: false,
    showScorpio: true,
    showNextEvent: true,
  );

  NotificationPreferences copyWith({
    bool? enabled,
    bool? showDate,
    bool? showOccasion,
    bool? showMoonPhase,
    bool? showScorpio,
    bool? showNextEvent,
  }) => NotificationPreferences(
        enabled: enabled ?? this.enabled,
        showDate: showDate ?? this.showDate,
        showOccasion: showOccasion ?? this.showOccasion,
        showMoonPhase: showMoonPhase ?? this.showMoonPhase,
        showScorpio: showScorpio ?? this.showScorpio,
        showNextEvent: showNextEvent ?? this.showNextEvent,
      );
}

class MahNegarNotificationService {
  MahNegarNotificationService._();

  static final instance = MahNegarNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _notificationId = 1404;
  static const _channelId = 'mahnegar_today';
  static const _channelName = 'ماه‌نگار امروز';

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  Future<bool> requestPermission() async {
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
    ]);
  }

  Future<void> showStatus({required String title, required String body}) async {
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
    );
    await _plugin.show(
      _notificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> hideStatus() => _plugin.cancel(_notificationId);
}
