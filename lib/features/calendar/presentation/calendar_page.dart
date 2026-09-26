import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/services/astronomy_service.dart';
import '../../../core/services/device_calendar_service.dart';
import '../../../core/services/iran_holidays.dart';
import '../../../core/services/local_store.dart';
import '../../../main.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _store = LocalStore();
  final _astronomy = AstronomyService();
  final _holidays = IranHolidays();
  final _sync = DeviceCalendarSyncService();

  late Jalali visibleMonth;
  late Jalali selectedDay;
  List<CalendarEntry> entries = [];
  int navIndex = 0;
  bool busy = false;

  static const weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
  static const monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    visibleMonth = Jalali(now.year, now.month, 1);
    selectedDay = now;
    _load();
  }

  Future<void> _load() async {
    final data = await _store.load();
    if (mounted) setState(() => entries = data);
  }

  String faNum(Object value) => value
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

  int get daysInMonth {
    final next = visibleMonth.month == 12
        ? Jalali(visibleMonth.year + 1, 1, 1)
        : Jalali(visibleMonth.year, visibleMonth.month + 1, 1);
    return next.toDateTime().difference(visibleMonth.toDateTime()).inDays;
  }

  int get firstWeekdayIndex => (visibleMonth.toDateTime().weekday + 1) % 7;

  void changeMonth(int delta) {
    setState(() {
      var year = visibleMonth.year;
      var month = visibleMonth.month + delta;
      if (month < 1) {
        year--;
        month = 12;
      } else if (month > 12) {
        year++;
        month = 1;
      }
      visibleMonth = Jalali(year, month, 1);
    });
  }

  List<CalendarEntry> _entriesFor(Jalali day) {
    return entries.where((entry) {
      final j = Jalali.fromDateTime(entry.start);
      return j.year == day.year && j.month == day.month && j.day == day.day;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _saveEntry(CalendarEntry entry) async {
    setState(() => entries = [...entries, entry]);
    await _store.save(entries);
  }

  Future<void> _toggleTodo(CalendarEntry entry) async {
    entries = entries
        .map((e) => e.id == entry.id ? e.copyWith(completed: !e.completed) : e)
        .toList();
    await _store.save(entries);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          _brandMark(),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ماه‌نگار', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('تقویم، برنامه و آسمان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'امروز',
            onPressed: () {
              final today = Jalali.now();
              setState(() {
                selectedDay = today;
                visibleMonth = Jalali(today.year, today.month, 1);
                navIndex = 0;
              });
            },
            icon: const Icon(Icons.today_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _body())),
      floatingActionButton: navIndex == 0 || navIndex == 1 || navIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSheet(todo: navIndex == 1),
              icon: const Icon(Icons.add_rounded),
              label: Text(navIndex == 1 ? 'کار جدید' : 'افزودن'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (value) => setState(() => navIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'تقویم'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'کارها'),
          NavigationDestination(icon: Icon(Icons.dark_mode_outlined), selectedIcon: Icon(Icons.dark_mode), label: 'آسمان'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'رویدادها'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'تنظیمات'),
        ],
      ),
    );
  }

  Widget _brandMark() {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [c.primary, c.tertiary]),
      ),
      child: const Stack(alignment: Alignment.center, children: [
        Icon(Icons.nightlight_round, color: Colors.white, size: 26),
        Positioned(right: 7, bottom: 7, child: Icon(Icons.calendar_month, color: Colors.white, size: 13)),
      ]),
    );
  }

  Widget _body() {
    return switch (navIndex) {
      0 => _calendarView(),
      1 => _todosView(),
      2 => _skyView(),
      3 => _eventsView(),
      _ => _settingsView(),
    };
  }

  Widget _calendarView() {
    final today = Jalali.now();
    return ListView(
      key: const ValueKey('calendar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _calendarCard(today),
        const SizedBox(height: 16),
        _selectedDayCard(),
        const SizedBox(height: 16),
        _agendaCard(),
      ],
    );
  }

  Widget _calendarCard(Jalali today) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_right_rounded)),
            Expanded(
              child: Column(children: [
                Text('${monthNames[visibleMonth.month - 1]} ${faNum(visibleMonth.year)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('تقویم شمسی ایران', style: Theme.of(context).textTheme.labelMedium),
              ]),
            ),
            IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_left_rounded)),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: .82,
            children: [
              for (final d in weekDays)
                Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.w800, color: d == 'ج' ? Colors.redAccent : null))),
              for (var i = 0; i < firstWeekdayIndex; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++) _dayCell(day, today),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _dayCell(int day, Jalali today) {
    final current = Jalali(visibleMonth.year, visibleMonth.month, day);
    final isToday = current.year == today.year && current.month == today.month && current.day == today.day;
    final isSelected = current.year == selectedDay.year && current.month == selectedDay.month && current.day == selectedDay.day;
    final holiday = _holidays.isHoliday(current);
    final hasEntry = _entriesFor(current).isNotEmpty;
    final inScorpio = _astronomy.snapshot(current.toDateTime().add(const Duration(hours: 12))).isMoonInScorpio;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => selectedDay = current),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : (isToday ? colors.primaryContainer : null),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(faNum(day), style: TextStyle(
            fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? colors.onPrimary : (holiday ? Colors.redAccent : null),
          )),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (hasEntry) _dot(isSelected ? colors.onPrimary : colors.primary),
            if (inScorpio) ...[
              const SizedBox(width: 3),
              Icon(Icons.nightlight_round, size: 8, color: isSelected ? colors.onPrimary : colors.tertiary),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _dot(Color color) => Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _selectedDayCard() {
    final g = selectedDay.toGregorian();
    final holidays = _holidays.forDate(selectedDay);
    final snap = _astronomy.snapshot(selectedDay.toDateTime().add(const Duration(hours: 12)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${faNum(selectedDay.day)} ${monthNames[selectedDay.month - 1]} ${faNum(selectedDay.year)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('میلادی ${faNum(g.year)}/${faNum(g.month)}/${faNum(g.day)}'),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(snap.phaseName, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          if (holidays.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final holiday in holidays)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 18), const SizedBox(width: 8), Text(holiday)]),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _agendaCard() {
    final dayEntries = _entriesFor(selectedDay);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('برنامه این روز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            Text('${faNum(dayEntries.length)} مورد', style: Theme.of(context).textTheme.labelMedium),
          ]),
          const SizedBox(height: 12),
          if (dayEntries.isEmpty)
            _empty('هنوز برنامه‌ای ثبت نشده', 'با دکمه افزودن، جلسه، رویداد یا کار جدید بساز.')
          else
            ...dayEntries.map(_entryTile),
        ]),
      ),
    );
  }

  Widget _entryTile(CalendarEntry entry) {
    final time = DateFormat('HH:mm').format(entry.start);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(entry.isTodo ? Icons.check_circle_outline : Icons.event_rounded),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: entry.completed ? TextDecoration.lineThrough : null)),
          Text(entry.isTodo ? 'کار روزانه' : '${faNum(time)}${entry.location.isEmpty ? '' : ' • ${entry.location}'}', style: Theme.of(context).textTheme.bodySmall),
        ])),
        if (entry.isTodo)
          Checkbox(value: entry.completed, onChanged: (_) => _toggleTodo(entry))
        else if (entry.syncedCalendarId != null)
          const Icon(Icons.cloud_done_rounded, size: 18),
      ]),
    );
  }

  Widget _todosView() {
    final todos = entries.where((e) => e.isTodo).toList()..sort((a, b) => a.start.compareTo(b.start));
    return ListView(
      key: const ValueKey('todos'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _sectionHeader('کارهای من', 'برنامه روزانه ساده و خلوت', Icons.task_alt_rounded),
        const SizedBox(height: 14),
        if (todos.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: _empty('کاری ثبت نشده', 'اولین کار روزانه‌ات را اضافه کن.')))
        else ...todos.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _entryTile(e))))),
      ],
    );
  }

  Widget _eventsView() {
    final events = entries.where((e) => !e.isTodo).toList()..sort((a, b) => a.start.compareTo(b.start));
    return ListView(
      key: const ValueKey('events'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _sectionHeader('جلسه‌ها و رویدادها', 'رویدادهای محلی و همگام‌شده', Icons.event_available_rounded),
        const SizedBox(height: 14),
        if (events.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18), child: _empty('رویدادی ندارید', 'جلسه جدید بساز و در صورت تمایل به Google Calendar بفرست.')))
        else ...events.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _entryTile(e))))),
      ],
    );
  }

  Widget _skyView() {
    final now = DateTime.now();
    final snap = _astronomy.snapshot(now);
    final transition = _astronomy.nextScorpioTransition(now, entering: !snap.isMoonInScorpio);
    return ListView(
      key: const ValueKey('sky'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _sectionHeader('آسمان امروز', 'محاسبات نجومی بر پایه موقعیت واقعی ماه و خورشید', Icons.auto_awesome_rounded),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF111A3F), Color(0xFF35266A)]),
          ),
          child: Column(children: [
            const Icon(Icons.nightlight_round, color: Color(0xFFFFDB8A), size: 86),
            const SizedBox(height: 14),
            Text(snap.phaseName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('روشنایی تقریبی ${faNum((snap.illumination * 100).round())}٪', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _metricCard('برج ماه', snap.zodiacName, Icons.motion_photos_on_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('طول ماه', '${faNum(snap.moonLongitude.toStringAsFixed(1))}°', Icons.explore_outlined)),
        ]),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('♏', style: TextStyle(fontSize: 26)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('قمر در عقرب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text(snap.isMoonInScorpio ? 'اکنون فعال است' : 'اکنون فعال نیست'),
                if (transition != null)
                  Text('${snap.isMoonInScorpio ? 'پایان تقریبی' : 'شروع تقریبی'}: ${faNum(DateFormat('MM/dd  HH:mm').format(transition))}', style: Theme.of(context).textTheme.bodySmall),
              ])),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text('بخش استرولوژی جنبه فرهنگی/سرگرمی دارد؛ داده‌های این صفحه برای موقعیت ماه و فاز آن از محاسبات نجومی جداگانه تولید می‌شوند.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _settingsView() {
    return ListView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _sectionHeader('تنظیمات', 'ظاهر، تقویم و همگام‌سازی', Icons.tune_rounded),
        const SizedBox(height: 14),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('حالت روشن'),
              onTap: () => themeModeNotifier.value = ThemeMode.light,
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('حالت تاریک'),
              onTap: () => themeModeNotifier.value = ThemeMode.dark,
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('هماهنگ با سیستم'),
              onTap: () => themeModeNotifier.value = ThemeMode.system,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('اتصال به تقویم گوگل'),
            subtitle: const Text('تقویم‌های Google موجود روی دستگاه را شناسایی می‌کند.'),
            trailing: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_left_rounded),
            onTap: busy ? null : _checkGoogleCalendars,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Text('فونت رابط برای IRANSans تنظیم شده است. برای انتشار عمومی، فایل فونت باید با مجوز معتبر توسط مالک پروژه به assets اضافه شود.'),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle, IconData icon) => Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]);

  Widget _metricCard(String title, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _empty(String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 34),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Future<void> _showAddSheet({required bool todo}) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    var start = selectedDay.toDateTime().add(const Duration(hours: 9));
    var end = start.add(const Duration(hours: 1));
    bool syncGoogle = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(todo ? 'کار جدید' : 'جلسه یا رویداد جدید', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان')),
              const SizedBox(height: 10),
              if (!todo) ...[
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'محل جلسه')),
                const SizedBox(height: 10),
              ],
              TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text('${faNum(DateFormat('yyyy/MM/dd').format(start))} • ${faNum(DateFormat('HH:mm').format(start))}'),
                subtitle: Text(todo ? 'زمان کار' : 'زمان شروع'),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
                  if (time != null) {
                    setSheetState(() {
                      start = DateTime(start.year, start.month, start.day, time.hour, time.minute);
                      end = start.add(const Duration(hours: 1));
                    });
                  }
                },
              ),
              if (!todo)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: syncGoogle,
                  onChanged: (v) => setSheetState(() => syncGoogle = v),
                  title: const Text('افزودن به Google Calendar'),
                  subtitle: const Text('در صورت وجود حساب گوگل روی دستگاه'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    var entry = CalendarEntry(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      start: start,
                      end: todo ? start.add(const Duration(minutes: 30)) : end,
                      description: descriptionController.text.trim(),
                      location: locationController.text.trim(),
                      isTodo: todo,
                    );
                    if (syncGoogle && !todo) {
                      try {
                        final calendars = await _sync.googleCalendars();
                        final calendarId = calendars.isNotEmpty ? calendars.first.id : null;
                        final eventId = await _sync.addMeeting(entry, calendarId: calendarId);
                        entry = entry.copyWith(syncedCalendarId: eventId);
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('اتصال به تقویم گوگل انجام نشد؛ رویداد فقط در ماه‌نگار ذخیره شد.')));
                        }
                      }
                    }
                    await _saveEntry(entry);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ذخیره'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _checkGoogleCalendars() async {
    setState(() => busy = true);
    try {
      final calendars = await _sync.googleCalendars();
      if (!mounted) return;
      final message = calendars.isEmpty
          ? 'تقویم Google قابل نوشتن پیدا نشد. حساب گوگل را در تنظیمات Android اضافه و Sync Calendar را فعال کنید.'
          : '${faNum(calendars.length)} تقویم Google پیدا شد: ${calendars.map((e) => e.name).join('، ')}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای همگام‌سازی، اجازه دسترسی به تقویم را فعال کنید.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
