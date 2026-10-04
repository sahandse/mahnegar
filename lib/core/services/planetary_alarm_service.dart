import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'planetary_hours_service.dart';
import 'sky_times_service.dart';

class PlanetaryAlarmSettings {
  const PlanetaryAlarmSettings({
    required this.enabled,
    required this.leadMinutes,
    required this.cityName,
    required this.latitude,
    required this.longitude,
  });

  final bool enabled;
  final int leadMinutes;
  final String cityName;
  final double latitude;
  final double longitude;

  SkyCity get city => SkyCity(cityName, latitude, longitude);
}

class PlanetaryAlarmService {
  PlanetaryAlarmService._();

  static final instance = PlanetaryAlarmService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _planetary = PlanetaryHoursService();
  bool _initialized = false;

  static const _enabledKey = 'planetary_jupiter_alarm_enabled';
  static const _leadKey = 'planetary_jupiter_alarm_lead';
  static const _cityNameKey = 'planetary_jupiter_alarm_city_name';
  static const _latKey = 'planetary_jupiter_alarm_lat';
  static const _lonKey = 'planetary_jupiter_alarm_lon';
  static const _baseId = 3600;
  static const _maxScheduled = 30;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_mahnegar');
    await _plugin.initialize(const InitializationSettings(android: android));
    tz.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Keep timezone package default if platform timezone lookup fails.
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<PlanetaryAlarmSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return PlanetaryAlarmSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      leadMinutes: prefs.getInt(_leadKey) ?? 5,
      cityName: prefs.getString(_cityNameKey) ?? 'تهران',
      latitude: prefs.getDouble(_latKey) ?? 35.6892,
      longitude: prefs.getDouble(_lonKey) ?? 51.3890,
    );
  }

  Future<void> setEnabled(
    bool enabled, {
    required SkyCity city,
    required int leadMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_enabledKey, enabled),
      prefs.setInt(_leadKey, leadMinutes.clamp(0, 30)),
      prefs.setString(_cityNameKey, city.name),
      prefs.setDouble(_latKey, city.latitude),
      prefs.setDouble(_lonKey, city.longitude),
    ]);
    if (enabled) {
      await requestPermission();
      await schedule(city: city, leadMinutes: leadMinutes);
    } else {
      await cancelAll();
    }
  }

  Future<void> updateLocationAndLead({
    required SkyCity city,
    required int leadMinutes,
  }) async {
    final settings = await loadSettings();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_leadKey, leadMinutes.clamp(0, 30)),
      prefs.setString(_cityNameKey, city.name),
      prefs.setDouble(_latKey, city.latitude),
      prefs.setDouble(_lonKey, city.longitude),
    ]);
    if (settings.enabled) {
      await schedule(city: city, leadMinutes: leadMinutes);
    }
  }

  Future<void> refreshIfEnabled() async {
    final settings = await loadSettings();
    if (!settings.enabled) return;
    await schedule(
      city: settings.city,
      leadMinutes: settings.leadMinutes,
    );
  }

  Future<void> schedule({
    required SkyCity city,
    required int leadMinutes,
  }) async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();
    final slots = _planetary.upcomingFor(
      PlanetaryRuler.jupiter,
      now,
      city,
      days: 14,
      limit: _maxScheduled,
    );

    const details = AndroidNotificationDetails(
      'mahnegar_planetary_hours',
      'اوقات کواکب ماه‌نگار',
      channelDescription: 'یادآوری اختیاری آغاز ساعات سنتی کواکب',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_stat_mahnegar',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    final lead = Duration(minutes: leadMinutes.clamp(0, 30));
    var id = _baseId;
    for (final slot in slots) {
      final trigger = slot.start.subtract(lead);
      if (!trigger.isAfter(now)) continue;
      final scheduled = tz.TZDateTime.from(trigger, tz.local);
      final title = leadMinutes == 0
          ? '♃ ساعت مشتری شروع شد'
          : '♃ ساعت مشتری نزدیک است';
      final body = leadMinutes == 0
          ? 'از الان تا ${_formatTime(slot.end)} • ${city.name}'
          : '$leadMinutes دقیقه دیگر شروع می‌شود • ${_formatTime(slot.start)} تا ${_formatTime(slot.end)} • ${city.name}';
      await _plugin.zonedSchedule(
        id++,
        title,
        body,
        scheduled,
        const NotificationDetails(android: details),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      if (id >= _baseId + _maxScheduled) break;
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    for (var id = _baseId; id < _baseId + _maxScheduled; id++) {
      await _plugin.cancel(id);
    }
  }

  String _formatTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}';
  }
}
