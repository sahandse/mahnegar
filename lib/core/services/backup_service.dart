import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'local_store.dart';

class BackupService {
  BackupService({LocalStore? store}) : _store = store ?? LocalStore();

  final LocalStore _store;

  Future<bool> exportBackup() async {
    final raw = await _store.exportJson();
    final now = DateTime.now();
    final fileName =
        'mahnegar-backup-${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.json';
    final uri = await FilePicker.saveFile(
      dialogTitle: 'ذخیره نسخه پشتیبان ماه‌نگار',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(raw)),
    );
    return uri != null;
  }

  Future<List<CalendarEntry>?> importBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return _store.importJson(utf8.decode(bytes));
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
