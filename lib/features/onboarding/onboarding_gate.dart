import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/branding/mahnegar_brand_logo.dart';
import '../../main.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? done;
  int page = 0;
  final controller = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => done = prefs.getBool('mahnegar_onboarding_done') ?? false);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mahnegar_onboarding_done', true);
    if (mounted) setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (done == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (done == true) return widget.child;
    final slides = <Widget>[
      _slide(Icons.calendar_month_rounded, 'تقویم فارسی، ساده و کامل', 'شمسی در مرکز؛ میلادی و قمری همیشه کنار آن. مناسبت‌ها، جلسه‌ها و کارها در یک جا.'),
      _slide(Icons.nights_stay_rounded, 'آسمان امروز', 'فاز ماه، روشنایی، برج ماه و قمر در عقرب با محاسبه نجومی؛ بدون تاریخ‌های ساختگی.'),
      _slide(Icons.tune_rounded, 'همه‌چیز انتخابی است', 'تقویم Google، مخاطبین، ویجت و اعلان‌ها فقط وقتی فعال می‌شوند که خودت بخواهی.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 28),
          const MahNegarBrandLogo(size: 92, borderRadius: 28),
          const SizedBox(height: 14),
          Text('ماه‌نگار', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Expanded(child: PageView(controller: controller, onPageChanged: (v) => setState(() => page = v), children: slides)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == page ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: i == page ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(10)),
          ))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(children: [
              if (page == 2)
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => themeModeNotifier.value = ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: const Text('روشن'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => themeModeNotifier.value = ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: const Text('تیره'))),
                ]),
              if (page == 2) const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: page == slides.length - 1 ? _finish : () => controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                child: Text(page == slides.length - 1 ? 'شروع ماه‌نگار' : 'بعدی'),
              )),
              TextButton(onPressed: _finish, child: const Text('رد کردن')),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _slide(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8)),
        ]),
      );
}
