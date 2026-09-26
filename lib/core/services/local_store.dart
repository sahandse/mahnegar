import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.description = '',
    this.location = '',
    this.isTodo = false,
    this.completed = false,
    this.syncedCalendarId,
    this.externalEventId,
    this.sourceCalendarId,
    this.isBirthday = false,
    this.allDay = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String description;
  final String location;
  final bool isTodo;
  final bool completed;
  final String? syncedCalendarId;
  final String? externalEventId;
  final String? sourceCalendarId;
  final bool isBirthday;
  final bool allDay;

  CalendarEntry copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
    bool? isTodo,
    bool? completed,
    String? syncedCalendarId,
    String? externalEventId,
    String? sourceCalendarId,
    bool? isBirthday,
    bool? allDay,
  }) =>
      CalendarEntry(
        id: id,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        description: description ?? this.description,
        location: location ?? this.location,
        isTodo: isTodo ?? this.isTodo,
        completed: completed ?? this.completed,
        syncedCalendarId: syncedCalendarId ?? this.syncedCalendarId,
        externalEventId: externalEventId ?? this.externalEventId,
        sourceCalendarId: sourceCalendarId ?? this.sourceCalendarId,
        isBirthday: isBirthday ?? this.isBirthday,
        allDay: allDay ?? this.allDay,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'description': description,
        'location': location,
        'isTodo': isTodo,
        'completed': completed,
        'syncedCalendarId': syncedCalendarId,
        'externalEventId': externalEventId,
        'sourceCalendarId': sourceCalendarId,
        'isBirthday': isBirthday,
        'allDay': allDay,
      };

  factory CalendarEntry.fromJson(Map<String, dynamic> json) => CalendarEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        description: (json['description'] as String?) ?? '',
        location: (json['location'] as String?) ?? '',
        isTodo: (json['isTodo'] as bool?) ?? false,
        completed: (json['completed'] as bool?) ?? false,
        syncedCalendarId: json['syncedCalendarId'] as String?,
        externalEventId: json['externalEventId'] as String?,
        sourceCalendarId: json['sourceCalendarId'] as String?,
        isBirthday: (json['isBirthday'] as bool?) ?? false,
        allDay: (json['allDay'] as bool?) ?? false,
      );
}

class LocalStore {
  static const _key = 'mahnegar_entries_v2';
  static const _legacyKey = 'mahnegar_entries_v1';

  Future<List<CalendarEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .map((e) => CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<List<CalendarEntry>> merge(List<CalendarEntry> incoming) async {
    final existing = await load();
    final byKey = <String, CalendarEntry>{};
    for (final item in existing) {
      byKey[_identity(item)] = item;
    }
    for (final item in incoming) {
      byKey[_identity(item)] = item;
    }
    final result = byKey.values.toList()..sort((a, b) => a.start.compareTo(b.start));
    await save(result);
    return result;
  }

  Future<String> exportJson() async {
    final entries = await load();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'mahnegar-backup',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<CalendarEntry>> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    final List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      list = (decoded['entries'] as List<dynamic>?) ?? <dynamic>[];
    } else if (decoded is List<dynamic>) {
      list = decoded;
    } else {
      throw const FormatException('Invalid MahNegar backup');
    }
    final incoming = list
        .map((e) => CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return merge(incoming);
  }

  String _identity(CalendarEntry entry) =>
      entry.externalEventId != null && entry.externalEventId!.isNotEmpty
          ? 'external:${entry.sourceCalendarId ?? ''}:${entry.externalEventId}'
          : 'local:${entry.id}';
}
