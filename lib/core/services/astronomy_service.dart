import 'dart:math' as math;

import 'package:astronomia/astronomia.dart';
import 'package:astronomia/moonposition.dart' as moon;
import 'package:astronomia/solar.dart' as solar;

class AstronomySnapshot {
  const AstronomySnapshot({
    required this.moonLongitude,
    required this.sunLongitude,
    required this.illumination,
    required this.phaseName,
    required this.zodiacName,
    required this.isMoonInScorpio,
  });

  final double moonLongitude;
  final double sunLongitude;
  final double illumination;
  final String phaseName;
  final String zodiacName;
  final bool isMoonInScorpio;
}

class AstronomyService {
  static const zodiac = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله',
    'میزان', 'عقرب', 'قوس', 'جدی', 'دلو', 'حوت',
  ];

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
      if (entering && !previous && current) return _refine(cursor.subtract(const Duration(hours: 1)), true);
      if (!entering && previous && !current) return _refine(cursor.subtract(const Duration(hours: 1)), false);
      previous = current;
    }
    return null;
  }

  DateTime _refine(DateTime start, bool entering) {
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
