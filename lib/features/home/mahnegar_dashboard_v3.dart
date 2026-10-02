import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/sky_times_service.dart';
import '../calendar/presentation/calendar_page.dart';

class MahNegarDashboardV3 extends StatefulWidget {
  const MahNegarDashboardV3({super.key});

  @override
  State<MahNegarDashboardV3> createState() => _MahNegarDashboardV3State();
}

class _MahNegarDashboardV3State extends State<MahNegarDashboardV3> {
  final _astronomy = AstronomyService();
  final _skyTimes = SkyTimesService();

  DateTime _selectedDate = DateTime.now();
  SkyCity _city = SkyCity.presets.first;

  static const _monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
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

  String _jalali(DateTime date) {
    final j = Jalali.fromDateTime(date);
    return '${_fa(j.day)} ${_monthNames[j.month - 1]} ${_fa(j.year)}';
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'انتخاب تاریخ',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
    );
    if (value != null && mounted) setState(() => _selectedDate = value);
  }

  Future<void> _pickCity() async {
    final value = await showModalBottomSheet<SkyCity>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('انتخاب شهر', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...SkyCity.presets.map(
                (city) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(city.name.characters.first)),
                  title: Text(city.name),
                  subtitle: Text('${city.latitude.toStringAsFixed(2)}°, ${city.longitude.toStringAsFixed(2)}°'),
                  trailing: city.name == _city.name ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, city),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _city = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = _astronomy.snapshot(_selectedDate);
    final sky = _skyTimes.calculate(_selectedDate, _city);
    final phases = _astronomy.upcomingMajorPhases(_selectedDate);
    final scorpio = _astronomy.scorpioWindow(_selectedDate);
    final percent = (snapshot.illumination * 100).round();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
              sliver: SliverList.list(
                children: [
                  _Header(
                    dateLabel: _jalali(_selectedDate),
                    city: _city.name,
                    onDateTap: _pickDate,
                    onCityTap: _pickCity,
                  ),
                  const SizedBox(height: 18),
                  _MoonHero(
                    snapshot: snapshot,
                    percentage: percent,
                    accent: scheme.primary,
                  ),
                  const SizedBox(height: 14),
                  _GlassGrid(
                    children: [
                      _Metric(icon: Icons.wb_sunny_outlined, title: 'طلوع خورشید', value: _time(sky.sunrise)),
                      _Metric(icon: Icons.nights_stay_outlined, title: 'غروب خورشید', value: _time(sky.sunset)),
                      _Metric(icon: Icons.dark_mode_outlined, title: 'طلوع ماه', value: _time(sky.moonrise)),
                      _Metric(icon: Icons.bedtime_outlined, title: 'غروب ماه', value: _time(sky.moonset)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'وضعیت نجومی',
                    subtitle: 'اطلاعات محاسبه‌شده برای ${_city.name}',
                    child: Column(
                      children: [
                        _InfoRow(label: 'سن ماه', value: '${_fa(snapshot.moonAgeDays.toStringAsFixed(1))} روز'),
                        _InfoRow(label: 'فاصله ماه تا زمین', value: '${_fa(snapshot.distanceKm.round())} کیلومتر'),
                        _InfoRow(label: 'برج ماه', value: snapshot.zodiacName),
                        _InfoRow(
                          label: 'قمر در عقرب',
                          value: snapshot.isMoonInScorpio ? 'فعال' : 'غیرفعال',
                          valueColor: snapshot.isMoonInScorpio ? scheme.error : scheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'قمر در عقرب',
                    subtitle: snapshot.isMoonInScorpio ? 'اکنون در بازه عقرب قرار دارد' : 'نزدیک‌ترین بازه بعدی',
                    child: Row(
                      children: [
                        Expanded(child: _RangeTile(label: 'شروع', value: _dateTime(scorpio.start))),
                        const SizedBox(width: 10),
                        Expanded(child: _RangeTile(label: 'پایان', value: _dateTime(scorpio.end))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'فازهای بعدی ماه',
                    subtitle: 'چهار رویداد اصلی پیشِ رو',
                    child: Column(
                      children: phases
                          .map(
                            (event) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PhaseRow(event: event, fa: _fa),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActionCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'تقویم کامل ماه‌نگار',
                    subtitle: 'شمسی، قمری، میلادی، مناسبت‌ها و کارهای شخصی',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarPage())),
                  ),
                  const SizedBox(height: 10),
                  _NoticeCard(),
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
              color: scheme.surfaceContainerHigh.withValues(alpha: .96),
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
                if (index == 1) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
                } else if (index == 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نمای آسمان و قطب‌نما در مرحله بعد اضافه می‌شود.')));
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  String _dateTime(DateTime? value) {
    if (value == null) return 'در دسترس نیست';
    return '${_jalali(value)} • ${_time(value)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dateLabel, required this.city, required this.onDateTap, required this.onCityTap});

  final String dateLabel;
  final String city;
  final VoidCallback onDateTap;
  final VoidCallback onCityTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ماه‌نگار', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('تقویم و رصد روزانه، بدون شلوغی', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        _ChipButton(icon: Icons.location_on_outlined, label: city, onTap: onCityTap),
        const SizedBox(width: 8),
        IconButton.filledTonal(onPressed: onDateTap, icon: const Icon(Icons.today_rounded), tooltip: dateLabel),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.icon, required this.label, required this.onTap});
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)]),
          ),
        ),
      );
}

class _MoonHero extends StatelessWidget {
  const _MoonHero({required this.snapshot, required this.percentage, required this.accent});
  final AstronomySnapshot snapshot;
  final int percentage;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.primaryContainer.withValues(alpha: .72), scheme.surfaceContainerHighest],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Center(
              child: CustomPaint(
                size: const Size.square(172),
                painter: _MoonPainter(phaseAngle: snapshot.phaseAngle, lightColor: scheme.onSurface, darkColor: scheme.surface),
              ),
            ),
          ),
          Text(snapshot.phaseName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('$percentage٪ روشنایی', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: accent, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('زاویه فاز ${snapshot.phaseAngle.toStringAsFixed(1)}° • ${snapshot.zodiacName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.phaseAngle, required this.lightColor, required this.darkColor});
  final double phaseAngle;
  final Color lightColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final circle = Rect.fromCircle(center: center, radius: radius);
    final bg = Paint()..color = darkColor.withValues(alpha: .88);
    canvas.drawCircle(center, radius, bg);

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    final lit = Paint()..color = lightColor.withValues(alpha: .94);
    canvas.drawCircle(center, radius, lit);

    final angle = phaseAngle % 360;
    final waxing = angle <= 180;
    final illumination = (1 - math.cos(angle * math.pi / 180)) / 2;
    final terminatorWidth = radius * 2 * (1 - illumination).abs();
    final shadow = Paint()..color = darkColor.withValues(alpha: .96);

    if (illumination < .5) {
      canvas.drawRect(Rect.fromLTWH(waxing ? 0 : radius, 0, radius, size.height), shadow);
      final oval = Rect.fromCenter(center: center, width: math.max(2, terminatorWidth), height: radius * 2);
      canvas.drawOval(oval, shadow);
    } else {
      canvas.drawRect(Rect.fromLTWH(waxing ? 0 : radius, 0, radius, size.height), shadow);
      final oval = Rect.fromCenter(center: center, width: math.max(2, terminatorWidth), height: radius * 2);
      canvas.drawOval(oval, lit);
    }
    canvas.restore();

    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = lightColor.withValues(alpha: .18));
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) => oldDelegate.phaseAngle != phaseAngle || oldDelegate.lightColor != lightColor || oldDelegate.darkColor != darkColor;
}

class _GlassGrid extends StatelessWidget {
  const _GlassGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: children,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)), const SizedBox(height: 2), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))])),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor))]),
      );
}

class _RangeTile extends StatelessWidget {
  const _RangeTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 5), Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))]),
      );
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.event, required this.fa});
  final LunarEvent event;
  final String Function(Object) fa;

  @override
  Widget build(BuildContext context) {
    final j = Jalali.fromDateTime(event.time);
    final when = '${fa(j.year)}/${fa(j.month)}/${fa(j.day)} • ${fa(DateFormat('HH:mm').format(event.time))}';
    return Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer), child: const Icon(Icons.brightness_2_rounded, size: 19)), const SizedBox(width: 11), Expanded(child: Text(event.name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(when, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.arrow_back_ios_new_rounded, size: 16)]),
          ),
        ),
      );
}

class _NoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 20), const SizedBox(width: 10), Expanded(child: Text('محاسبات نجومی ماه‌نگار برای اطلاع‌رسانی و برنامه‌ریزی عمومی هستند. رویدادهای سنتی/مذهبی به‌صورت توضیحی نمایش داده می‌شوند و جایگزین منابع تخصصی نیستند.', style: Theme.of(context).textTheme.bodySmall))]),
      );
}
