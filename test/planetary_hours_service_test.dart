import 'package:flutter_test/flutter_test.dart';
import 'package:mahnegar/core/services/planetary_hours_service.dart';

void main() {
  group('PlanetaryHoursService', () {
    final service = PlanetaryHoursService();

    test('uses the traditional weekday rulers', () {
      // 2026-10-05 is Monday.
      final monday = DateTime(2026, 10, 5);
      expect(service.dayRuler(monday), PlanetaryRuler.moon);
      expect(service.dayRuler(monday.add(const Duration(days: 1))), PlanetaryRuler.mars);
      expect(service.dayRuler(monday.add(const Duration(days: 2))), PlanetaryRuler.mercury);
      expect(service.dayRuler(monday.add(const Duration(days: 3))), PlanetaryRuler.jupiter);
      expect(service.dayRuler(monday.add(const Duration(days: 4))), PlanetaryRuler.venus);
      expect(service.dayRuler(monday.add(const Duration(days: 5))), PlanetaryRuler.saturn);
      expect(service.dayRuler(monday.add(const Duration(days: 6))), PlanetaryRuler.sun);
    });

    test('keeps the Chaldean order', () {
      expect(
        PlanetaryHoursService.chaldeanOrder,
        const [
          PlanetaryRuler.saturn,
          PlanetaryRuler.jupiter,
          PlanetaryRuler.mars,
          PlanetaryRuler.sun,
          PlanetaryRuler.venus,
          PlanetaryRuler.mercury,
          PlanetaryRuler.moon,
        ],
      );
    });
  });
}
