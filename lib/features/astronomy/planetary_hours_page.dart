import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/device_sky_service.dart';
import '../../core/services/planetary_alarm_service.dart';
import '../../core/services/planetary_hours_service.dart';
import '../../core/services/sky_times_service.dart';

class PlanetaryHoursPage extends StatefulWidget {
  const PlanetaryHoursPage({super.key, this.initialCity});

  final SkyCity? initialCity;

  @override
  State<PlanetaryHoursPage> createState() => _PlanetaryHoursPageState();
}

class _PlanetaryHoursPageState extends State<PlanetaryHoursPage> {
  final _planetary = PlanetaryHoursService();
  final _alarm = PlanetaryAlarmService.instance;
  final _deviceSky = DeviceSkyService();

  late SkyCity _city;
  DateTime _date = DateTime.now();
  bool _alarmEnabled = false;
  int _leadMinutes = 5;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity ?? SkyCity.presets.first;
    _loadAlarm();
  }

  Future<void> _loadAlarm() async {
    final settings = await _alarm.loadSettings();
    if (!mounted) return;
    setState(() {
      _alarmEnabled = settings.enabled;
      _leadMinutes = settings.leadMinutes;
      if (widget.initialCity == null && settings.enabled) {
        _city = settings.city;
      }
    });
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

  String _time(DateTime value) => _fa(DateFormat('HH:mm').format(value));

  String _weekday(DateTime value) {
    const names = ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'];
    return names[value.weekday - 1];
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'انتخاب روز',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final city = await _deviceSky.currentLocation();
      if (!mounted) return;
      if (city == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('موقعیت دریافت نشد یا دسترسی Location فعال نیست.')),
        );
        return;
      }
      setState(() => _city = city);
      if (_alarmEnabled) {
        await _alarm.updateLocationAndLead(city: city, leadMinutes: _leadMinutes);
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
                title: const Text('موقعیت فعلی من', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('محاسبه با GPS دستگاه'),
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
    if (selected == null || !mounted) return;
    setState(() => _city = selected);
    if (_alarmEnabled) {
      await _alarm.updateLocationAndLead(city: selected, leadMinutes: _leadMinutes);
    }
  }

  Future<void> _setAlarm(bool enabled) async {
    if (enabled) {
      final allowed = await _alarm.requestPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برای هشدار ساعت مشتری، اجازه اعلان لازم است.')),
        );
      }
    }
    await _alarm.setEnabled(
      enabled,
      city: _city,
      leadMinutes: _leadMinutes,
    );
    if (mounted) setState(() => _alarmEnabled = enabled);
  }

  Future<void> _setLead(int value) async {
    setState(() => _leadMinutes = value);
    await _alarm.updateLocationAndLead(city: _city, leadMinutes: value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final schedule = _planetary.calculate(_date, _city);
    final now = DateTime.now();
    final current = _planetary.current(now, _city);
    final nextJupiter = _planetary.nextFor(PlanetaryRuler.jupiter, now, _city);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اوقات کواکب'),
        actions: [
          TextButton.icon(
            onPressed: _pickCity,
            icon: const Icon(Icons.location_on_outlined),
            label: Text(_locating ? 'در حال دریافت…' : _city.name),
          ),
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.today_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
              ),
            ),
            child: Column(children: [
              Text('ساعت فعلی', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(current?.ruler.symbol ?? '✦', style: const TextStyle(fontSize: 62, height: 1)),
              const SizedBox(height: 8),
              Text(
                current == null ? 'خارج از بازه محاسبه' : 'ساعت ${current.ruler.faName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (current != null) ...[
                const SizedBox(height: 5),
                Text('${_time(current.start)} تا ${_time(current.end)}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
                  child: const Text('♃', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('مشتری بعدی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      nextJupiter == null
                          ? 'زمان بعدی پیدا نشد'
                          : '${_weekday(nextJupiter.start)} • ${_time(nextJupiter.start)} تا ${_time(nextJupiter.end)}',
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(children: [
              SwitchListTile(
                value: _alarmEnabled,
                secondary: const Icon(Icons.notifications_active_rounded),
                title: const Text('Jupiter Alarm', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('برای شروع ساعت مشتری یادآوری بفرست'),
                onChanged: _setAlarm,
              ),
              if (_alarmEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('زمان هشدار', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [0, 5, 10, 15].map((minutes) {
                        final label = minutes == 0 ? 'همان لحظه' : '$minutes دقیقه قبل';
                        return ChoiceChip(
                          label: Text(label),
                          selected: _leadMinutes == minutes,
                          onSelected: (_) => _setLead(minutes),
                        );
                      }).toList(),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          if (schedule == null)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('برای این تاریخ/موقعیت امکان محاسبه طلوع و غروب وجود ندارد.')))
          else ...[
            _ScheduleCard(
              title: '☀️ ساعات روز',
              subtitle: '${_time(schedule.sunrise)} تا ${_time(schedule.sunset)} • حاکم روز: ${schedule.dayRuler.symbol} ${schedule.dayRuler.faName}',
              slots: schedule.daySlots,
              current: current,
              time: _time,
              fa: _fa,
            ),
            const SizedBox(height: 14),
            _ScheduleCard(
              title: '🌙 ساعات شب',
              subtitle: '${_time(schedule.sunset)} تا ${_time(schedule.nextSunrise)}',
              slots: schedule.nightSlots,
              current: current,
              time: _time,
              fa: _fa,
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
            child: Text(
              'اوقات کواکب یک روش سنتی است: فاصله طلوع تا غروب و فاصله غروب تا طلوع بعدی هر کدام به ۱۲ بخش تقسیم می‌شوند. این بخش برای مرجع فرهنگی و زمان‌بندی شخصی است و اثر علمی یا پیش‌بینی قطعی ادعا نمی‌کند.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.title,
    required this.subtitle,
    required this.slots,
    required this.current,
    required this.time,
    required this.fa,
  });

  final String title;
  final String subtitle;
  final List<PlanetaryHourSlot> slots;
  final PlanetaryHourSlot? current;
  final String Function(DateTime) time;
  final String Function(Object) fa;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ...slots.map((slot) {
            final active = current != null &&
                current!.start == slot.start &&
                current!.ruler == slot.ruler;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? scheme.primaryContainer : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                SizedBox(width: 28, child: Text(fa(slot.index), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(slot.ruler.symbol, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Text(slot.ruler.faName, style: const TextStyle(fontWeight: FontWeight.w900))),
                Text('${time(slot.start)} – ${time(slot.end)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}
