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
    SkyCity('مشهد', 36.2605, 59.6168),
    SkyCity('اصفهان', 32.6546, 51.6680),
    SkyCity('شیراز', 29.5918, 52.5837),
    SkyCity('تبریز', 38.0800, 46.2919),
    SkyCity('تورنتو', 43.6532, -79.3832),
    SkyCity('ونکوور', 49.2827, -123.1207),
    SkyCity('مونترال', 45.5017, -73.5673),
  ];
}

class SkyTimes {
  const SkyTimes({
    this.sunrise,
    this.sunset,
    this.solarNoon,
    this.moonrise,
    this.moonset,
    this.moonTransit,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? solarNoon;
  final DateTime? moonrise;
  final DateTime? moonset;
  final DateTime? moonTransit;
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

    return SkyTimes(
      sunrise: fromJd(sun.rise),
      sunset: fromJd(sun.set),
      solarNoon: fromJd(sun.noon),
      moonrise: fromSeconds(moonResult?.rise),
      moonset: fromSeconds(moonResult?.set),
      moonTransit: fromSeconds(moonResult?.transit),
    );
  }
}
