from pathlib import Path

calendar = Path('lib/features/calendar/presentation/calendar_page.dart')
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

# flutter create generates default PNG launcher resources. The release workflow
# writes the exact MahNegar master logo as WebP with the same resource name, so
# remove the generated defaults first to avoid duplicate Android resources.
for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
    launcher = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    if launcher.exists():
        launcher.unlink()
