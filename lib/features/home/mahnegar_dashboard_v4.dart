import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/sky_times_service.dart';
import '../astronomy/lunar_month_page.dart';
import '../astronomy/sky_tools_page.dart';
import '../calendar/presentation/calendar_page.dart';

class MahNegarDashboardV4 extends StatefulWidget {
  const MahNegarDashboardV4({super.key});

  @override
  State<MahNegarDashboardV4> createState() => _MahNegarDashboardV4State();
}

class _MahNegarDashboardV4State extends State<MahNegarDashboardV4> {
  final _astronomy = AstronomyService();
  final _sky = SkyTimesService();

  DateTime _selectedDate = DateTime.now();
  SkyCity _city = SkyCity.presets.first;

  static const _months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

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

  String _time(DateTime? value) => value == null ? '—' : _fa(DateFormat('HH:mm').format(value));

  String _date(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${_fa(j.day)} ${_months[j.month - 1]} ${_fa(j.year)}';
  }

  String _window(LightWindow value) {
    if (!value.available) return '—';
    return '${_time(value.start)}–${_time(value.end)}';
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'انتخاب تاریخ',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
    );
    if (result != null && mounted) setState(() => _selectedDate = result);
  }

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
              ...SkyCity.presets.map(
                (city) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(city.name.characters.first)),
                  title: Text(city.name),
                  trailing: city.name == _city.name ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, city),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _city = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final moon = _astronomy.snapshot(_selectedDate);
    final sky = _sky.calculate(_selectedDate, _city);
    final phases = _astronomy.upcomingMajorPhases(_selectedDate);
    final scorpio = _astronomy.scorpioWindow(_selectedDate);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ماه‌نگار', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(_date(_selectedDate), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      _SoftButton(icon: Icons.location_on_outlined, label: _city.name, onTap: _pickCity),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(onPressed: _pickDate, icon: const Icon(Icons.today_rounded)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _MoonHero(moon: moon, fa: _fa),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.72,
                    children: [
                      _Metric(icon: Icons.wb_sunny_outlined, title: 'طلوع خورشید', value: _time(sky.sunrise)),
                      _Metric(icon: Icons.nights_stay_outlined, title: 'غروب خورشید', value: _time(sky.sunset)),
                      _Metric(icon: Icons.dark_mode_outlined, title: 'طلوع ماه', value: _time(sky.moonrise)),
                      _Metric(icon: Icons.bedtime_outlined, title: 'غروب ماه', value: _time(sky.moonset)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    title: 'نور مناسب عکاسی',
                    subtitle: 'Golden Hour و Blue Hour تقریبی برای ${_city.name}',
                    child: Column(
                      children: [
                        _RowInfo(label: 'Blue Hour صبح', value: _window(sky.morningBlueHour)),
                        _RowInfo(label: 'Golden Hour صبح', value: _window(sky.morningGoldenHour)),
                        _RowInfo(label: 'Golden Hour عصر', value: _window(sky.eveningGoldenHour)),
                        _RowInfo(label: 'Blue Hour شب', value: _window(sky.eveningBlueHour)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    title: 'وضعیت ماه',
                    subtitle: 'اطلاعات نجومی روز انتخاب‌شده',
                    child: Column(
                      children: [
                        _RowInfo(label: 'فاز', value: moon.phaseName),
                        _RowInfo(label: 'روشنایی', value: '${_fa((moon.illumination * 100).round())}٪'),
                        _RowInfo(label: 'سن ماه', value: '${_fa(moon.moonAgeDays.toStringAsFixed(1))} روز'),
                        _RowInfo(label: 'فاصله تا زمین', value: '${_fa(moon.distanceKm.round())} کیلومتر'),
                        _RowInfo(label: 'برج ماه', value: moon.zodiacName),
                        _RowInfo(label: 'قمر در عقرب', value: moon.isMoonInScorpio ? 'فعال' : 'غیرفعال', valueColor: moon.isMoonInScorpio ? scheme.error : scheme.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    title: 'قمر در عقرب',
                    subtitle: moon.isMoonInScorpio ? 'اکنون در بازه عقرب' : 'نزدیک‌ترین بازه بعدی',
                    child: Row(
                      children: [
                        Expanded(child: _Range(label: 'شروع', value: _dateTime(scorpio.start))),
                        const SizedBox(width: 10),
                        Expanded(child: _Range(label: 'پایان', value: _dateTime(scorpio.end))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    title: 'فازهای مهم بعدی',
                    subtitle: 'ماه نو، تربیع‌ها و ماه کامل',
                    child: Column(
                      children: phases.map((event) => _Phase(event: event, fa: _fa)).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.auto_awesome_rounded,
                          title: 'آسمان و نور',
                          subtitle: 'نور عکاسی و زمان‌های خورشید/ماه',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SkyToolsPage(initialCity: _city))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.calendar_view_month_rounded,
                          title: 'فاز ماهانه',
                          subtitle: 'فاز ماه برای همه روزهای ماه',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LunarMonthPage(initialDate: _selectedDate))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FeatureCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'تقویم کامل ماه‌نگار',
                    subtitle: 'شمسی، قمری، میلادی، مناسبت‌ها و کارهای شخصی',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarPage())),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Golden/Blue Hour در این نسخه به‌صورت تقریبی محاسبه می‌شود. سایر محاسبات نجومی برای اطلاع‌رسانی و برنامه‌ریزی عمومی هستند.', style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: .97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.brightness_2_outlined), selectedIcon: Icon(Icons.brightness_2), label: 'امروز'),
                NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'تقویم'),
                NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'آسمان'),
              ],
              onDestinationSelected: (index) {
                if (index == 1) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
                if (index == 2) Navigator.of(context).push(MaterialPageRoute(builder: (_) => SkyToolsPage(initialCity: _city)));
              },
            ),
          ),
        ),
      ),
    );
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '—';
    return '${_date(value)} • ${_time(value)}';
  }
}

class _MoonHero extends StatelessWidget {
  const _MoonHero({required this.moon, required this.fa});
  final AstronomySnapshot moon;
  final String Function(Object) fa;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [scheme.primaryContainer.withValues(alpha: .75), scheme.surfaceContainerHighest]),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          CustomPaint(
            size: const Size.square(150),
            painter: _MoonPainter(phaseAngle: moon.phaseAngle, light: scheme.onSurface, dark: scheme.surface),
          ),
          const SizedBox(height: 14),
          Text(moon.phaseName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${fa((moon.illumination * 100).round())}٪ روشنایی • ${moon.zodiacName}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.phaseAngle, required this.light, required this.dark});
  final double phaseAngle;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = dark.withValues(alpha: .9));
    canvas.save();
    canvas.clipOval(rect);
    canvas.drawCircle(center, radius, Paint()..color = light.withValues(alpha: .96));
    final angle = phaseAngle % 360;
    final waxing = angle <= 180;
    final illumination = (1 - math.cos(angle * math.pi / 180)) / 2;
    final width = radius * 2 * (1 - illumination).abs();
    final shadow = Paint()..color = dark.withValues(alpha: .97);
    if (illumination < .5) {
      canvas.drawRect(Rect.fromLTWH(waxing ? 0 : radius, 0, radius, size.height), shadow);
      canvas.drawOval(Rect.fromCenter(center: center, width: math.max(2, width), height: radius * 2), shadow);
    } else {
      canvas.drawRect(Rect.fromLTWH(waxing ? 0 : radius, 0, radius, size.height), shadow);
      canvas.drawOval(Rect.fromCenter(center: center, width: math.max(2, width), height: radius * 2), Paint()..color = light.withValues(alpha: .96));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) => oldDelegate.phaseAngle != phaseAngle || oldDelegate.light != light || oldDelegate.dark != dark;
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 5), Text(label)]),
          ),
        ),
      );
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
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)), const SizedBox(height: 2), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))])),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 14), child]),
        ),
      );
}

class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: valueColor))]),
      );
}

class _Range extends StatelessWidget {
  const _Range({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 5), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800))]),
      );
}

class _Phase extends StatelessWidget {
  const _Phase({required this.event, required this.fa});
  final LunarEvent event;
  final String Function(Object) fa;

  @override
  Widget build(BuildContext context) {
    final j = Jalali.fromDateTime(event.time);
    final date = '${fa(j.year)}/${fa(j.month)}/${fa(j.day)} • ${fa(DateFormat('HH:mm').format(event.time))}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.brightness_2_rounded, size: 18)), const SizedBox(width: 10), Expanded(child: Text(event.name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)]))]),
          ),
        ),
      );
}
