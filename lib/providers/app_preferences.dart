import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppPreferences extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  DateTime? lastExport;
  bool backupReminders = true;
  String? error;
  bool _disposed = false;
  Future<void> _pending = Future.value();
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/preferences.json',
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString()) as Map;
        themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == data['theme'],
          orElse: () => ThemeMode.system,
        );
        lastExport = DateTime.tryParse(data['lastExport'] as String? ?? '');
        backupReminders = data['reminders'] != false;
      }
    } catch (_) {
      error = 'Preferences could not be loaded. Default settings are active.';
    }
    _notify();
  }

  Future<void> save({ThemeMode? theme, bool? reminders, DateTime? exported}) {
    themeMode = theme ?? themeMode;
    backupReminders = reminders ?? backupReminders;
    lastExport = exported ?? lastExport;
    final content = jsonEncode({
      'theme': themeMode.name,
      'reminders': backupReminders,
      'lastExport': lastExport?.toIso8601String(),
    });
    _notify();
    _pending = _pending.then((_) async {
      try {
        final file = await _file;
        final staging = File('${file.path}.tmp');
        await staging.writeAsString(content, flush: true);
        await staging.rename(file.path);
        error = null;
      } catch (_) {
        error = 'Your preference could not be saved. Please try again.';
      }
      _notify();
    });
    return _pending;
  }
}
