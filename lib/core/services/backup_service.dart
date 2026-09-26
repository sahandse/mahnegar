import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:public_file_saver/public_file_saver.dart';

import 'local_store.dart';

class BackupService {
  BackupService({LocalStore? store}) : _store = store ?? LocalStore();

  final LocalStore _store;
  final PublicFileSaver _saver = PublicFileSaver();

  Future<bool> exportBackup() async {
    final raw = await _store.exportJson();
    final now = DateTime.now();
    final fileName =
        'mahnegar-backup-${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.json';
    final result = await _saver.saveBytesWithDialog(
      bytes: Uint8List.fromList(utf8.encode(raw)),
      fileName: fileName,
      mimeType: 'application/json',
    );
    return result?.isSuccess == true;
  }

  Future<List<CalendarEntry>?> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('Backup file could not be read');
    }
    return _store.importJson(utf8.decode(bytes));
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
