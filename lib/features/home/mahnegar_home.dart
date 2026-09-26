import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/iran_holidays.dart';
import '../../core/services/local_store.dart';
import '../../core/services/notification_service.dart';
import 'mahnegar_dashboard.dart';

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

  NotificationPreferences _prefs = NotificationPreferences.defaults;

  static const _months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    try {
      _prefs = await _notifications.loadPreferences();
      if (_prefs.enabled) await _refreshPersistentNotification();
    } catch (_) {}
    if (mounted) setState(() {});
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

  Future<void> _refreshPersistentNotification() async {
    if (!_prefs.enabled) {
      await _notifications.hideStatus();
      return;
    }
    final now = DateTime.now();
    final jalali = Jalali.now();
    final astro = _astronomy.snapshot(now);
    final occasions = _holidays.forDate(jalali);
    final entries = await _store.load();
    final upcoming = entries.where((e) => !e.completed && e.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final parts = <String>[];
    if (_prefs.showDate) parts.add('${_fa(jalali.day)} ${_months[jalali.month - 1]} ${_fa(jalali.year)}');
    if (_prefs.showOccasion && occasions.isNotEmpty) parts.add(occasions.first);
    if (_prefs.showMoonPhase) parts.add('ماه: ${astro.phaseName}');
    if (_prefs.showScorpio) parts.add(astro.isMoonInScorpio ? 'قمر در عقرب: فعال' : 'قمر در عقرب: غیرفعال');
    if (_prefs.showNextEvent && upcoming.isNotEmpty) {
      final next = upcoming.first;
      parts.add('بعدی: ${next.title} ${_fa(DateFormat('HH:mm').format(next.start))}');
    }
    await _notifications.showStatus(title: 'ماه‌نگار', body: parts.isEmpty ? 'نمایش نوار اعلان فعال است' : parts.join(' • '));
  }

  Future<void> _setPrefs(NotificationPreferences value) async {
    _prefs = value;
    await _notifications.savePreferences(value);
    await _refreshPersistentNotification();
    if (mounted) setState(() {});
  }

  Future<void> _openNotificationSettings() async {
    var draft = _prefs;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> update(NotificationPreferences value) async {
          draft = value;
          setSheetState(() {});
          await _setPrefs(value);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اعلان و نوار وضعیت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('خودت انتخاب کن چه اطلاعاتی در اعلان دائمی و Lock Screen نمایش داده شود.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Card(child: SwitchListTile(
              value: draft.enabled,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('نمایش در نوار اعلان'),
              subtitle: const Text('اعلان کم‌اهمیت، بدون صدا و کاملاً اختیاری'),
              onChanged: (enabled) async {
                if (enabled) {
                  final allowed = await _notifications.requestPermission();
                  if (!allowed) return;
                }
                await update(draft.copyWith(enabled: enabled));
              },
            )),
            const SizedBox(height: 10),
            Opacity(opacity: draft.enabled ? 1 : .45, child: IgnorePointer(ignoring: !draft.enabled, child: Card(child: Column(children: [
              CheckboxListTile(value: draft.showDate, title: const Text('تاریخ شمسی امروز'), onChanged: (v) => update(draft.copyWith(showDate: v ?? false))),
              CheckboxListTile(value: draft.showOccasion, title: const Text('مناسبت امروز'), onChanged: (v) => update(draft.copyWith(showOccasion: v ?? false))),
              CheckboxListTile(value: draft.showMoonPhase, title: const Text('فاز ماه'), onChanged: (v) => update(draft.copyWith(showMoonPhase: v ?? false))),
              CheckboxListTile(value: draft.showScorpio, title: const Text('قمر در عقرب'), onChanged: (v) => update(draft.copyWith(showScorpio: v ?? false))),
              CheckboxListTile(value: draft.showNextEvent, title: const Text('جلسه یا کار بعدی'), onChanged: (v) => update(draft.copyWith(showNextEvent: v ?? false))),
            ])))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () async { await _refreshPersistentNotification(); if (sheetContext.mounted) Navigator.pop(sheetContext); },
              icon: const Icon(Icons.check_rounded),
              label: const Text('ذخیره'),
            )),
          ])),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const MahNegarDashboard(),
      PositionedDirectional(
        end: 14,
        bottom: 92,
        child: SafeArea(child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(18),
          elevation: 2,
          child: IconButton(
            tooltip: 'اعلان و Lock Screen',
            onPressed: _openNotificationSettings,
            icon: Icon(_prefs.enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
          ),
        )),
      ),
    ]);
  }
}
