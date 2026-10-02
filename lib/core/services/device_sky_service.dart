import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import 'sky_times_service.dart';

class DeviceSkyService {
  Stream<double?> get headingStream =>
      FlutterCompass.events?.map((event) => event.heading) ?? const Stream<double?>.empty();

  Future<SkyCity?> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return SkyCity('موقعیت من', position.latitude, position.longitude);
  }
}
