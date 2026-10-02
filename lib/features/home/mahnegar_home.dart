import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/iran_holidays.dart';
import '../../core/services/local_store.dart';
import '../../core/services/notification_service.dart';
import 'mahnegar_dashboard_v4.dart';

class MahNegarHome extends StatefulWidget {
  const MahNegarHome({super.key});

  @override
  State<MahNegarHome> createState() => _MahNegarHomeState();
}

class _MahNegarHomeState extends State<MahNegarHome> {
  final _notifications = MahNegarNotificationService.instance;
  final _astronomy = AstronomyService();
  final _holidays = IranHolidays();
  final _store = LocalStore();

  static const _months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  @override
  void initState() {
    super.initState();
    _refreshStatusIfEnabled();
  }

  String _fa(Object value) => value
      .toString()
      .replaceAll('0', '۰')
      .replaceAll('1', '۱')
      .replaceAll('2', '۲')
      .replaceAll('3', '۳')
      .replaceAll('4', '۴')
      .replaceAll('5', '۵')
      .replaceAll('6', '۶')
      .replaceAll('7', '۷')
      .replaceAll('8', '۸')
      .replaceAll('9', '۹');

  Future<void> _refreshStatusIfEnabled() async {
    try {
      final prefs = await _notifications.loadPreferences();
      if (!prefs.enabled) return;
      final now = DateTime.now();
      final jalali = Jalali.now();
      final astro = _astronomy.snapshot(now);
      final occasions = _holidays.forDate(jalali);
      final entries = await _store.load();
      final upcoming = entries.where((e) => !e.completed && e.start.isAfter(now)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      final parts = <String>[];
      if (prefs.showDate) parts.add('${_fa(jalali.day)} ${_months[jalali.month - 1]} ${_fa(jalali.year)}');
      if (prefs.showOccasion && occasions.isNotEmpty) parts.add(occasions.first);
      if (prefs.showMoonPhase) parts.add('ماه: ${astro.phaseName}');
      if (prefs.showScorpio) parts.add(astro.isMoonInScorpio ? 'قمر در عقرب: فعال' : 'قمر در عقرب: غیرفعال');
      if (prefs.showNextEvent && upcoming.isNotEmpty) {
        final next = upcoming.first;
        parts.add('بعدی: ${next.title} ${_fa(DateFormat('HH:mm').format(next.start))}');
      }
      await _notifications.showStatus(title: 'ماه‌نگار', body: parts.isEmpty ? 'نمایش نوار اعلان فعال است' : parts.join(' • '));
    } catch (_) {
      // اعلان اختیاری است و هرگز نباید مانع اجرای رابط کاربری شود.
    }
  }

  @override
  Widget build(BuildContext context) => const MahNegarDashboardV4();
}
