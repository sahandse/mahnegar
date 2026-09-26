import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
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
import '../../main.dart';

class MahNegarDashboard extends StatefulWidget {
  const MahNegarDashboard({super.key});

  @override
  State<MahNegarDashboard> createState() => _MahNegarDashboardState();
}

class _MahNegarDashboardState extends State<MahNegarDashboard> {
  final _store = LocalStore();
  final _astronomy = AstronomyService();
  final _holidays = IranHolidays();
  final _calendar = DeviceCalendarSyncService();
  final _quick = QuickAddService();
  final _backup = BackupService();
  final _birthdays = BirthdayService();
  final _widget = MahNegarHomeWidgetService();
  final _notifications = MahNegarNotificationService.instance;

  List<CalendarEntry> entries = [];
  late Jalali visibleMonth;
  late Jalali selectedDay;
  int tab = 0;
  bool busy = false;

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
    if (!mounted) return;
    setState(() => entries = loaded);
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
            Text('تقویم، برنامه و آسمان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ]),
        ]),
        actions: [
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

  Widget _calendarPage() {
    final today = Jalali.now();
    return ListView(
      key: const ValueKey('calendar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _dateHero(selectedDay),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_right_rounded)),
                Expanded(child: Column(children: [
                  Text('${months[visibleMonth.month - 1]} ${fa(visibleMonth.year)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text('شمسی • میلادی • قمری', style: Theme.of(context).textTheme.labelMedium),
                ])),
                IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_left_rounded)),
              ]),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: .78,
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
        const SizedBox(height: 14),
        _agendaCard(),
      ],
    );
  }

  Widget _dateHero(Jalali day) {
    final date = day.toDateTime();
    final greg = day.toGregorian();
    final hijri = HijriCalendar.fromDate(date);
    final snap = _astronomy.snapshot(date.add(const Duration(hours: 12)));
    final occasions = _holidays.forDate(day);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0B1C42), Color(0xFF203B84)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${fa(day.day)} ${months[day.month - 1]} ${fa(day.year)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
          const MahNegarBrandLogo(size: 48, borderRadius: 15),
        ]),
        const SizedBox(height: 6),
        Text('میلادی ${fa(greg.year)}/${fa(greg.month)}/${fa(greg.day)}  •  قمری ${fa(hijri.hYear)}/${fa(hijri.hMonth)}/${fa(hijri.hDay)}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _darkChip('فاز ماه: ${snap.phaseName}'),
          _darkChip(snap.isMoonInScorpio ? 'قمر در عقرب' : 'خارج از عقرب'),
          if (occasions.isNotEmpty) _darkChip(occasions.first),
        ]),
      ]),
    );
  }

  Widget _darkChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _dayCell(int d, Jalali today) {
    final current = Jalali(visibleMonth.year, visibleMonth.month, d);
    final selected = current.year == selectedDay.year && current.month == selectedDay.month && current.day == selectedDay.day;
    final isToday = current.year == today.year && current.month == today.month && current.day == today.day;
    final holiday = _holidays.isHoliday(current);
    final items = _forDay(current);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => selectedDay = current),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? colors.primary : (isToday ? colors.primaryContainer : null),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(fa(d), style: TextStyle(fontWeight: selected || isToday ? FontWeight.w900 : FontWeight.w600, color: selected ? colors.onPrimary : (holiday ? Colors.redAccent : null))),
          const SizedBox(height: 3),
          if (items.isNotEmpty) Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? colors.onPrimary : colors.primary)),
        ]),
      ),
    );
  }

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

  Widget _agendaCard() {
    final items = _forDay(selectedDay);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('برنامه این روز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            Text('${fa(items.length)} مورد'),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty) _empty('برنامه‌ای ثبت نشده', 'جلسه، کار یا یادآوری اضافه کن.') else ...items.map(_entryTile),
        ]),
      ),
    );
  }

  Widget _timelinePage() {
    final items = _forDay(selectedDay);
    return ListView(
      key: const ValueKey('timeline'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _dateHero(selectedDay),
        const SizedBox(height: 14),
        Row(children: [
          IconButton(onPressed: () => setState(() => selectedDay = Jalali.fromDateTime(selectedDay.toDateTime().subtract(const Duration(days: 1)))), icon: const Icon(Icons.chevron_right_rounded)),
          Expanded(child: Text('نمای روزانه', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => setState(() => selectedDay = Jalali.fromDateTime(selectedDay.toDateTime().add(const Duration(days: 1)))), icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (var hour = 6; hour <= 23; hour++) _hourRow(hour, items.where((e) => e.start.hour == hour).toList()),
          ]),
        ),
      ],
    );
  }

  Widget _hourRow(int hour, List<CalendarEntry> hourItems) => Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .2)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 46, child: Text('${fa(hour.toString().padLeft(2, '0'))}:۰۰', style: Theme.of(context).textTheme.labelMedium)),
          Expanded(child: hourItems.isEmpty
              ? const SizedBox.shrink()
              : Column(children: hourItems.map((e) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  )).toList())),
        ]),
      );

  Widget _skyPage() {
    final now = DateTime.now();
    final snap = _astronomy.snapshot(now);
    final transition = _astronomy.nextScorpioTransition(now, entering: !snap.isMoonInScorpio);
    return ListView(
      key: const ValueKey('sky'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [Color(0xFF07152F), Color(0xFF243D85)])),
          child: Column(children: [
            const MahNegarBrandLogo(size: 96, borderRadius: 28),
            const SizedBox(height: 14),
            Text(snap.phaseName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text('روشنایی ${fa((snap.illumination * 100).round())}٪', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _metric('برج ماه', snap.zodiacName, Icons.explore_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _metric('طول ماه', '${fa(snap.moonLongitude.toStringAsFixed(1))}°', Icons.motion_photos_on_outlined)),
        ]),
        const SizedBox(height: 10),
        Card(child: ListTile(
          leading: const Text('♏', style: TextStyle(fontSize: 32)),
          title: const Text('قمر در عقرب', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${snap.isMoonInScorpio ? 'اکنون فعال است' : 'اکنون فعال نیست'}${transition == null ? '' : '\nتغییر بعدی: ${fa(DateFormat('yyyy/MM/dd HH:mm').format(transition))}'}'),
        )),
        const SizedBox(height: 10),
        Card(child: ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('محاسبات نجومی'),
          subtitle: const Text('فاز ماه و موقعیت آن محاسبات نجومی هستند. تعبیرهای استرولوژی در ماه‌نگار به‌عنوان محتوای فرهنگی/سرگرمی از داده نجومی جدا نگه داشته می‌شوند.'),
        )),
      ],
    );
  }

  Widget _metric(String title, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [Icon(icon), const SizedBox(height: 8), Text(title), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
        ),
      );

  Widget _plannerPage() {
    final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    final future = sorted.where((e) => e.start.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
    return ListView(
      key: const ValueKey('planner'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(children: [
          Expanded(child: Text('برنامه‌ها و کارها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
          IconButton(onPressed: _showSearch, icon: const Icon(Icons.search_rounded)),
        ]),
        const SizedBox(height: 12),
        if (future.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: _empty('برنامه‌ای نداری', 'با + یا افزودن سریع شروع کن.')))
        else ...future.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _entryTile(e))))),
      ],
    );
  }

  Widget _entryTile(CalendarEntry e) => Row(children: [
        Icon(e.isBirthday ? Icons.cake_outlined : e.isTodo ? Icons.check_circle_outline : Icons.event_outlined),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: e.completed ? TextDecoration.lineThrough : null)),
          Text('${fa(DateFormat('yyyy/MM/dd HH:mm').format(e.start))}${e.syncedCalendarId == null ? '' : ' • Google'}', style: Theme.of(context).textTheme.bodySmall),
        ])),
        if (e.isTodo) Checkbox(value: e.completed, onChanged: (_) => _toggleTodo(e)),
      ]);

  Future<void> _toggleTodo(CalendarEntry entry) async {
    await _persist(entries.map((e) => e.id == entry.id ? e.copyWith(completed: !e.completed) : e).toList());
  }

  Widget _settingsPage() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Text('تنظیمات و ابزارها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          SwitchListTile(
            value: dark,
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('دارک مود'),
            subtitle: const Text('تغییر سریع بین حالت روشن و تیره'),
            onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
          ),
          ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('همگام‌سازی Google Calendar'), subtitle: const Text('انتخاب تقویم‌ها و دریافت رویدادهای واقعی'), trailing: const Icon(Icons.chevron_left_rounded), onTap: _syncGoogle),
          ListTile(leading: const Icon(Icons.widgets_outlined), title: const Text('ویجت صفحه اصلی'), subtitle: const Text('تاریخ، مناسبت، ماه و برنامه بعدی'), trailing: const Icon(Icons.add_to_home_screen_rounded), onTap: _pinWidget),
          ListTile(leading: const Icon(Icons.cake_outlined), title: const Text('تولد و سالگرد از مخاطبین'), subtitle: const Text('فقط با انتخاب و اجازه خودت'), trailing: const Icon(Icons.person_add_alt_rounded), onTap: _importBirthday),
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Backup / ذخیره در فایل یا Google Drive'), subtitle: const Text('از پنجره ذخیره اندروید، Drive را هم می‌توانی انتخاب کنی'), onTap: _exportBackup),
          ListTile(leading: const Icon(Icons.restore_rounded), title: const Text('Restore / بازیابی'), subtitle: const Text('ورود فایل JSON ماه‌نگار و ادغام امن داده‌ها'), onTap: _importBackup),
          ListTile(leading: const Icon(Icons.wb_sunny_outlined), title: const Text('خلاصه صبحگاهی'), subtitle: const Text('اعلان اختیاری هر روز ساعت ۸ با برنامه امروز'), onTap: _configureMorning),
          ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('نمایش روی Lock Screen'), subtitle: const Text('اعلان‌های انتخابی ماه‌نگار قابلیت نمایش عمومی روی قفل صفحه دارند')),
        ])),
        const SizedBox(height: 12),
        Card(child: const ListTile(
          leading: MahNegarBrandLogo(size: 48, borderRadius: 14),
          title: Text('ماه‌نگار 1.1.0', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('بدون دیتای دمو • داده‌های شخصی روی دستگاه • دسترسی‌ها اختیاری'),
        )),
      ],
    );
  }

  Future<void> _showQuickAdd() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن سریع'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'مثلاً: جلسه شنبه ساعت ۱۴ با علی')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('ادامه'))],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final parsed = _quick.parse(text);
    final entry = CalendarEntry(id: 'quick-${DateTime.now().microsecondsSinceEpoch}', title: parsed.title, start: parsed.start, end: parsed.end, isTodo: parsed.isTodo);
    await _persist([...entries, entry]);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${entry.title}» اضافه شد.')));
  }

  Future<void> _showAddEntry() async {
    final title = TextEditingController();
    var isTodo = false;
    var syncGoogle = false;
    var start = selectedDay.toDateTime().add(const Duration(hours: 9));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان جلسه یا کار')),
          const SizedBox(height: 10),
          SwitchListTile(value: isTodo, title: const Text('این مورد یک کار (Todo) است'), onChanged: (v) => setSheet(() => isTodo = v)),
          if (!isTodo) SwitchListTile(value: syncGoogle, title: const Text('ارسال به Google Calendar'), onChanged: (v) => setSheet(() => syncGoogle = v)),
          ListTile(leading: const Icon(Icons.schedule_rounded), title: Text('زمان: ${fa(DateFormat('yyyy/MM/dd HH:mm').format(start))}'), onTap: () async {
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
            if (time != null) setSheet(() => start = DateTime(start.year, start.month, start.day, time.hour, time.minute));
          }),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
            if (title.text.trim().isEmpty) return;
            var entry = CalendarEntry(id: 'local-${DateTime.now().microsecondsSinceEpoch}', title: title.text.trim(), start: start, end: start.add(Duration(minutes: isTodo ? 30 : 60)), isTodo: isTodo);
            if (syncGoogle) {
              try {
                final id = await _calendar.addMeeting(entry);
                entry = entry.copyWith(syncedCalendarId: 'default', externalEventId: id);
              } catch (_) {}
            }
            await _persist([...entries, entry]);
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('ذخیره'))),
        ]),
      )),
    );
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController();
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        final q = query.trim().toLowerCase();
        final matches = q.isEmpty ? <CalendarEntry>[] : entries.where((e) => '${e.title} ${e.description} ${e.location}'.toLowerCase().contains(q)).toList();
        final occasionMatches = q.isEmpty ? <String>[] : _occasionSearch(q);
        return SizedBox(height: MediaQuery.of(context).size.height * .75, child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: controller, autofocus: true, onChanged: (v) => setSheet(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجوی جلسه، کار و مناسبت')),
            const SizedBox(height: 12),
            Expanded(child: ListView(children: [
              ...matches.map((e) => ListTile(leading: Icon(e.isTodo ? Icons.task_alt : Icons.event), title: Text(e.title), subtitle: Text(fa(DateFormat('yyyy/MM/dd').format(e.start))))),
              ...occasionMatches.map((e) => ListTile(leading: const Icon(Icons.flag_outlined), title: Text(e))),
              if (q.isNotEmpty && matches.isEmpty && occasionMatches.isEmpty) _empty('نتیجه‌ای پیدا نشد', 'عبارت دیگری امتحان کن.'),
            ])),
          ]),
        ));
      }),
    );
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
      if (calendars.isEmpty) {
        _snack('تقویم Google قابل دسترسی پیدا نشد؛ ابتدا حساب Google را با Calendar گوشی همگام کن.');
        return;
      }
      final selected = <String>{...calendars.map((c) => c.id)};
      final ids = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
          title: const Text('تقویم‌های Google'),
          content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: calendars.map((Calendar c) => CheckboxListTile(
            value: selected.contains(c.id),
            title: Text(c.name),
            subtitle: Text(c.accountName ?? ''),
            onChanged: (v) => setDialog(() { if (v == true) { selected.add(c.id); } else { selected.remove(c.id); } }),
          )).toList())),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(dialogContext, selected.toList()), child: const Text('همگام‌سازی'))],
        )),
      );
      if (ids == null || ids.isEmpty) return;
      final merged = await _calendar.syncIntoLocal(_store, calendarIds: ids);
      if (mounted) setState(() => entries = merged);
      await _widget.refresh().catchError((_) {});
      _snack('${fa(merged.length)} برنامه محلی/همگام‌شده در ماه‌نگار موجود است.');
    });
  }

  Future<void> _pinWidget() async {
    await _withBusy(() async {
      await _widget.requestPin();
      _snack('درخواست افزودن ویجت به صفحه اصلی ارسال شد.');
    });
  }

  Future<void> _importBirthday() async {
    await _withBusy(() async {
      final result = await _birthdays.pickAndImport();
      if (result == null) { _snack('دسترسی یا انتخاب مخاطب انجام نشد.'); return; }
      if (result.entries.isEmpty) { _snack('برای ${result.contactName} تولد/سالگردی ثبت نشده است.'); return; }
      final merged = await _store.merge(result.entries);
      if (mounted) setState(() => entries = merged);
      _snack('تولد/سالگرد ${result.contactName} اضافه شد.');
    });
  }

  Future<void> _exportBackup() async {
    await _withBusy(() async {
      final ok = await _backup.exportBackup();
      _snack(ok ? 'فایل پشتیبان ذخیره شد.' : 'ذخیره فایل لغو شد.');
    });
  }

  Future<void> _importBackup() async {
    await _withBusy(() async {
      final imported = await _backup.importBackup();
      if (imported == null) return;
      if (mounted) setState(() => entries = imported);
      await _widget.refresh().catchError((_) {});
      _snack('بازیابی با موفقیت انجام شد.');
    });
  }

  Future<void> _configureMorning() async {
    final prefs = await _notifications.loadPreferences();
    if (!mounted) return;
    final enable = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('خلاصه صبحگاهی'),
      content: Text(prefs.morningSummary ? 'خلاصه صبحگاهی فعال است. غیرفعال شود؟' : 'هر روز ساعت ۸ خلاصه برنامه و مناسبت روز نمایش داده شود؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, !prefs.morningSummary), child: Text(prefs.morningSummary ? 'غیرفعال کن' : 'فعال کن'))],
    ));
    if (enable == null) return;
    final updated = prefs.copyWith(morningSummary: enable, morningHour: 8);
    await _notifications.savePreferences(updated);
    if (enable) {
      final allowed = await _notifications.requestPermission();
      if (!allowed) { _snack('مجوز اعلان فعال نشد.'); return; }
      await _notifications.scheduleMorningSummary(hour: 8, body: _morningText());
      _snack('خلاصه صبحگاهی ساعت ۸ فعال شد.');
    } else {
      await _notifications.cancelMorningSummary();
      _snack('خلاصه صبحگاهی غیرفعال شد.');
    }
  }

  String _morningText() {
    final today = Jalali.now();
    final items = _forDay(today);
    final occasions = _holidays.forDate(today);
    final snap = _astronomy.snapshot(DateTime.now());
    final parts = <String>['${fa(today.day)} ${months[today.month - 1]}'];
    if (occasions.isNotEmpty) parts.add(occasions.first);
    if (items.isNotEmpty) parts.add('${fa(items.length)} برنامه امروز');
    parts.add(snap.isMoonInScorpio ? 'قمر در عقرب' : snap.phaseName);
    return parts.join(' • ');
  }

  Future<void> _withBusy(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try { await task(); } catch (e) { _snack('عملیات انجام نشد: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _empty(String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(children: [const Icon(Icons.inbox_outlined, size: 38), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]),
      );
}
