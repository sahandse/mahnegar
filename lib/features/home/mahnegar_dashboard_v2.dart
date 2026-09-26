import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/branding/mahnegar_brand_logo.dart';
import '../../core/services/astronomy_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/birthday_service.dart';
import '../../core/services/device_calendar_service.dart';
import '../../core/services/home_widget_service.dart';
import '../../core/services/iran_holidays.dart';
import '../../core/services/local_store.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/quick_add_service.dart';
import '../../core/services/sky_times_service.dart';
import '../../main.dart';

enum CalendarViewMode { month, week, day }

class MahNegarDashboardV2 extends StatefulWidget {
  const MahNegarDashboardV2({super.key});

  @override
  State<MahNegarDashboardV2> createState() => _MahNegarDashboardV2State();
}

class _MahNegarDashboardV2State extends State<MahNegarDashboardV2> {
  final _store = LocalStore();
  final _astronomy = AstronomyService();
  final _holidays = IranHolidays();
  final _calendar = DeviceCalendarSyncService();
  final _quick = QuickAddService();
  final _backup = BackupService();
  final _birthdays = BirthdayService();
  final _widget = MahNegarHomeWidgetService();
  final _notifications = MahNegarNotificationService.instance;
  final _skyTimes = SkyTimesService();

  List<CalendarEntry> entries = [];
  late Jalali visibleMonth;
  late Jalali selectedDay;
  int tab = 0;
  bool busy = false;
  CalendarViewMode calendarMode = CalendarViewMode.month;

  bool showGregorian = true;
  bool showHijri = true;
  bool showHolidays = true;
  bool showAstronomyMarkers = true;
  SkyCity skyCity = SkyCity.presets.first;

  static const months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];
  static const weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    visibleMonth = Jalali(now.year, now.month, 1);
    selectedDay = now;
    _load();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    final prefs = await SharedPreferences.getInstance();
    final cityName = prefs.getString('sky_city') ?? SkyCity.presets.first.name;
    if (!mounted) return;
    setState(() {
      entries = loaded;
      showGregorian = prefs.getBool('calendar_show_gregorian') ?? true;
      showHijri = prefs.getBool('calendar_show_hijri') ?? true;
      showHolidays = prefs.getBool('calendar_show_holidays') ?? true;
      showAstronomyMarkers = prefs.getBool('calendar_show_astro') ?? true;
      skyCity = SkyCity.presets.firstWhere(
        (e) => e.name == cityName,
        orElse: () => SkyCity.presets.first,
      );
    });
    _widget.refresh().catchError((_) {});
  }

  String fa(Object value) => value
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

  List<CalendarEntry> _forDay(Jalali day) {
    final result = entries.where((e) {
      final j = Jalali.fromDateTime(e.start);
      return j.year == day.year && j.month == day.month && j.day == day.day;
    }).toList();
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  Future<void> _persist(List<CalendarEntry> value) async {
    entries = value..sort((a, b) => a.start.compareTo(b.start));
    await _store.save(entries);
    await _widget.refresh().catchError((_) {});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(children: [
          MahNegarBrandLogo(size: 42, borderRadius: 13),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ماه‌نگار', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('تقویم، برنامه و آسمان', style: TextStyle(fontSize: 11)),
          ]),
        ]),
        actions: [
          if (tab == 0 && !_isCurrentMonth)
            IconButton(onPressed: _goToday, tooltip: 'امروز', icon: const Icon(Icons.today_rounded)),
          IconButton(onPressed: _showSearch, tooltip: 'جستجو', icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: _showQuickAdd, tooltip: 'افزودن سریع', icon: const Icon(Icons.bolt_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (tab) {
            0 => _calendarPage(),
            1 => _timelinePage(),
            2 => _skyPage(),
            3 => _plannerPage(),
            _ => _settingsPage(),
          },
        ),
      ),
      floatingActionButton: tab == 0 || tab == 1 || tab == 3
          ? FloatingActionButton.extended(
              onPressed: _showAddEntry,
              onLongPress: _showQuickAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('افزودن'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'تقویم'),
          NavigationDestination(icon: Icon(Icons.view_timeline_outlined), selectedIcon: Icon(Icons.view_timeline_rounded), label: 'روز'),
          NavigationDestination(icon: Icon(Icons.nights_stay_outlined), selectedIcon: Icon(Icons.nights_stay_rounded), label: 'آسمان'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'برنامه'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'تنظیمات'),
        ],
      ),
    );
  }

  bool get _isCurrentMonth {
    final now = Jalali.now();
    return visibleMonth.year == now.year && visibleMonth.month == now.month;
  }

  void _goToday() {
    final now = Jalali.now();
    setState(() {
      selectedDay = now;
      visibleMonth = Jalali(now.year, now.month, 1);
    });
  }

  Widget _calendarPage() {
    final today = Jalali.now();
    return ListView(
      key: const ValueKey('calendar-v2'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _compactDateHero(selectedDay),
        const SizedBox(height: 12),
        SegmentedButton<CalendarViewMode>(
          segments: const [
            ButtonSegment(value: CalendarViewMode.month, label: Text('ماه')),
            ButtonSegment(value: CalendarViewMode.week, label: Text('هفته')),
            ButtonSegment(value: CalendarViewMode.day, label: Text('روز')),
          ],
          selected: {calendarMode},
          onSelectionChanged: (s) => setState(() => calendarMode = s.first),
        ),
        const SizedBox(height: 12),
        if (calendarMode == CalendarViewMode.month) _monthCalendar(today),
        if (calendarMode == CalendarViewMode.week) _weekCalendar(),
        if (calendarMode == CalendarViewMode.day) _daySummary(selectedDay),
        const SizedBox(height: 12),
        _occasionAndEventsCard(selectedDay),
        const SizedBox(height: 12),
        _nextItemCard(),
      ],
    );
  }

  Widget _compactDateHero(Jalali day) {
    final date = day.toDateTime();
    final greg = day.toGregorian();
    final hijri = HijriCalendar.fromDate(date);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF0B1C42), Color(0xFF203B84)]),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${fa(day.day)} ${months[day.month - 1]} ${fa(day.year)}', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Wrap(spacing: 10, runSpacing: 3, children: [
            if (showGregorian) Text('میلادی ${fa(greg.year)}/${fa(greg.month)}/${fa(greg.day)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (showHijri) Text('قمری ${fa(hijri.hYear)}/${fa(hijri.hMonth)}/${fa(hijri.hDay)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ])),
        const MahNegarBrandLogo(size: 50, borderRadius: 16),
      ]),
    );
  }

  Widget _monthCalendar(Jalali today) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 120) _changeMonth(v < 0 ? 1 : -1);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_right_rounded)),
              Expanded(child: Text('${months[visibleMonth.month - 1]} ${fa(visibleMonth.year)}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_left_rounded)),
            ]),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: .72,
              children: [
                for (final d in weekDays)
                  Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.w800, color: d == 'ج' ? Colors.redAccent : null))),
                for (var i = 0; i < _firstWeekday; i++) const SizedBox.shrink(),
                for (var d = 1; d <= _daysInMonth; d++) _dayCell(d, today),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dayCell(int d, Jalali today) {
    final current = Jalali(visibleMonth.year, visibleMonth.month, d);
    final selected = _sameDay(current, selectedDay);
    final isToday = _sameDay(current, today);
    final items = _forDay(current);
    final occasions = showHolidays ? _holidays.forDate(current) : <String>[];
    final holiday = showHolidays && _holidays.isHoliday(current);
    final inScorpio = showAstronomyMarkers && _astronomy.snapshot(current.toDateTime().add(const Duration(hours: 12))).isMoonInScorpio;
    final colors = Theme.of(context).colorScheme;
    final tiny = occasions.isNotEmpty ? occasions.first : (items.isNotEmpty ? items.first.title : '');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => selectedDay = current);
        _showDaySheet(current);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? colors.primary : (isToday ? colors.primaryContainer : null),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(fa(d), style: TextStyle(fontWeight: selected || isToday ? FontWeight.w900 : FontWeight.w600, color: selected ? colors.onPrimary : (holiday ? Colors.redAccent : null))),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (holiday) _dot(Colors.redAccent),
            if (items.isNotEmpty) ...[const SizedBox(width: 2), _dot(selected ? colors.onPrimary : colors.primary)],
            if (inScorpio) ...[const SizedBox(width: 2), Text('☾', style: TextStyle(fontSize: 8, color: selected ? colors.onPrimary : colors.tertiary))],
          ]),
          if (tiny.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(tiny, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 7, color: selected ? colors.onPrimary : colors.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }

  Widget _weekCalendar() {
    final start = selectedDay.toDateTime().subtract(Duration(days: (selectedDay.toDateTime().weekday + 1) % 7));
    final days = List.generate(7, (i) => Jalali.fromDateTime(start.add(Duration(days: i))));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          for (final d in days)
            Expanded(child: InkWell(
              onTap: () => setState(() => selectedDay = d),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(color: _sameDay(d, selectedDay) ? Theme.of(context).colorScheme.primaryContainer : null, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text(weekDays[days.indexOf(d)], style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 5),
                  Text(fa(d.day), style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (_forDay(d).isNotEmpty) ...[const SizedBox(height: 4), _dot(Theme.of(context).colorScheme.primary)],
                  if (_holidays.forDate(d).isNotEmpty) const Icon(Icons.flag_rounded, size: 10, color: Colors.redAccent),
                ]),
              ),
            )),
        ]),
      ),
    );
  }

  Widget _daySummary(Jalali day) {
    final items = _forDay(day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('برنامه روز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (items.isEmpty) _empty('برنامه‌ای ثبت نشده', 'جلسه، کار یا یادآوری اضافه کن.') else ...items.map(_entryTile),
        ]),
      ),
    );
  }

  Widget _occasionAndEventsCard(Jalali day) {
    final occasions = _holidays.forDate(day);
    final items = _forDay(day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_available_rounded),
            const SizedBox(width: 8),
            Expanded(child: Text('مناسبت‌ها و رویدادها', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          if (occasions.isEmpty && items.isEmpty) _empty('چیزی برای این روز نیست', 'مناسبت یا برنامه ثبت‌شده‌ای وجود ندارد.'),
          for (final occasion in occasions)
            ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.flag_rounded, color: Colors.redAccent), title: Text(occasion, style: const TextStyle(fontWeight: FontWeight.w700))),
          for (final item in items) _entryTile(item),
        ]),
      ),
    );
  }

  Widget _nextItemCard() {
    final now = DateTime.now();
    final upcoming = entries.where((e) => !e.completed && e.start.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final e = upcoming.first;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.upcoming_rounded),
        title: const Text('برنامه بعدی', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${e.title} • ${fa(DateFormat('MM/dd HH:mm').format(e.start))}'),
      ),
    );
  }

  Widget _timelinePage() {
    final items = _forDay(selectedDay);
    return ListView(
      key: const ValueKey('timeline-v2'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _compactDateHero(selectedDay),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(onPressed: () => _shiftDay(-1), icon: const Icon(Icons.chevron_right_rounded)),
          Expanded(child: Text('نمای روزانه', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => _shiftDay(1), icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        const SizedBox(height: 8),
        Card(child: Column(children: [for (var h = 0; h < 24; h++) _hourRow(h, items.where((e) => e.start.hour == h).toList())])),
      ],
    );
  }

  Widget _hourRow(int hour, List<CalendarEntry> items) => DragTarget<CalendarEntry>(
        onAcceptWithDetails: (details) async {
          final e = details.data;
          final start = DateTime(selectedDay.toDateTime().year, selectedDay.toDateTime().month, selectedDay.toDateTime().day, hour, e.start.minute);
          await _persist(entries.map((x) => x.id == e.id ? x.copyWith(start: start, end: start.add(e.end.difference(e.start))) : x).toList());
        },
        builder: (context, candidate, rejected) => Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: candidate.isNotEmpty ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35) : null, border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .2)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 48, child: Text('${fa(hour.toString().padLeft(2, '0'))}:۰۰', style: Theme.of(context).textTheme.labelMedium)),
            Expanded(child: Column(children: items.map((e) => LongPressDraggable<CalendarEntry>(
              data: e,
              feedback: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Text(e.title))),
              child: Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700))),
            )).toList())),
          ]),
        ),
      );

  Widget _skyPage() {
    final now = DateTime.now();
    final snap = _astronomy.snapshot(now);
    final phases = _astronomy.upcomingMajorPhases(now).take(4).toList();
    final window = _astronomy.scorpioWindow(now);
    final times = _skyTimes.calculate(now, skyCity);
    final remain = snap.isMoonInScorpio && window.end != null ? window.end!.difference(now) : null;
    return ListView(
      key: const ValueKey('sky-v2'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [Color(0xFF07152F), Color(0xFF243D85)])),
          child: Column(children: [
            const Icon(Icons.nightlight_round, color: Color(0xFFFFD77A), size: 92),
            const SizedBox(height: 10),
            Text(snap.phaseName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text('روشنایی ${fa((snap.illumination * 100).round())}٪ • سن ماه ${fa(snap.moonAgeDays.toStringAsFixed(1))} روز', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text('فاصله تقریبی ${fa(snap.distanceKm.round())} کیلومتر', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric('برج ماه', snap.zodiacName, Icons.explore_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _metric('طول دایرةالبروج', '${fa(snap.moonLongitude.toStringAsFixed(1))}°', Icons.motion_photos_on_outlined)),
        ]),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('♏', style: TextStyle(fontSize: 30)), const SizedBox(width: 10), Expanded(child: Text('قمر در عقرب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          Text(snap.isMoonInScorpio ? 'اکنون فعال است' : 'اکنون فعال نیست'),
          if (window.start != null) Text('شروع: ${fa(DateFormat('yyyy/MM/dd HH:mm').format(window.start!))}'),
          if (window.end != null) Text('پایان: ${fa(DateFormat('yyyy/MM/dd HH:mm').format(window.end!))}'),
          if (remain != null) Text('باقی‌مانده: ${fa(remain.inHours)} ساعت و ${fa(remain.inMinutes.remainder(60))} دقیقه'),
        ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.location_city_outlined), const SizedBox(width: 8), Text('طلوع و غروب • ${skyCity.name}', style: const TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _timeChip('طلوع خورشید', times.sunrise),
            _timeChip('غروب خورشید', times.sunset),
            _timeChip('طلوع ماه', times.moonrise),
            _timeChip('غروب ماه', times.moonset),
          ]),
          const SizedBox(height: 8),
          Text('ساعت‌ها بر اساس منطقه زمانی دستگاه نمایش داده می‌شوند.', style: Theme.of(context).textTheme.bodySmall),
        ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('رویدادهای بعدی ماه', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final event in phases) ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.circle_outlined, size: 18), title: Text(event.name), trailing: Text(fa(DateFormat('MM/dd HH:mm').format(event.time)))),
        ]))),
        const SizedBox(height: 10),
        _moonCalendarStrip(),
        const SizedBox(height: 10),
        Card(child: const ListTile(leading: Icon(Icons.science_outlined), title: Text('نجوم و استرولوژی جدا هستند'), subtitle: Text('موقعیت، فاز و زمان‌های آسمانی محاسبات نجومی‌اند؛ تعبیرهای استرولوژی فقط محتوای فرهنگی/سرگرمی هستند.'))),
      ],
    );
  }

  Widget _moonCalendarStrip() {
    final start = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('۱۴ روز آینده ماه', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SizedBox(height: 72, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 14, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, i) {
            final date = start.add(Duration(days: i));
            final s = _astronomy.snapshot(date);
            return Container(width: 58, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Column(children: [
              Text(fa(DateFormat('MM/dd').format(date)), style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 4),
              Text(s.isMoonInScorpio ? '♏' : '☾', style: const TextStyle(fontSize: 20)),
              Text('${fa((s.illumination * 100).round())}٪', style: const TextStyle(fontSize: 9)),
            ]));
          })),
        ]),
      ),
    );
  }

  Widget _plannerPage() {
    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    final future = sorted.where((e) => e.start.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
    return ListView(key: const ValueKey('planner-v2'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
      Text('برنامه‌ها و کارها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (future.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: _empty('برنامه‌ای نداری', 'با + یا افزودن سریع شروع کن.'))) else ...future.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _entryTile(e))))),
    ]);
  }

  Widget _settingsPage() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(key: const ValueKey('settings-v2'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
      Text('تنظیمات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        SwitchListTile(value: dark, secondary: const Icon(Icons.dark_mode_outlined), title: const Text('دارک مود'), onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light),
        ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('اعلان و نوار وضعیت'), subtitle: const Text('تاریخ، مناسبت، فاز ماه، قمر در عقرب و برنامه بعدی'), trailing: const Icon(Icons.chevron_left_rounded), onTap: _notificationSettings),
        ListTile(leading: const Icon(Icons.wb_sunny_outlined), title: const Text('خلاصه صبحگاهی'), subtitle: const Text('اعلان اختیاری برنامه و مناسبت امروز'), onTap: _configureMorning),
      ])),
      const SizedBox(height: 10),
      Card(child: Column(children: [
        SwitchListTile(value: showGregorian, title: const Text('نمایش تاریخ میلادی'), onChanged: (v) => _saveCalendarSetting('calendar_show_gregorian', v, () => showGregorian = v)),
        SwitchListTile(value: showHijri, title: const Text('نمایش تاریخ قمری'), onChanged: (v) => _saveCalendarSetting('calendar_show_hijri', v, () => showHijri = v)),
        SwitchListTile(value: showHolidays, title: const Text('نمایش تعطیلات و مناسبت‌ها'), onChanged: (v) => _saveCalendarSetting('calendar_show_holidays', v, () => showHolidays = v)),
        SwitchListTile(value: showAstronomyMarkers, title: const Text('علائم نجومی در تقویم'), subtitle: const Text('نمایش نشان قمر در عقرب روی روزها'), onChanged: (v) => _saveCalendarSetting('calendar_show_astro', v, () => showAstronomyMarkers = v)),
      ])),
      const SizedBox(height: 10),
      Card(child: ListTile(
        leading: const Icon(Icons.location_city_outlined),
        title: const Text('شهر محاسبات آسمان'),
        subtitle: Text('${skyCity.name} • بدون نیاز به GPS'),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: _chooseSkyCity,
      )),
      const SizedBox(height: 10),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('همگام‌سازی Google Calendar'), subtitle: const Text('انتخاب تقویم‌ها و دریافت رویدادهای واقعی'), onTap: _syncGoogle),
        ListTile(leading: const Icon(Icons.widgets_outlined), title: const Text('ویجت صفحه اصلی'), subtitle: const Text('تاریخ، مناسبت، ماه و برنامه بعدی'), onTap: _pinWidget),
        ListTile(leading: const Icon(Icons.cake_outlined), title: const Text('تولد و سالگرد از مخاطبین'), subtitle: const Text('فقط با اجازه و انتخاب خودت'), onTap: _importBirthday),
      ])),
      const SizedBox(height: 10),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Backup / ذخیره فایل یا Google Drive'), onTap: _exportBackup),
        ListTile(leading: const Icon(Icons.restore_rounded), title: const Text('Restore / بازیابی'), onTap: _importBackup),
      ])),
      const SizedBox(height: 10),
      const Card(child: ListTile(leading: MahNegarBrandLogo(size: 48, borderRadius: 14), title: Text('ماه‌نگار', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('داده واقعی • بدون دیتای دمو • دسترسی‌ها اختیاری'))),
    ]);
  }

  Future<void> _notificationSettings() async {
    var draft = await _notifications.loadPreferences();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true, builder: (sheet) => StatefulBuilder(builder: (context, setSheet) {
      Future<void> update(NotificationPreferences p) async {
        draft = p;
        await _notifications.savePreferences(p);
        if (!p.enabled) await _notifications.hideStatus();
        setSheet(() {});
      }
      return Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('اعلان و نوار وضعیت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        SwitchListTile(value: draft.enabled, title: const Text('نمایش اعلان دائمی'), subtitle: const Text('کم‌اهمیت، بدون صدا و کاملاً اختیاری'), onChanged: (v) async {
          if (v && !await _notifications.requestPermission()) return;
          await update(draft.copyWith(enabled: v));
        }),
        Opacity(opacity: draft.enabled ? 1 : .45, child: IgnorePointer(ignoring: !draft.enabled, child: Column(children: [
          CheckboxListTile(value: draft.showDate, title: const Text('تاریخ شمسی امروز'), onChanged: (v) => update(draft.copyWith(showDate: v ?? false))),
          CheckboxListTile(value: draft.showOccasion, title: const Text('مناسبت امروز'), onChanged: (v) => update(draft.copyWith(showOccasion: v ?? false))),
          CheckboxListTile(value: draft.showMoonPhase, title: const Text('فاز ماه'), onChanged: (v) => update(draft.copyWith(showMoonPhase: v ?? false))),
          CheckboxListTile(value: draft.showScorpio, title: const Text('قمر در عقرب'), onChanged: (v) => update(draft.copyWith(showScorpio: v ?? false))),
          CheckboxListTile(value: draft.showNextEvent, title: const Text('جلسه یا کار بعدی'), onChanged: (v) => update(draft.copyWith(showNextEvent: v ?? false))),
        ]))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          if (draft.enabled) await _refreshStatus(draft);
          if (sheet.mounted) Navigator.pop(sheet);
        }, child: const Text('ذخیره'))),
      ])));
    }));
  }

  Future<void> _refreshStatus(NotificationPreferences prefs) async {
    final now = DateTime.now();
    final j = Jalali.now();
    final snap = _astronomy.snapshot(now);
    final items = entries.where((e) => !e.completed && e.start.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final occasions = _holidays.forDate(j);
    final parts = <String>[];
    if (prefs.showDate) parts.add('${fa(j.day)} ${months[j.month - 1]} ${fa(j.year)}');
    if (prefs.showOccasion && occasions.isNotEmpty) parts.add(occasions.first);
    if (prefs.showMoonPhase) parts.add(snap.phaseName);
    if (prefs.showScorpio) parts.add(snap.isMoonInScorpio ? 'قمر در عقرب' : 'خارج از عقرب');
    if (prefs.showNextEvent && items.isNotEmpty) parts.add('بعدی: ${items.first.title}');
    await _notifications.showStatus(title: 'ماه‌نگار', body: parts.join(' • '));
  }

  Future<void> _showDaySheet(Jalali day) async {
    final occasions = _holidays.forDate(day);
    final items = _forDay(day);
    final snap = _astronomy.snapshot(day.toDateTime().add(const Duration(hours: 12)));
    await showModalBottomSheet<void>(context: context, showDragHandle: true, useSafeArea: true, builder: (context) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${fa(day.day)} ${months[day.month - 1]} ${fa(day.year)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (occasions.isNotEmpty) ...occasions.map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.flag_rounded, color: Colors.redAccent), title: Text(e))),
      ...items.map(_entryTile),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.nights_stay_outlined), title: Text('${snap.phaseName} • ${snap.zodiacName}'), subtitle: Text(snap.isMoonInScorpio ? 'قمر در عقرب' : 'خارج از عقرب')),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(context); _showAddEntry(); }, icon: const Icon(Icons.add), label: const Text('افزودن برنامه'))),
    ]))));
  }

  Future<void> _chooseSkyCity() async {
    final selected = await showDialog<SkyCity>(context: context, builder: (context) => AlertDialog(title: const Text('شهر محاسبات آسمان'), content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: SkyCity.presets.map((c) => RadioListTile<SkyCity>(value: c, groupValue: skyCity, title: Text(c.name), onChanged: (v) => Navigator.pop(context, v))).toList()))));
    if (selected == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sky_city', selected.name);
    if (mounted) setState(() => skyCity = selected);
  }

  Future<void> _saveCalendarSetting(String key, bool value, VoidCallback apply) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (mounted) setState(apply);
  }

  Widget _entryTile(CalendarEntry e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [
    Icon(e.isBirthday ? Icons.cake_outlined : e.isTodo ? Icons.check_circle_outline : Icons.event_outlined, size: 20),
    const SizedBox(width: 9),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: e.completed ? TextDecoration.lineThrough : null)),
      Text('${fa(DateFormat('HH:mm').format(e.start))}${e.syncedCalendarId == null ? '' : ' • Google'}', style: Theme.of(context).textTheme.bodySmall),
    ])),
    if (e.isTodo) Checkbox(value: e.completed, onChanged: (_) => _toggleTodo(e)),
  ]));

  Widget _metric(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Icon(icon), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.w900)), Text(title, style: Theme.of(context).textTheme.bodySmall)])));

  Widget _timeChip(String label, DateTime? value) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Text('$label: ${value == null ? '—' : fa(DateFormat('HH:mm').format(value))}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));

  Widget _dot(Color color) => Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  bool _sameDay(Jalali a, Jalali b) => a.year == b.year && a.month == b.month && a.day == b.day;

  int get _daysInMonth {
    final next = visibleMonth.month == 12 ? Jalali(visibleMonth.year + 1, 1, 1) : Jalali(visibleMonth.year, visibleMonth.month + 1, 1);
    return next.toDateTime().difference(visibleMonth.toDateTime()).inDays;
  }

  int get _firstWeekday => (visibleMonth.toDateTime().weekday + 1) % 7;

  void _changeMonth(int delta) {
    var y = visibleMonth.year;
    var m = visibleMonth.month + delta;
    if (m < 1) { y--; m = 12; }
    if (m > 12) { y++; m = 1; }
    setState(() => visibleMonth = Jalali(y, m, 1));
  }

  void _shiftDay(int delta) => setState(() => selectedDay = Jalali.fromDateTime(selectedDay.toDateTime().add(Duration(days: delta))));

  Future<void> _toggleTodo(CalendarEntry entry) async => _persist(entries.map((e) => e.id == entry.id ? e.copyWith(completed: !e.completed) : e).toList());

  Future<void> _showQuickAdd() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('افزودن سریع'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'مثلاً: جلسه شنبه ساعت ۱۴ با علی')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('ادامه'))]));
    if (text == null || text.trim().isEmpty) return;
    final parsed = _quick.parse(text);
    await _persist([...entries, CalendarEntry(id: 'quick-${DateTime.now().microsecondsSinceEpoch}', title: parsed.title, start: parsed.start, end: parsed.end, isTodo: parsed.isTodo)]);
  }

  Future<void> _showAddEntry() async {
    final title = TextEditingController();
    var isTodo = false;
    var syncGoogle = false;
    var start = selectedDay.toDateTime().add(const Duration(hours: 9));
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheet) => StatefulBuilder(builder: (context, setSheet) => Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان جلسه یا کار')),
      SwitchListTile(value: isTodo, title: const Text('Todo'), onChanged: (v) => setSheet(() => isTodo = v)),
      if (!isTodo) SwitchListTile(value: syncGoogle, title: const Text('ارسال به Google Calendar'), onChanged: (v) => setSheet(() => syncGoogle = v)),
      ListTile(leading: const Icon(Icons.schedule), title: Text(fa(DateFormat('yyyy/MM/dd HH:mm').format(start))), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start)); if (t != null) setSheet(() => start = DateTime(start.year, start.month, start.day, t.hour, t.minute)); }),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
        if (title.text.trim().isEmpty) return;
        var e = CalendarEntry(id: 'local-${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(), start: start, end: start.add(Duration(minutes: isTodo ? 30 : 60)), isTodo: isTodo);
        if (syncGoogle) { try { final id = await _calendar.addMeeting(e); e = e.copyWith(syncedCalendarId: 'default', externalEventId: id); } catch (_) {} }
        await _persist([...entries, e]);
        if (sheet.mounted) Navigator.pop(sheet);
      }, child: const Text('ذخیره'))),
    ]))));
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController();
    var query = '';
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheet) => StatefulBuilder(builder: (context, setSheet) {
      final q = query.trim().toLowerCase();
      final matches = q.isEmpty ? <CalendarEntry>[] : entries.where((e) => '${e.title} ${e.description} ${e.location}'.toLowerCase().contains(q)).toList();
      final occasionMatches = q.isEmpty ? <String>[] : _occasionSearch(q);
      return SizedBox(height: MediaQuery.of(context).size.height * .72, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: controller, autofocus: true, onChanged: (v) => setSheet(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجوی جلسه، کار و مناسبت')),
        const SizedBox(height: 10),
        Expanded(child: ListView(children: [...matches.map((e) => ListTile(leading: const Icon(Icons.event), title: Text(e.title))), ...occasionMatches.map((e) => ListTile(leading: const Icon(Icons.flag_outlined), title: Text(e)))])),
      ])));
    }));
  }

  List<String> _occasionSearch(String query) {
    final year = Jalali.now().year;
    final result = <String>[];
    var date = Jalali(year, 1, 1);
    for (var i = 0; i < 366; i++) {
      if (date.year != year) break;
      for (final occasion in _holidays.forDate(date)) {
        if (occasion.toLowerCase().contains(query)) result.add('${fa(date.month)}/${fa(date.day)} • $occasion');
      }
      date = Jalali.fromDateTime(date.toDateTime().add(const Duration(days: 1)));
    }
    return result.take(40).toList();
  }

  Future<void> _syncGoogle() async {
    await _withBusy(() async {
      final calendars = await _calendar.googleCalendars();
      if (!mounted) return;
      if (calendars.isEmpty) { _snack('تقویم Google قابل دسترسی پیدا نشد.'); return; }
      final selected = <String>{...calendars.map((c) => c.id)};
      final ids = await showDialog<List<String>>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('تقویم‌های Google'), content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: calendars.map((Calendar c) => CheckboxListTile(value: selected.contains(c.id), title: Text(c.name), subtitle: Text(c.accountName ?? ''), onChanged: (v) => setDialog(() { if (v == true) { selected.add(c.id); } else { selected.remove(c.id); } }))).toList())), actions: [FilledButton(onPressed: () => Navigator.pop(dialog, selected.toList()), child: const Text('همگام‌سازی'))]))));
      if (ids == null || ids.isEmpty) return;
      final merged = await _calendar.syncIntoLocal(_store, calendarIds: ids);
      if (mounted) setState(() => entries = merged);
      await _widget.refresh().catchError((_) {});
    });
  }

  Future<void> _pinWidget() async => _withBusy(() async { await _widget.requestPin(); _snack('درخواست افزودن ویجت ارسال شد.'); });

  Future<void> _importBirthday() async => _withBusy(() async { final result = await _birthdays.pickAndImport(); if (result == null) return; final merged = await _store.merge(result.entries); if (mounted) setState(() => entries = merged); });

  Future<void> _exportBackup() async => _withBusy(() async { final ok = await _backup.exportBackup(); _snack(ok ? 'فایل پشتیبان ذخیره شد.' : 'ذخیره لغو شد.'); });

  Future<void> _importBackup() async => _withBusy(() async { final imported = await _backup.importBackup(); if (imported != null && mounted) setState(() => entries = imported); });

  Future<void> _configureMorning() async {
    final prefs = await _notifications.loadPreferences();
    if (!mounted) return;
    final enable = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('خلاصه صبحگاهی'), content: Text(prefs.morningSummary ? 'خلاصه صبحگاهی غیرفعال شود؟' : 'هر روز ساعت ۸ خلاصه برنامه و مناسبت نمایش داده شود؟'), actions: [FilledButton(onPressed: () => Navigator.pop(context, !prefs.morningSummary), child: Text(prefs.morningSummary ? 'غیرفعال کن' : 'فعال کن'))]));
    if (enable == null) return;
    final updated = prefs.copyWith(morningSummary: enable, morningHour: 8);
    await _notifications.savePreferences(updated);
    if (enable) { if (await _notifications.requestPermission()) await _notifications.scheduleMorningSummary(hour: 8, body: _morningText()); } else { await _notifications.cancelMorningSummary(); }
  }

  String _morningText() {
    final today = Jalali.now();
    final items = _forDay(today);
    final occasions = _holidays.forDate(today);
    final snap = _astronomy.snapshot(DateTime.now());
    return ['${fa(today.day)} ${months[today.month - 1]}', if (occasions.isNotEmpty) occasions.first, if (items.isNotEmpty) '${fa(items.length)} برنامه', snap.isMoonInScorpio ? 'قمر در عقرب' : snap.phaseName].join(' • ');
  }

  Future<void> _withBusy(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try { await task(); } catch (e) { _snack('عملیات انجام نشد: $e'); } finally { if (mounted) setState(() => busy = false); }
  }

  void _snack(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Widget _empty(String title, String subtitle) => Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(children: [const Icon(Icons.inbox_outlined, size: 34), const SizedBox(height: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]));
}
