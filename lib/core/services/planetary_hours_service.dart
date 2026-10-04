import 'sky_times_service.dart';

enum PlanetaryRuler {
  saturn('زحل', '♄'),
  jupiter('مشتری', '♃'),
  mars('مریخ', '♂'),
  sun('شمس', '☉'),
  venus('زهره', '♀'),
  mercury('عطارد', '☿'),
  moon('قمر', '☽');

  const PlanetaryRuler(this.faName, this.symbol);
  final String faName;
  final String symbol;
}

class PlanetaryHourSlot {
  const PlanetaryHourSlot({
    required this.index,
    required this.ruler,
    required this.start,
    required this.end,
    required this.isDay,
  });

  final int index;
  final PlanetaryRuler ruler;
  final DateTime start;
  final DateTime end;
  final bool isDay;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);
}

class PlanetaryHoursDay {
  const PlanetaryHoursDay({
    required this.date,
    required this.city,
    required this.sunrise,
    required this.sunset,
    required this.nextSunrise,
    required this.dayRuler,
    required this.slots,
  });

  final DateTime date;
  final SkyCity city;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime nextSunrise;
  final PlanetaryRuler dayRuler;
  final List<PlanetaryHourSlot> slots;

  List<PlanetaryHourSlot> get daySlots =>
      slots.where((slot) => slot.isDay).toList(growable: false);

  List<PlanetaryHourSlot> get nightSlots =>
      slots.where((slot) => !slot.isDay).toList(growable: false);
}

class PlanetaryHoursService {
  PlanetaryHoursService({SkyTimesService? sky})
      : _sky = sky ?? SkyTimesService();

  final SkyTimesService _sky;

  static const chaldeanOrder = <PlanetaryRuler>[
    PlanetaryRuler.saturn,
    PlanetaryRuler.jupiter,
    PlanetaryRuler.mars,
    PlanetaryRuler.sun,
    PlanetaryRuler.venus,
    PlanetaryRuler.mercury,
    PlanetaryRuler.moon,
  ];

  PlanetaryRuler dayRuler(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return PlanetaryRuler.moon;
      case DateTime.tuesday:
        return PlanetaryRuler.mars;
      case DateTime.wednesday:
        return PlanetaryRuler.mercury;
      case DateTime.thursday:
        return PlanetaryRuler.jupiter;
      case DateTime.friday:
        return PlanetaryRuler.venus;
      case DateTime.saturday:
        return PlanetaryRuler.saturn;
      case DateTime.sunday:
        return PlanetaryRuler.sun;
      default:
        return PlanetaryRuler.sun;
    }
  }

  PlanetaryHoursDay? calculate(DateTime date, SkyCity city) {
    final civilDate = DateTime(date.year, date.month, date.day);
    final today = _sky.calculate(civilDate, city);
    final tomorrowDate = civilDate.add(const Duration(days: 1));
    final tomorrow = _sky.calculate(tomorrowDate, city);

    final sunrise = today.sunrise;
    final sunset = today.sunset;
    final nextSunrise = tomorrow.sunrise;
    if (sunrise == null || sunset == null || nextSunrise == null) return null;
    if (!sunset.isAfter(sunrise) || !nextSunrise.isAfter(sunset)) return null;

    final ruler = dayRuler(civilDate);
    final firstIndex = chaldeanOrder.indexOf(ruler);
    final dayMicros = sunset.difference(sunrise).inMicroseconds;
    final nightMicros = nextSunrise.difference(sunset).inMicroseconds;

    final slots = <PlanetaryHourSlot>[];
    for (var i = 0; i < 12; i++) {
      final start = sunrise.add(Duration(microseconds: dayMicros * i ~/ 12));
      final end = sunrise.add(Duration(microseconds: dayMicros * (i + 1) ~/ 12));
      slots.add(PlanetaryHourSlot(
        index: i + 1,
        ruler: chaldeanOrder[(firstIndex + i) % chaldeanOrder.length],
        start: start,
        end: end,
        isDay: true,
      ));
    }

    for (var i = 0; i < 12; i++) {
      final start = sunset.add(Duration(microseconds: nightMicros * i ~/ 12));
      final end = sunset.add(Duration(microseconds: nightMicros * (i + 1) ~/ 12));
      slots.add(PlanetaryHourSlot(
        index: i + 1,
        ruler: chaldeanOrder[(firstIndex + 12 + i) % chaldeanOrder.length],
        start: start,
        end: end,
        isDay: false,
      ));
    }

    return PlanetaryHoursDay(
      date: civilDate,
      city: city,
      sunrise: sunrise,
      sunset: sunset,
      nextSunrise: nextSunrise,
      dayRuler: ruler,
      slots: List.unmodifiable(slots),
    );
  }

  PlanetaryHourSlot? current(DateTime now, SkyCity city) {
    final today = calculate(now, city);
    if (today != null && now.isBefore(today.sunrise)) {
      final previous = calculate(now.subtract(const Duration(days: 1)), city);
      if (previous != null) {
        for (final slot in previous.slots) {
          if (slot.contains(now)) return slot;
        }
      }
    }
    if (today != null) {
      for (final slot in today.slots) {
        if (slot.contains(now)) return slot;
      }
    }
    return null;
  }

  PlanetaryHourSlot? nextFor(
    PlanetaryRuler ruler,
    DateTime after,
    SkyCity city, {
    int searchDays = 4,
  }) {
    for (var offset = -1; offset <= searchDays; offset++) {
      final day = calculate(after.add(Duration(days: offset)), city);
      if (day == null) continue;
      for (final slot in day.slots) {
        if (slot.ruler == ruler && slot.start.isAfter(after)) return slot;
      }
    }
    return null;
  }

  List<PlanetaryHourSlot> upcomingFor(
    PlanetaryRuler ruler,
    DateTime after,
    SkyCity city, {
    int days = 14,
    int limit = 30,
  }) {
    final result = <PlanetaryHourSlot>[];
    for (var offset = -1; offset <= days && result.length < limit; offset++) {
      final day = calculate(after.add(Duration(days: offset)), city);
      if (day == null) continue;
      for (final slot in day.slots) {
        if (slot.ruler == ruler && slot.start.isAfter(after)) {
          result.add(slot);
          if (result.length >= limit) break;
        }
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }
}
