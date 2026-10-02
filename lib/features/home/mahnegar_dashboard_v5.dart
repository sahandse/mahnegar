import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/sky_times_service.dart';
import '../astronomy/lunar_month_page.dart';
import '../astronomy/sky_tools_page.dart';
import '../calendar/presentation/calendar_page.dart';

class MahNegarDashboardV5 extends StatefulWidget {
  const MahNegarDashboardV5({super.key});

  @override
  State<MahNegarDashboardV5> createState() => _MahNegarDashboardV5State();
}

class _MahNegarDashboardV5State extends State<MahNegarDashboardV5> {
  final _astronomy = AstronomyService();
  final _sky = SkyTimesService();
  DateTime _date = DateTime.now();
  SkyCity _city = SkyCity.presets.first;

  static const _months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  String _fa(Object value) => value.toString()
      .replaceAll('0', '۰').replaceAll('1', '۱').replaceAll('2', '۲')
      .replaceAll('3', '۳').replaceAll('4', '۴').replaceAll('5', '۵')
      .replaceAll('6', '۶').replaceAll('7', '۷').replaceAll('8', '۸')
      .replaceAll('9', '۹');

  String _time(DateTime? value) => value == null ? '—' : _fa(DateFormat('HH:mm').format(value));

  String _jalali(DateTime value) {
    final j = Jalali.fromDateTime(value);
    return '${_fa(j.day)} ${_months[j.month - 1]} ${_fa(j.year)}';
  }

  String _window(LightWindow window) => window.available ? '${_time(window.start)} تا ${_time(window.end)}' : '—';

  Future<void> _pickCity() async {
    final result = await showModalBottomSheet<SkyCity>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text('انتخاب شهر', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...SkyCity.presets.map((city) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(city.name.characters.first)),
                title: Text(city.name),
                trailing: city.name == _city.name ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, city),
              )),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _city = result);
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'انتخاب تاریخ',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
    );
    if (result != null && mounted) setState(() => _date = result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moon = _astronomy.snapshot(_date);
    final sky = _sky.calculate(_date, _city);
    final phases = _astronomy.upcomingMajorPhases(_date);
    final scorpio = _astronomy.scorpioWindow(_date);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ماه‌نگار', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(_jalali(_date), style: TextStyle(color: scheme.onSurfaceVariant)),
              ])),
              TextButton.icon(onPressed: _pickCity, icon: const Icon(Icons.location_on_outlined), label: Text(_city.name)),
              IconButton.filledTonal(onPressed: _pickDate, icon: const Icon(Icons.today_rounded)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [scheme.primaryContainer, scheme.surfaceContainerHighest]),
              ),
              child: Column(children: [
                Container(
                  width: 138,
                  height: 138,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface, boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .12), blurRadius: 28, spreadRadius: 4)]),
                  child: Icon(_moonIcon(moon.phaseName), size: 82, color: scheme.onSurface),
                ),
                const SizedBox(height: 14),
                Text(moon.phaseName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${_fa((moon.illumination * 100).round())}٪ روشنایی • ${moon.zodiacName}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _Metric(icon: Icons.wb_sunny_outlined, title: 'طلوع خورشید', value: _time(sky.sunrise)),
                _Metric(icon: Icons.nights_stay_outlined, title: 'غروب خورشید', value: _time(sky.sunset)),
                _Metric(icon: Icons.dark_mode_outlined, title: 'طلوع ماه', value: _time(sky.moonrise)),
                _Metric(icon: Icons.bedtime_outlined, title: 'غروب ماه', value: _time(sky.moonset)),
              ],
            ),
            const SizedBox(height: 12),
            _Section(title: 'نور مناسب عکاسی', subtitle: 'Golden Hour و Blue Hour تقریبی برای ${_city.name}', children: [
              _Info(label: 'Blue Hour صبح', value: _window(sky.morningBlueHour)),
              _Info(label: 'Golden Hour صبح', value: _window(sky.morningGoldenHour)),
              _Info(label: 'Golden Hour عصر', value: _window(sky.eveningGoldenHour)),
              _Info(label: 'Blue Hour شب', value: _window(sky.eveningBlueHour)),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'جزئیات ماه', subtitle: 'محاسبات روز انتخاب‌شده', children: [
              _Info(label: 'سن ماه', value: '${_fa(moon.moonAgeDays.toStringAsFixed(1))} روز'),
              _Info(label: 'فاصله تا زمین', value: '${_fa(moon.distanceKm.round())} کیلومتر'),
              _Info(label: 'برج ماه', value: moon.zodiacName),
              _Info(label: 'قمر در عقرب', value: moon.isMoonInScorpio ? 'فعال' : 'غیرفعال', valueColor: moon.isMoonInScorpio ? scheme.error : scheme.primary),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'قمر در عقرب', subtitle: moon.isMoonInScorpio ? 'اکنون در بازه عقرب' : 'نزدیک‌ترین بازه بعدی', children: [
              _Info(label: 'شروع', value: _dateTime(scorpio.start)),
              _Info(label: 'پایان', value: _dateTime(scorpio.end)),
            ]),
            const SizedBox(height: 12),
            _Section(title: 'فازهای مهم بعدی', subtitle: 'چهار رویداد اصلی ماه', children: phases.map((event) {
              final j = Jalali.fromDateTime(event.time);
              return _Info(label: event.name, value: '${_fa(j.month)}/${_fa(j.day)} • ${_time(event.time)}');
            }).toList()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Action(icon: Icons.auto_awesome_rounded, title: 'آسمان و نور', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SkyToolsPage(initialCity: _city))))),
              const SizedBox(width: 10),
              Expanded(child: _Action(icon: Icons.calendar_view_month_rounded, title: 'فاز ماهانه', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LunarMonthPage(initialDate: _date))))),
            ]),
            const SizedBox(height: 10),
            _Action(icon: Icons.calendar_month_rounded, title: 'تقویم کامل ماه‌نگار', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
              child: Text('زمان‌های Golden/Blue Hour در این نسخه تقریبی هستند؛ سایر محاسبات نجومی برای اطلاع‌رسانی و برنامه‌ریزی عمومی ارائه می‌شوند.', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.brightness_2_outlined), selectedIcon: Icon(Icons.brightness_2), label: 'امروز'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'تقویم'),
              NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'آسمان'),
            ],
            onDestinationSelected: (index) {
              if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()));
              if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => SkyToolsPage(initialCity: _city)));
            },
          ),
        ),
      ),
    );
  }

  String _dateTime(DateTime? value) => value == null ? '—' : '${_jalali(value)} • ${_time(value)}';

  IconData _moonIcon(String phase) {
    if (phase == 'ماه نو') return Icons.circle;
    if (phase == 'ماه کامل') return Icons.circle_outlined;
    if (phase.contains('تربیع')) return Icons.contrast_rounded;
    return Icons.brightness_2_rounded;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 20)),
        const SizedBox(width: 9),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ])),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        ...children,
      ]),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: valueColor))]),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .58),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))])),
    ),
  );
}
