import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahnegar/core/services/astronomy_alert_service.dart';
import 'package:mahnegar/core/services/home_widget_service.dart';
import 'package:mahnegar/core/services/notification_service.dart';
import 'package:mahnegar/features/home/mahnegar_home.dart';
import 'package:mahnegar/features/onboarding/onboarding_gate.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MahNegarApp()));
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  try {
    await MahNegarNotificationService.instance.initialize();
    await MahNegarHomeWidgetService().refresh();
    if (await AstronomyAlertService.instance.isEnabled()) {
      await AstronomyAlertService.instance.scheduleUpcoming();
    }
  } catch (error, stackTrace) {
    debugPrint('MahNegar optional services init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MahNegarApp extends StatelessWidget {
  const MahNegarApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFF8B93FF) : const Color(0xFF3347C8),
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0C0E15) : const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF151925) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A1F2C) : const Color(0xFFF1F3F9),
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.vazirmatnTextTheme(base.primaryTextTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ماه‌نگار',
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: OnboardingGate(child: MahNegarHome()),
        ),
      ),
    );
  }
}
