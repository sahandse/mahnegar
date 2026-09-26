from pathlib import Path

calendar = Path('lib/features/calendar/presentation/calendar_page.dart')
if calendar.exists():
    text = calendar.read_text(encoding='utf-8')

    brand_import = "import '../../../core/branding/mahnegar_brand_logo.dart';"
    anchor_import = "import '../../../main.dart';"
    if brand_import not in text:
        text = text.replace(anchor_import, f"{anchor_import}\n{brand_import}")

    start_marker = '  Widget _brandMark() {'
    end_marker = '\n  Widget _body()'
    if start_marker in text and end_marker in text:
        start = text.index(start_marker)
        end = text.index(end_marker, start)
        replacement = (
            "  Widget _brandMark() => const MahNegarBrandLogo(\n"
            "        size: 42,\n"
            "        borderRadius: 14,\n"
            "      );\n"
        )
        text = text[:start] + replacement + text[end:]

    calendar.write_text(text, encoding='utf-8')

# Keep notification controls inside Settings instead of a floating shortcut.
dashboard = Path('lib/features/home/mahnegar_dashboard.dart')
if dashboard.exists():
    text = dashboard.read_text(encoding='utf-8')

    settings_anchor = "          ListTile(leading: const Icon(Icons.wb_sunny_outlined), title: const Text('خلاصه صبحگاهی'), subtitle: const Text('اعلان اختیاری هر روز ساعت ۸ با برنامه امروز'), onTap: _configureMorning),"
    notification_tile = "          ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('اعلان و نوار وضعیت'), subtitle: const Text('تاریخ، مناسبت، فاز ماه، قمر در عقرب و برنامه بعدی'), trailing: const Icon(Icons.chevron_left_rounded), onTap: _openStatusNotificationSettings),\n"
    if 'onTap: _openStatusNotificationSettings' not in text and settings_anchor in text:
        text = text.replace(settings_anchor, notification_tile + settings_anchor)

    method_anchor = '  Future<void> _configureMorning() async {'
    if 'Future<void> _openStatusNotificationSettings()' not in text and method_anchor in text:
        methods = r'''  Future<void> _openStatusNotificationSettings() async {
    var draft = await _notifications.loadPreferences();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> update(NotificationPreferences value) async {
          draft = value;
          setSheet(() {});
          await _notifications.savePreferences(value);
          await _applyStatusNotification(value);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اعلان و نوار وضعیت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('انتخاب کن چه اطلاعاتی در اعلان دائمی و Lock Screen نمایش داده شود.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Card(child: SwitchListTile(
                value: draft.enabled,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('نمایش در نوار اعلان'),
                subtitle: const Text('کم‌اهمیت، بدون صدا و کاملاً اختیاری'),
                onChanged: (enabled) async {
                  if (enabled) {
                    final allowed = await _notifications.requestPermission();
                    if (!allowed) {
                      _snack('مجوز اعلان فعال نشد.');
                      return;
                    }
                  }
                  await update(draft.copyWith(enabled: enabled));
                },
              )),
              const SizedBox(height: 10),
              Opacity(
                opacity: draft.enabled ? 1 : .45,
                child: IgnorePointer(
                  ignoring: !draft.enabled,
                  child: Card(child: Column(children: [
                    CheckboxListTile(value: draft.showDate, title: const Text('تاریخ شمسی امروز'), onChanged: (v) => update(draft.copyWith(showDate: v ?? false))),
                    CheckboxListTile(value: draft.showOccasion, title: const Text('مناسبت امروز'), onChanged: (v) => update(draft.copyWith(showOccasion: v ?? false))),
                    CheckboxListTile(value: draft.showMoonPhase, title: const Text('فاز ماه'), onChanged: (v) => update(draft.copyWith(showMoonPhase: v ?? false))),
                    CheckboxListTile(value: draft.showScorpio, title: const Text('قمر در عقرب'), onChanged: (v) => update(draft.copyWith(showScorpio: v ?? false))),
                    CheckboxListTile(value: draft.showNextEvent, title: const Text('جلسه یا کار بعدی'), onChanged: (v) => update(draft.copyWith(showNextEvent: v ?? false))),
                  ])),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () async {
                  await _applyStatusNotification(draft);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('ذخیره و به‌روزرسانی'),
              )),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _applyStatusNotification(NotificationPreferences prefs) async {
    if (!prefs.enabled) {
      await _notifications.hideStatus();
      return;
    }
    final now = DateTime.now();
    final today = Jalali.now();
    final snap = _astronomy.snapshot(now);
    final occasions = _holidays.forDate(today);
    final upcoming = entries.where((e) => !e.completed && e.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final parts = <String>[];
    if (prefs.showDate) parts.add('${fa(today.day)} ${months[today.month - 1]} ${fa(today.year)}');
    if (prefs.showOccasion && occasions.isNotEmpty) parts.add(occasions.first);
    if (prefs.showMoonPhase) parts.add('ماه: ${snap.phaseName}');
    if (prefs.showScorpio) parts.add(snap.isMoonInScorpio ? 'قمر در عقرب: فعال' : 'قمر در عقرب: غیرفعال');
    if (prefs.showNextEvent && upcoming.isNotEmpty) {
      final next = upcoming.first;
      parts.add('بعدی: ${next.title} ${fa(DateFormat('HH:mm').format(next.start))}');
    }
    await _notifications.showStatus(title: 'ماه‌نگار', body: parts.isEmpty ? 'نمایش نوار اعلان فعال است' : parts.join(' • '));
  }

'''
        text = text.replace(method_anchor, methods + method_anchor)

    dashboard.write_text(text, encoding='utf-8')

# flutter create generates default PNG launcher resources. The release workflow
# writes the exact MahNegar master logo as WebP with the same resource name, so
# remove the generated defaults first to avoid duplicate Android resources.
for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
    launcher = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    if launcher.exists():
        launcher.unlink()
