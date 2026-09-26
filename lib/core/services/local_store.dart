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

  CalendarEntry copyWith({bool? completed, String? syncedCalendarId}) => CalendarEntry(
        id: id,
        title: title,
        start: start,
        end: end,
        description: description,
        location: location,
        isTodo: isTodo,
        completed: completed ?? this.completed,
        syncedCalendarId: syncedCalendarId ?? this.syncedCalendarId,
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
      );
}

class LocalStore {
  static const _key = 'mahnegar_entries_v1';

  Future<List<CalendarEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((e) => CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> save(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}
