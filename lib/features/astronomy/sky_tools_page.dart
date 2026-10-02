import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/astronomy_alert_service.dart';
import '../../core/services/astronomy_service.dart';
import '../../core/services/device_sky_service.dart';
import '../../core/services/sky_times_service.dart';
import '../../core/services/solar_light_service.dart';
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
  final _deviceSky = DeviceSkyService();
  final _solarLight = SolarLightService();
  final _alerts = AstronomyAlertService.instance;

  late SkyCity _city;
  DateTime _date = DateTime.now();
  bool _alertsEnabled = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity ?? SkyCity.presets.first;
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final enabled = await _alerts.isEnabled();
    if (mounted) setState(() => _alertsEnabled = enabled);
  }

  String _fa(Object value) => value.toString()
      .replaceAll('0', '۰').replaceAll('1', '۱').replaceAll('2', '۲')
      .replaceAll('3', '۳').replaceAll('4', '۴').replaceAll('5', '۵')
      .replaceAll('6', '۶').replaceAll('7', '۷').replaceAll('8', '۸')
      .replaceAll('9', '۹');

  String _time(DateTime? value) => value == null ? '—' : _fa(DateFormat('HH:mm').format(value));
  String _window(LightWindow value) => value.available ? '${_time(value.start)} تا ${_time(value.end)}' : '—';

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final city = await _deviceSky.currentLocation();
      if (!mounted) return;
      if (city != null) {
        setState(() => _city = city);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دسترسی موقعیت فعال نیست یا موقعیت دریافت نشد.')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.my_location_rounded)),
                title: const Text('موقعیت فعلی من', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('استفاده از GPS دستگاه'),
                onTap: () {
                  Navigator.pop(context);
                  _useMyLocation();
                },
              ),
              const Divider(),
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
    if (selected != null && mounted) setState(() => _city = selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final times = _sky.calculate(_date, _city);
    final moon = _astronomy.snapshot(_date);
    final light = _solarLight.calculate(_date, _city);

    return Scaffold(
      appBar: AppBar(
        title: const Text('آسمان و نور'),
        actions: [
          TextButton.icon(onPressed: _pickCity, icon: const Icon(Icons.location_on_outlined), label: Text(_locating ? 'در حال دریافت…' : _city.name)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          _CompassCard(stream: _deviceSky.headingStream),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [scheme.primaryContainer, scheme.surfaceContainerHighest]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [const Icon(Icons.wb_twilight_rounded), const SizedBox(width: 10), Expanded(child: Text('Golden / Blue Hour', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 16),
              _WindowRow(title: 'Blue Hour صبح', value: _window(light.morningBlue), icon: Icons.nights_stay_outlined),
              _WindowRow(title: 'Golden Hour صبح', value: _window(light.morningGolden), icon: Icons.wb_sunny_outlined),
              _WindowRow(title: 'Golden Hour عصر', value: _window(light.eveningGolden), icon: Icons.sunny_snowing),
              _WindowRow(title: 'Blue Hour شب', value: _window(light.eveningBlue), icon: Icons.dark_mode_outlined),
              const SizedBox(height: 8),
              Text('این بازه‌ها بر اساس زاویه خورشید و مختصات شهر محاسبه می‌شوند.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 14),
          _InfoCard(title: 'خورشید و ماه', children: [
            _InfoLine(label: 'طلوع خورشید', value: _time(times.sunrise)),
            _InfoLine(label: 'ظهر خورشیدی', value: _time(times.solarNoon)),
            _InfoLine(label: 'غروب خورشید', value: _time(times.sunset)),
            _InfoLine(label: 'طلوع ماه', value: _time(times.moonrise)),
            _InfoLine(label: 'عبور ماه', value: _time(times.moonTransit)),
            _InfoLine(label: 'غروب ماه', value: _time(times.moonset)),
          ]),
          const SizedBox(height: 14),
          _InfoCard(title: 'وضعیت ماه', children: [
            _InfoLine(label: 'فاز', value: moon.phaseName),
            _InfoLine(label: 'روشنایی', value: '${_fa((moon.illumination * 100).round())}٪'),
            _InfoLine(label: 'سن ماه', value: '${_fa(moon.moonAgeDays.toStringAsFixed(1))} روز'),
            _InfoLine(label: 'برج', value: moon.zodiacName),
          ]),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: _alertsEnabled,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('هشدارهای نجومی', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('۶ ساعت قبل از فازهای مهم ماه و قمر در عقرب'),
              onChanged: (value) async {
                setState(() => _alertsEnabled = value);
                await _alerts.setEnabled(value);
              },
            ),
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

class _CompassCard extends StatelessWidget {
  const _CompassCard({required this.stream});
  final Stream<double?> stream;

  @override
  Widget build(BuildContext context) => StreamBuilder<double?>(
        stream: stream,
        builder: (context, snapshot) {
          final heading = snapshot.data;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Transform.rotate(
                    angle: heading == null ? 0 : -heading * math.pi / 180,
                    child: const Icon(Icons.navigation_rounded, size: 72),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('قطب‌نمای آسمان', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(heading == null ? 'سنسور قطب‌نما در دسترس نیست' : '${heading.round()}° از شمال'),
                ])),
              ]),
            ),
          );
        },
      );
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 10), Expanded(child: Text(title)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...children]),
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
