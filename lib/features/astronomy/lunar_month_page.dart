import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';

class LunarMonthPage extends StatefulWidget {
  const LunarMonthPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<LunarMonthPage> createState() => _LunarMonthPageState();
}

class _LunarMonthPageState extends State<LunarMonthPage> {
  final _astronomy = AstronomyService();
  late Jalali _month;

  static const _monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  @override
  void initState() {
    super.initState();
    final j = Jalali.fromDateTime(widget.initialDate ?? DateTime.now());
    _month = Jalali(j.year, j.month, 1);
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

  int get _daysInMonth {
    final next = _month.month == 12 ? Jalali(_month.year + 1, 1, 1) : Jalali(_month.year, _month.month + 1, 1);
    return next.toDateTime().difference(_month.toDateTime()).inDays;
  }

  void _moveMonth(int delta) {
    var year = _month.year;
    var month = _month.month + delta;
    if (month < 1) {
      year--;
      month = 12;
    } else if (month > 12) {
      year++;
      month = 1;
    }
    setState(() => _month = Jalali(year, month, 1));
  }

  String _phaseIcon(String phase) {
    if (phase == 'ماه نو') return '●';
    if (phase == 'ماه کامل') return '○';
    if (phase == 'تربیع اول') return '◐';
    if (phase == 'تربیع آخر') return '◑';
    if (phase.contains('افزاینده')) return '◒';
    return '◓';
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(_daysInMonth, (index) {
      final jalali = Jalali(_month.year, _month.month, index + 1);
      final date = jalali.toDateTime().add(const Duration(hours: 12));
      return (jalali: jalali, date: date, snapshot: _astronomy.snapshot(date));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('تقویم فاز ماه')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
              Expanded(
                child: Column(
                  children: [
                    Text('${_monthNames[_month.month - 1]} ${_fa(_month.year)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('وضعیت ماه در نیمروز هر تاریخ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          ...days.map((item) {
            final snap = item.snapshot;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(_phaseIcon(snap.phaseName), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  title: Text('${_fa(item.jalali.day)} ${_monthNames[item.jalali.month - 1]}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${snap.phaseName} • سن ${_fa(snap.moonAgeDays.toStringAsFixed(1))} روز • ${_fa((snap.illumination * 100).round())}٪ روشنایی'),
                  trailing: Text(snap.zodiacName, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
