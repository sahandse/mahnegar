import 'package:device_calendar_plus/device_calendar_plus.dart';

import 'local_store.dart';

class DeviceCalendarSyncService {
  final DeviceCalendar _plugin = DeviceCalendar.instance;

  Future<CalendarPermissionStatus> requestAccess() => _plugin.requestPermissions();

  Future<List<Calendar>> googleCalendars() async {
    final status = await _plugin.requestPermissions();
    if (status != CalendarPermissionStatus.granted) return [];
    final calendars = await _plugin.listCalendars();
    return calendars.where((calendar) {
      final accountType = (calendar.accountType ?? '').toLowerCase();
      final accountName = (calendar.accountName ?? '').toLowerCase();
      return accountType.contains('google') || accountName.contains('gmail.com');
    }).where((calendar) => !calendar.readOnly).toList();
  }

  Future<String> addMeeting(
    CalendarEntry entry, {
    String? calendarId,
  }) async {
    final status = await _plugin.requestPermissions();
    if (status != CalendarPermissionStatus.granted &&
        status != CalendarPermissionStatus.writeOnly) {
      throw StateError('Calendar permission is not granted.');
    }

    return _plugin.createEvent(
      calendarId: calendarId,
      title: entry.title,
      startDate: entry.start,
      endDate: entry.end,
      description: entry.description.isEmpty ? null : entry.description,
      location: entry.location.isEmpty ? null : entry.location,
      reminders: const [Duration(minutes: 15)],
    );
  }
}
