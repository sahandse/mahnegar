import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'astronomy_service.dart';

class AstronomyAlertService {
  AstronomyAlertService._();
  static final instance = AstronomyAlertService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _astronomy = AstronomyService();
  bool _initialized = false;

  static const _prefKey = 'astronomy_alerts_enabled';
  static const _phaseBaseId = 2400;
  static const _scorpioId = 2490;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_mahnegar'),
    );
    await _plugin.initialize(settings);
    tz.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {}
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    if (enabled) {
      await scheduleUpcoming();
    } else {
      await cancelAll();
    }
  }

  Future<void> scheduleUpcoming() async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();
    final phases = _astronomy.upcomingMajorPhases(now);
    for (var i = 0; i < phases.length; i++) {
      final event = phases[i];
      await _schedule(
        id: _phaseBaseId + i,
        title: 'رویداد ماه 🌙',
        body: '${event.name} نزدیک است',
        when: event.time.subtract(const Duration(hours: 6)),
      );
    }

    final scorpio = _astronomy.scorpioWindow(now);
    if (scorpio.start != null) {
      await _schedule(
        id: _scorpioId,
        title: 'قمر در عقرب',
        body: 'بازه بعدی قمر در عقرب نزدیک است',
        when: scorpio.start!.subtract(const Duration(hours: 6)),
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final now = DateTime.now();
    if (!when.isAfter(now)) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mahnegar_astronomy',
        'هشدارهای نجومی ماه‌نگار',
        channelDescription: 'ماه نو، ماه کامل، تربیع‌ها و قمر در عقرب',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@drawable/ic_stat_mahnegar',
        category: AndroidNotificationCategory.reminder,
      ),
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await initialize();
    for (var i = 0; i < 4; i++) {
      await _plugin.cancel(_phaseBaseId + i);
    }
    await _plugin.cancel(_scorpioId);
  }
}
