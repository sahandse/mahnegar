import 'dart:math' as math;

import 'package:astronomia/astronomia.dart';
import 'package:astronomia/coord.dart' as coord;
import 'package:astronomia/moonposition.dart' as moon;
import 'package:astronomia/rise.dart' as rise;
import 'package:astronomia/sidereal.dart' as sid;
import 'package:astronomia/sunrise.dart' as sunrise;

class SkyCity {
  const SkyCity(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;

  static const presets = <SkyCity>[
    SkyCity('تهران', 35.6892, 51.3890),
    SkyCity('کرج', 35.8400, 50.9391),
    SkyCity('مشهد', 36.2605, 59.6168),
    SkyCity('اصفهان', 32.6546, 51.6680),
    SkyCity('شیراز', 29.5918, 52.5837),
    SkyCity('تبریز', 38.0800, 46.2919),
    SkyCity('قم', 34.6416, 50.8746),
    SkyCity('اهواز', 31.3183, 48.6706),
    SkyCity('کرمانشاه', 34.3142, 47.0650),
    SkyCity('ارومیه', 37.5527, 45.0761),
    SkyCity('رشت', 37.2808, 49.5832),
    SkyCity('زاهدان', 29.4963, 60.8629),
    SkyCity('کرمان', 30.2839, 57.0834),
    SkyCity('همدان', 34.7992, 48.5146),
    SkyCity('اراک', 34.0917, 49.6892),
    SkyCity('یزد', 31.8974, 54.3569),
    SkyCity('اردبیل', 38.2498, 48.2933),
    SkyCity('بندرعباس', 27.1832, 56.2666),
    SkyCity('بوشهر', 28.9234, 50.8203),
    SkyCity('قزوین', 36.2688, 50.0041),
    SkyCity('سنندج', 35.3219, 46.9862),
    SkyCity('خرم‌آباد', 33.4878, 48.3558),
    SkyCity('گرگان', 36.8427, 54.4439),
    SkyCity('ساری', 36.5659, 53.0586),
    SkyCity('بجنورد', 37.4747, 57.3290),
    SkyCity('بیرجند', 32.8649, 59.2262),
    SkyCity('شهرکرد', 32.3256, 50.8644),
    SkyCity('یاسوج', 30.6682, 51.5870),
    SkyCity('ایلام', 33.6374, 46.4227),
    SkyCity('سمنان', 35.5769, 53.3921),
    SkyCity('زنجان', 36.6769, 48.4963),
    SkyCity('فرانکفورت', 50.1109, 8.6821),
    SkyCity('استانبول', 41.0082, 28.9784),
    SkyCity('دبی', 25.2048, 55.2708),
    SkyCity('تورنتو', 43.6532, -79.3832),
    SkyCity('ونکوور', 49.2827, -123.1207),
    SkyCity('مونترال', 45.5017, -73.5673),
  ];
}

class LightWindow {
  const LightWindow({required this.start, required this.end});
  final DateTime? start;
  final DateTime? end;

  bool get available => start != null && end != null;
}

class SkyTimes {
  const SkyTimes({
    this.sunrise,
    this.sunset,
    this.solarNoon,
    this.moonrise,
    this.moonset,
    this.moonTransit,
    required this.morningBlueHour,
    required this.morningGoldenHour,
    required this.eveningGoldenHour,
    required this.eveningBlueHour,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? solarNoon;
  final DateTime? moonrise;
  final DateTime? moonset;
  final DateTime? moonTransit;
  final LightWindow morningBlueHour;
  final LightWindow morningGoldenHour;
  final LightWindow eveningGoldenHour;
  final LightWindow eveningBlueHour;
}

class SkyTimesService {
  SkyTimes calculate(DateTime localDate, SkyCity city) {
    final utcMidnight = DateTime.utc(localDate.year, localDate.month, localDate.day);
    final jd = calendarGregorianToJD(localDate.year, localDate.month, localDate.day.toDouble());
    final lat = toRad(city.latitude);
    // Astronomia follows Meeus convention: longitude is positive west.
    final lon = toRad(-city.longitude);

    final sun = sunrise.sunriseSunset(jd, lat, lon);
    final th0 = sid.apparent0UT(jd);
    final moonResult = rise.moonTimes(jd, lat, lon, 69.0, th0, (jde) {
      final pos = moon.position(jde);
      const epsDeg = 23.4392911;
      final eps = toRad(epsDeg);
      final eq = coord.eclToEq(pos.lon, pos.lat, math.sin(eps), math.cos(eps));
      return (ra: eq.ra, dec: eq.dec, parallax: moon.parallax(pos.delta));
    });

    DateTime? fromJd(double? value) {
      if (value == null) return null;
      final seconds = ((value - jd) * 86400).round();
      return utcMidnight.add(Duration(seconds: seconds)).toLocal();
    }

    DateTime? fromSeconds(double? value) {
      if (value == null) return null;
      return utcMidnight.add(Duration(seconds: value.round())).toLocal();
    }

    final localSunrise = fromJd(sun.rise);
    final localSunset = fromJd(sun.set);

    // Photography windows are intentionally approximate, anchored to local
    // sunrise/sunset. This keeps the feature deterministic/offline while the
    // UI clearly labels the windows as approximate.
    LightWindow shift(DateTime? anchor, Duration startDelta, Duration endDelta) => LightWindow(
          start: anchor?.add(startDelta),
          end: anchor?.add(endDelta),
        );

    return SkyTimes(
      sunrise: localSunrise,
      sunset: localSunset,
      solarNoon: fromJd(sun.noon),
      moonrise: fromSeconds(moonResult?.rise),
      moonset: fromSeconds(moonResult?.set),
      moonTransit: fromSeconds(moonResult?.transit),
      morningBlueHour: shift(localSunrise, const Duration(minutes: -50), const Duration(minutes: -20)),
      morningGoldenHour: shift(localSunrise, const Duration(minutes: -20), const Duration(minutes: 45)),
      eveningGoldenHour: shift(localSunset, const Duration(minutes: -45), const Duration(minutes: 20)),
      eveningBlueHour: shift(localSunset, const Duration(minutes: 20), const Duration(minutes: 50)),
    );
  }
}
