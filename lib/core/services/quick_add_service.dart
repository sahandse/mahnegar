class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.start,
    required this.end,
    this.isTodo = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isTodo;
}

class QuickAddService {
  static const _weekdays = <String, int>{
    'دوشنبه': DateTime.monday,
    'سه‌شنبه': DateTime.tuesday,
    'سه شنبه': DateTime.tuesday,
    'چهارشنبه': DateTime.wednesday,
    'پنجشنبه': DateTime.thursday,
    'پنج‌شنبه': DateTime.thursday,
    'جمعه': DateTime.friday,
    'شنبه': DateTime.saturday,
    'یکشنبه': DateTime.sunday,
    'یک‌شنبه': DateTime.sunday,
  };

  QuickAddResult parse(String input, {DateTime? base}) {
    final now = base ?? DateTime.now();
    var text = _latinDigits(input.trim());
    var target = DateTime(now.year, now.month, now.day);

    if (text.contains('پس فردا') || text.contains('پس‌فردا')) {
      target = target.add(const Duration(days: 2));
      text = text.replaceAll('پس فردا', '').replaceAll('پس‌فردا', '');
    } else if (text.contains('فردا')) {
      target = target.add(const Duration(days: 1));
      text = text.replaceAll('فردا', '');
    } else if (text.contains('امروز')) {
      text = text.replaceAll('امروز', '');
    } else {
      for (final entry in _weekdays.entries) {
        if (text.contains(entry.key)) {
          var delta = (entry.value - now.weekday) % 7;
          if (delta <= 0) delta += 7;
          target = target.add(Duration(days: delta));
          text = text.replaceAll(entry.key, '');
          break;
        }
      }
    }

    final timeMatch = RegExp(r'(?:ساعت\s*)?(\d{1,2})(?:[:٫.](\d{1,2}))?').firstMatch(text);
    var hour = 9;
    var minute = 0;
    if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
      minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);
      text = text.replaceFirst(timeMatch.group(0)!, '');
    }

    final isTodo = text.contains('کار ') || text.startsWith('کار') || text.contains('یادآوری');
    text = text
        .replaceAll(RegExp(r'\bساعت\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) text = isTodo ? 'کار جدید' : 'جلسه جدید';

    final start = DateTime(target.year, target.month, target.day, hour, minute);
    final end = start.add(Duration(minutes: isTodo ? 30 : 60));
    return QuickAddResult(title: text, start: start, end: end, isTodo: isTodo);
  }

  String _latinDigits(String value) => value
      .replaceAll('۰', '0')
      .replaceAll('۱', '1')
      .replaceAll('۲', '2')
      .replaceAll('۳', '3')
      .replaceAll('۴', '4')
      .replaceAll('۵', '5')
      .replaceAll('۶', '6')
      .replaceAll('۷', '7')
      .replaceAll('۸', '8')
      .replaceAll('۹', '9');
}
