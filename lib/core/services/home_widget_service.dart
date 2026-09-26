import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'astronomy_service.dart';
import 'iran_holidays.dart';
import 'local_store.dart';

class MahNegarHomeWidgetService {
  MahNegarHomeWidgetService({
    LocalStore? store,
    AstronomyService? astronomy,
    IranHolidays? holidays,
  })  : _store = store ?? LocalStore(),
        _astronomy = astronomy ?? AstronomyService(),
        _holidays = holidays ?? IranHolidays();

  final LocalStore _store;
  final AstronomyService _astronomy;
  final IranHolidays _holidays;

  static const providerName = 'MahNegarWidgetProvider';
  static const qualifiedProviderName = 'ir.sahand.mahnegar.MahNegarWidgetProvider';

  Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    final jalali = Jalali.now();
    final astro = _astronomy.snapshot(now);
    final occasions = _holidays.forDate(jalali);
    final entries = await _store.load();
    final upcoming = entries
        .where((e) => !e.completed && e.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    await Future.wait<bool?>([
      HomeWidget.saveWidgetData<String>('date', '${_fa(jalali.year)}/${_fa(jalali.month)}/${_fa(jalali.day)}'),
      HomeWidget.saveWidgetData<String>('occasion', occasions.isEmpty ? 'بدون مناسبت' : occasions.first),
      HomeWidget.saveWidgetData<String>('moon', astro.phaseName),
      HomeWidget.saveWidgetData<String>('scorpio', astro.isMoonInScorpio ? 'قمر در عقرب' : 'قمر در عقرب نیست'),
      HomeWidget.saveWidgetData<String>('next', upcoming.isEmpty ? 'برنامه‌ای ثبت نشده' : upcoming.first.title),
    ]);
    await HomeWidget.updateWidget(
      name: providerName,
      androidName: providerName,
      qualifiedAndroidName: qualifiedProviderName,
    );
  }

  Future<void> requestPin() async {
    if (!Platform.isAndroid) return;
    await refresh();
    await HomeWidget.requestPinWidget(
      name: providerName,
      androidName: providerName,
      qualifiedAndroidName: qualifiedProviderName,
    );
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
}
