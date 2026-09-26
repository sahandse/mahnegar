import 'package:device_calendar_plus/device_calendar_plus.dart';

import 'local_store.dart';

class DeviceCalendarSyncService {
  final DeviceCalendar _plugin = DeviceCalendar.instance;

  Future<CalendarPermissionStatus> requestAccess() => _plugin.requestPermissions();

  Future<List<Calendar>> googleCalendars({bool writableOnly = false}) async {
    final status = await _plugin.requestPermissions();
    if (status != CalendarPermissionStatus.granted) return [];
    final calendars = await _plugin.listCalendars();
    return calendars.where((calendar) {
      final accountType = (calendar.accountType ?? '').toLowerCase();
      final accountName = (calendar.accountName ?? '').toLowerCase();
      final google = accountType.contains('google') || accountName.contains('gmail.com');
      return google && (!writableOnly || !calendar.readOnly);
    }).toList();
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
      isAllDay: entry.allDay,
      reminders: const [Duration(minutes: 15)],
    );
  }

  Future<List<CalendarEntry>> importGoogleEvents({
    required DateTime start,
    required DateTime end,
    List<String>? calendarIds,
  }) async {
    final status = await _plugin.requestPermissions();
    if (status != CalendarPermissionStatus.granted) return [];

    final calendars = await googleCalendars();
    final allowed = calendarIds == null || calendarIds.isEmpty
        ? calendars.map((c) => c.id).toSet()
        : calendarIds.toSet();
    if (allowed.isEmpty) return [];

    final events = await _plugin.listEvents(start, end, calendarIds: allowed.toList());
    return events
        .where((event) => allowed.contains(event.calendarId))
        .map((event) => CalendarEntry(
              id: 'google-${event.calendarId}-${event.instanceId}',
              title: event.title,
              start: event.startDate,
              end: event.endDate,
              description: event.description ?? '',
              location: event.location ?? '',
              externalEventId: event.eventId,
              sourceCalendarId: event.calendarId,
              syncedCalendarId: event.calendarId,
              allDay: event.isAllDay,
            ))
        .toList();
  }

  Future<List<CalendarEntry>> syncIntoLocal(
    LocalStore store, {
    List<String>? calendarIds,
    Duration past = const Duration(days: 90),
    Duration future = const Duration(days: 365),
  }) async {
    final now = DateTime.now();
    final incoming = await importGoogleEvents(
      start: now.subtract(past),
      end: now.add(future),
      calendarIds: calendarIds,
    );
    return store.merge(incoming);
  }
}
