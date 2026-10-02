import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/astronomy_service.dart';
import '../../core/services/sky_times_service.dart';
import 'lunar_month_page.dart';

class SkyToolsPage extends StatefulWidget {
  const SkyToolsPage({super.key, this.initialCity});

  final SkyCity? initialCity;

  @override
  State<SkyToolsPage> createState() => _SkyToolsPageState();
}

class _SkyToolsPageState extends State<SkyToolsPage> {
  final _sky = SkyTimesService();
  final _astronomy = AstronomyService();
  late SkyCity _city;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity ?? SkyCity.presets.first;
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

  String _time(DateTime? value) => value == null ? '—' : _fa(DateFormat('HH:mm').format(value));

  String _window(LightWindow value) {
    if (!value.available) return '—';
    return '${_time(value.start)} تا ${_time(value.end)}';
  }

  Future<void> _pickCity() async {
    final selected = await showModalBottomSheet<SkyCity>(
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
              const SizedBox(height: 10),
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
    if (selected != null && mounted) setState(() => _city = selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final times = _sky.calculate(_date, _city);
    final moon = _astronomy.snapshot(_date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('آسمان و نور'),
        actions: [
          TextButton.icon(onPressed: _pickCity, icon: const Icon(Icons.location_on_outlined), label: Text(_city.name)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_twilight_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Text('نور مناسب عکاسی', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  ],
                ),
                const SizedBox(height: 16),
                _WindowRow(title: 'Blue Hour صبح', value: _window(times.morningBlueHour), icon: Icons.nights_stay_outlined),
                _WindowRow(title: 'Golden Hour صبح', value: _window(times.morningGoldenHour), icon: Icons.wb_sunny_outlined),
                _WindowRow(title: 'Golden Hour عصر', value: _window(times.eveningGoldenHour), icon: Icons.sunny_snowing),
                _WindowRow(title: 'Blue Hour شب', value: _window(times.eveningBlueHour), icon: Icons.dark_mode_outlined),
                const SizedBox(height: 10),
                Text('زمان‌های Golden/Blue Hour در این نسخه به‌صورت تقریبی و بر پایه طلوع/غروب محلی محاسبه می‌شوند.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: 'خورشید و ماه',
            children: [
              _InfoLine(label: 'طلوع خورشید', value: _time(times.sunrise)),
              _InfoLine(label: 'ظهر خورشیدی', value: _time(times.solarNoon)),
              _InfoLine(label: 'غروب خورشید', value: _time(times.sunset)),
              _InfoLine(label: 'طلوع ماه', value: _time(times.moonrise)),
              _InfoLine(label: 'عبور ماه', value: _time(times.moonTransit)),
              _InfoLine(label: 'غروب ماه', value: _time(times.moonset)),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: 'وضعیت فعلی ماه',
            children: [
              _InfoLine(label: 'فاز', value: moon.phaseName),
              _InfoLine(label: 'روشنایی', value: '${_fa((moon.illumination * 100).round())}٪'),
              _InfoLine(label: 'سن ماه', value: '${_fa(moon.moonAgeDays.toStringAsFixed(1))} روز'),
              _InfoLine(label: 'برج', value: moon.zodiacName),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.calendar_view_month_rounded)),
              title: const Text('تقویم ماهانه فاز ماه', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('فاز، روشنایی و سن ماه برای تک‌تک روزهای ماه شمسی'),
              trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LunarMonthPage(initialDate: _date))),
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}
