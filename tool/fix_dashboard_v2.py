from pathlib import Path

path = Path('lib/features/home/mahnegar_dashboard_v2.dart')
text = path.read_text(encoding='utf-8')

text = text.replace("              onLongPress: _showQuickAdd,\n", "")

old = """      final ids = await showDialog<List<String>>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('تقویم‌های Google'), content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: calendars.map((Calendar c) => CheckboxListTile(value: selected.contains(c.id), title: Text(c.name), subtitle: Text(c.accountName ?? ''), onChanged: (v) => setDialog(() { if (v == true) { selected.add(c.id); } else { selected.remove(c.id); } }))).toList())), actions: [FilledButton(onPressed: () => Navigator.pop(dialog, selected.toList()), child: const Text('همگام‌سازی'))]))));
"""

new = """      final ids = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('تقویم‌های Google'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: calendars
                    .map(
                      (Calendar c) => CheckboxListTile(
                        value: selected.contains(c.id),
                        title: Text(c.name),
                        subtitle: Text(c.accountName ?? ''),
                        onChanged: (value) => setDialog(() {
                          if (value == true) {
                            selected.add(c.id);
                          } else {
                            selected.remove(c.id);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected.toList()),
                child: const Text('همگام‌سازی'),
              ),
            ],
          ),
        ),
      );
"""

if old not in text:
    raise SystemExit('Expected Google Calendar dialog source was not found')

text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
print('mahnegar_dashboard_v2.dart patched successfully')
