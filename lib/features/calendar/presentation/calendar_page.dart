import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late Jalali visibleMonth;
  late Jalali selectedDay;

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
  }

  int get daysInMonth {
    final next = visibleMonth.month == 12
        ? Jalali(visibleMonth.year + 1, 1, 1)
        : Jalali(visibleMonth.year, visibleMonth.month + 1, 1);
    return next.toDateTime().difference(visibleMonth.toDateTime()).inDays;
  }

  int get firstWeekdayIndex {
    final weekday = visibleMonth.toDateTime().weekday; // Monday = 1
    return (weekday + 1) % 7; // Saturday = 0
  }

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

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماه‌نگار', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              visibleMonth = Jalali(today.year, today.month, 1);
              selectedDay = today;
            }),
            child: const Text('امروز'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _calendarCard(context, today),
            const SizedBox(height: 16),
            _todayCard(context),
            const SizedBox(height: 12),
            _skyCard(context),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'تقویم'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'کارها'),
          NavigationDestination(icon: Icon(Icons.nightlight_outlined), label: 'آسمان'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'رویدادها'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }

  Widget _calendarCard(BuildContext context, Jalali today) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_right)),
                Expanded(
                  child: Text(
                    '${monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_left)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final d in weekDays)
                  Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.w700, color: d == 'ج' ? Colors.redAccent : null))),
                for (var i = 0; i < firstWeekdayIndex; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++) _dayCell(context, day, today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, int day, Jalali today) {
    final current = Jalali(visibleMonth.year, visibleMonth.month, day);
    final isToday = current.year == today.year && current.month == today.month && current.day == today.day;
    final isSelected = current.year == selectedDay.year && current.month == selectedDay.month && current.day == selectedDay.day;
    final isFriday = current.toDateTime().weekday == DateTime.friday;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => selectedDay = current),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : (isToday ? Theme.of(context).colorScheme.primaryContainer : null),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : isFriday
                    ? Colors.redAccent
                    : null,
          ),
        ),
      ),
    );
  }

  Widget _todayCard(BuildContext context) {
    final gregorian = selectedDay.toGregorian();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('روز انتخاب‌شده', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '${selectedDay.day} ${monthNames[selectedDay.month - 1]} ${selectedDay.year}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('میلادی: ${gregorian.year}/${gregorian.month}/${gregorian.day}'),
          const SizedBox(height: 12),
          const Row(children: [Icon(Icons.event_available_outlined, size: 20), SizedBox(width: 8), Text('رویداد و یادآورهای این روز')]),
        ]),
      ),
    );
  }

  Widget _skyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.nightlight_round),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('آسمان', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Text('فاز ماه و وضعیت قمر در عقرب'),
            ])),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text('موتور محاسبات نجومی در مرحله بعد به این کارت متصل می‌شود.'),
        ]),
      ),
    );
  }
}
