import 'dart:math' as math;

import 'package:astronomia/astronomia.dart';
import 'package:astronomia/moonposition.dart' as moon;
import 'package:astronomia/solar.dart' as solar;

class AstronomySnapshot {
  const AstronomySnapshot({
    required this.moonLongitude,
    required this.sunLongitude,
    required this.illumination,
    required this.phaseAngle,
    required this.moonAgeDays,
    required this.distanceKm,
    required this.phaseName,
    required this.zodiacName,
    required this.isMoonInScorpio,
  });

  final double moonLongitude;
  final double sunLongitude;
  final double illumination;
  final double phaseAngle;
  final double moonAgeDays;
  final double distanceKm;
  final String phaseName;
  final String zodiacName;
  final bool isMoonInScorpio;
}

class LunarEvent {
  const LunarEvent(this.name, this.time, this.angle);
  final String name;
  final DateTime time;
  final double angle;
}

class AstronomyService {
  static const zodiac = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله',
    'میزان', 'عقرب', 'قوس', 'جدی', 'دلو', 'حوت',
  ];

  static const _synodicMonth = 29.530588853;

  AstronomySnapshot snapshot(DateTime date) {
    final utc = date.toUtc();
    final day = utc.day +
        (utc.hour + (utc.minute + utc.second / 60) / 60) / 24;
    final jd = calendarGregorianToJD(utc.year, utc.month, day);
    final moonPos = moon.position(jd);
    final sunLon = solar.apparentLongitude(j2000Century(jd));

    final moonLon = _normalize(toDeg(moonPos.lon));
    final sunLongitude = _normalize(toDeg(sunLon));
    final elongation = _normalize(moonLon - sunLongitude);
    final illumination = (1 - math.cos(toRad(elongation))) / 2;
    final zodiacIndex = (moonLon / 30).floor() % 12;

    return AstronomySnapshot(
      moonLongitude: moonLon,
      sunLongitude: sunLongitude,
      illumination: illumination.clamp(0, 1),
      phaseAngle: elongation,
      moonAgeDays: elongation / 360 * _synodicMonth,
      distanceKm: _approxMoonDistanceKm(jd),
      phaseName: _phase(elongation),
      zodiacName: zodiac[zodiacIndex],
      isMoonInScorpio: zodiacIndex == 7,
    );
  }

  DateTime? nextScorpioTransition(DateTime from, {bool entering = true}) {
    var previous = snapshot(from).isMoonInScorpio;
    var cursor = from;
    for (var i = 0; i < 16 * 24; i++) {
      cursor = cursor.add(const Duration(hours: 1));
      final current = snapshot(cursor).isMoonInScorpio;
      if (entering && !previous && current) {
        return _refineBoolean(cursor.subtract(const Duration(hours: 1)), true);
      }
      if (!entering && previous && !current) {
        return _refineBoolean(cursor.subtract(const Duration(hours: 1)), false);
      }
      previous = current;
    }
    return null;
  }

  ({DateTime? start, DateTime? end}) scorpioWindow(DateTime from) {
    final current = snapshot(from).isMoonInScorpio;
    if (current) {
      final end = nextScorpioTransition(from, entering: false);
      DateTime? start;
      var cursor = from;
      for (var i = 0; i < 72; i++) {
        final previous = cursor.subtract(const Duration(hours: 1));
        if (!snapshot(previous).isMoonInScorpio) {
          start = _refineBoolean(previous, true);
          break;
        }
        cursor = previous;
      }
      return (start: start, end: end);
    }
    final start = nextScorpioTransition(from, entering: true);
    final end = start == null
        ? null
        : nextScorpioTransition(start.add(const Duration(hours: 1)), entering: false);
    return (start: start, end: end);
  }

  LunarEvent nextLunarEvent(DateTime from, double targetAngle, String name) {
    var cursor = from;
    var previous = _signedPhaseDelta(snapshot(cursor).phaseAngle, targetAngle);
    for (var i = 1; i <= 40 * 24; i++) {
      final next = from.add(Duration(hours: i));
      final current = _signedPhaseDelta(snapshot(next).phaseAngle, targetAngle);
      if ((previous <= 0 && current >= 0) || (previous >= 0 && current <= 0 && previous.abs() > 120)) {
        final refined = _refinePhase(cursor, next, targetAngle);
        return LunarEvent(name, refined, targetAngle);
      }
      previous = current;
      cursor = next;
    }
    return LunarEvent(name, from.add(const Duration(days: 29)), targetAngle);
  }

  List<LunarEvent> upcomingMajorPhases(DateTime from) {
    final values = <LunarEvent>[
      nextLunarEvent(from, 0, 'ماه نو'),
      nextLunarEvent(from, 90, 'تربیع اول'),
      nextLunarEvent(from, 180, 'ماه کامل'),
      nextLunarEvent(from, 270, 'تربیع آخر'),
    ];
    values.sort((a, b) => a.time.compareTo(b.time));
    return values;
  }

  DateTime _refineBoolean(DateTime start, bool entering) {
    var low = start;
    var high = start.add(const Duration(hours: 1));
    for (var i = 0; i < 12; i++) {
      final mid = low.add(Duration(milliseconds: high.difference(low).inMilliseconds ~/ 2));
      final inScorpio = snapshot(mid).isMoonInScorpio;
      if (inScorpio == entering) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return high;
  }

  DateTime _refinePhase(DateTime lowStart, DateTime highStart, double target) {
    var low = lowStart;
    var high = highStart;
    for (var i = 0; i < 14; i++) {
      final mid = low.add(Duration(milliseconds: high.difference(low).inMilliseconds ~/ 2));
      final lowDelta = _signedPhaseDelta(snapshot(low).phaseAngle, target);
      final midDelta = _signedPhaseDelta(snapshot(mid).phaseAngle, target);
      if ((lowDelta <= 0 && midDelta >= 0) || (lowDelta >= 0 && midDelta <= 0 && lowDelta.abs() < 90)) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return high;
  }

  double _signedPhaseDelta(double phase, double target) {
    var delta = _normalize(phase - target);
    if (delta > 180) delta -= 360;
    return delta;
  }

  double _approxMoonDistanceKm(double jd) {
    final d = jd - 2451543.5;
    final m = toRad(_normalize(115.3654 + 13.0649929509 * d));
    final f = toRad(_normalize(93.2721 + 13.22935024 * d));
    final distance = 385000.56 -
        20905.0 * math.cos(m) -
        3699.0 * math.cos(2 * f - m) -
        2956.0 * math.cos(2 * f) -
        570.0 * math.cos(2 * m);
    return distance.clamp(350000, 410000).toDouble();
  }

  String _phase(double angle) {
    if (angle < 22.5 || angle >= 337.5) return 'ماه نو';
    if (angle < 67.5) return 'هلال افزاینده';
    if (angle < 112.5) return 'تربیع اول';
    if (angle < 157.5) return 'کوژ افزاینده';
    if (angle < 202.5) return 'ماه کامل';
    if (angle < 247.5) return 'کوژ کاهنده';
    if (angle < 292.5) return 'تربیع آخر';
    return 'هلال کاهنده';
  }

  double _normalize(double value) {
    final r = value % 360;
    return r < 0 ? r + 360 : r;
  }
}
