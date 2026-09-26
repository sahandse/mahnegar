import 'package:flutter_contacts/flutter_contacts.dart';

import 'local_store.dart';

class BirthdayImportResult {
  const BirthdayImportResult({required this.contactName, required this.entries});
  final String contactName;
  final List<CalendarEntry> entries;
}

class BirthdayService {
  Future<BirthdayImportResult?> pickAndImport({int? targetYear}) async {
    final permission = await FlutterContacts.permissions.request(PermissionType.read);
    if (permission != PermissionStatus.granted) return null;

    final picked = await FlutterContacts.native.showPicker(
      properties: const {ContactProperty.event},
    );
    if (picked == null || picked.id == null) return null;

    final contact = await FlutterContacts.get(
      picked.id!,
      properties: const {ContactProperty.event, ContactProperty.name},
    );
    if (contact == null || contact.events.isEmpty) {
      return BirthdayImportResult(
        contactName: contact?.displayName ?? picked.displayName ?? 'مخاطب',
        entries: const [],
      );
    }

    final name = contact.displayName ?? picked.displayName ?? 'مخاطب';
    final now = DateTime.now();
    final year = targetYear ?? now.year;
    final result = <CalendarEntry>[];
    for (final event in contact.events) {
      final eventYear = event.year ?? year;
      DateTime date;
      try {
        date = DateTime(eventYear, event.month, event.day);
      } catch (_) {
        continue;
      }
      if (event.year == null && date.isBefore(DateTime(now.year, now.month, now.day))) {
        date = DateTime(year + 1, event.month, event.day);
      }
      final label = event.label.label.name;
      final isBirthday = label == 'birthday';
      final title = isBirthday ? 'تولد $name' : 'سالگرد $name';
      result.add(CalendarEntry(
        id: 'contact-${contact.id}-${event.month}-${event.day}-$label',
        title: title,
        start: DateTime(date.year, date.month, date.day),
        end: DateTime(date.year, date.month, date.day, 23, 59),
        description: 'واردشده از مخاطبین دستگاه',
        isBirthday: true,
        allDay: true,
      ));
    }
    return BirthdayImportResult(contactName: name, entries: result);
  }
}
