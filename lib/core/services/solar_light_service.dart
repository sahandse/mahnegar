import 'dart:math' as math;

import 'sky_times_service.dart';

class SolarLightWindows {
  const SolarLightWindows({
    required this.morningBlue,
    required this.morningGolden,
    required this.eveningGolden,
    required this.eveningBlue,
  });

  final LightWindow morningBlue;
  final LightWindow morningGolden;
  final LightWindow eveningGolden;
  final LightWindow eveningBlue;
}

class SolarLightService {
  SolarLightWindows calculate(DateTime localDate, SkyCity city) {
    DateTime? crossing(double altitude, bool morning) {
      final dayOfYear = int.parse(
        '${localDate.year}${localDate.month.toString().padLeft(2, '0')}${localDate.day.toString().padLeft(2, '0')}',
      );
      final start = DateTime(localDate.year, localDate.month, localDate.day);
      final n = start.difference(DateTime(localDate.year, 1, 1)).inDays + 1;
      final gamma = 2 * math.pi / 365 * (n - 1 + (morning ? 6 : 18) / 24);
      final eqTime = 229.18 *
          (0.000075 +
              0.001868 * math.cos(gamma) -
              0.032077 * math.sin(gamma) -
              0.014615 * math.cos(2 * gamma) -
              0.040849 * math.sin(2 * gamma));
      final decl = 0.006918 -
          0.399912 * math.cos(gamma) +
          0.070257 * math.sin(gamma) -
          0.006758 * math.cos(2 * gamma) +
          0.000907 * math.sin(2 * gamma) -
          0.002697 * math.cos(3 * gamma) +
          0.00148 * math.sin(3 * gamma);
      final lat = city.latitude * math.pi / 180;
      final zenith = (90 - altitude) * math.pi / 180;
      final cosH = (math.cos(zenith) / (math.cos(lat) * math.cos(decl))) -
          math.tan(lat) * math.tan(decl);
      if (cosH < -1 || cosH > 1) return null;
      final h = math.acos(cosH) * 180 / math.pi;
      final solarMinutes = 720 - 4 * (city.longitude + (morning ? h : -h)) - eqTime;

      final noon = DateTime(localDate.year, localDate.month, localDate.day, 12);
      final zoneOffsetMinutes = noon.timeZoneOffset.inMinutes;
      final localMinutes = solarMinutes + zoneOffsetMinutes;
      final midnight = DateTime(localDate.year, localDate.month, localDate.day);
      return midnight.add(Duration(seconds: (localMinutes * 60).round()));
    }

    LightWindow window(double startAltitude, double endAltitude, bool morning) {
      final a = crossing(startAltitude, morning);
      final b = crossing(endAltitude, morning);
      if (morning) return LightWindow(start: a, end: b);
      return LightWindow(start: b, end: a);
    }

    return SolarLightWindows(
      morningBlue: window(-6, -4, true),
      morningGolden: window(-4, 6, true),
      eveningGolden: window(-4, 6, false),
      eveningBlue: window(-6, -4, false),
    );
  }
}
