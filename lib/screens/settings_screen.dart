import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_preferences.dart';
import '../providers/relatives_provider.dart';
import '../services/backup_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    final provider = context.read<RelativesProvider>();
    final prefs = context.read<AppPreferences>();
    final file = await BackupService().export(provider.relatives);
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: 'UsrohDex family backup',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (!mounted || result.status == ShareResultStatus.dismissed) return;
    if (await confirmAction(
      context,
      title: 'Was your backup saved?',
      message: 'Confirm once the backup is saved somewhere outside this app, such as Files or your own storage.',
      action: 'Yes, saved',
    )) {
      await prefs.save(exported: DateTime.now());
    }
  });
  Future<void> _restoreFile(XFile file) async {
    if (await file.length() > BackupService.maxBytes) {
      throw const FormatException('Backup exceeds 100 MB.');
    }
    final preview = BackupService().decode(await file.readAsBytes());
    if (!mounted) return;
    final provider = context.read<RelativesProvider>();
    final approved = await confirmAction(
      context,
      title: 'Restore this family?',
      message:
          'Backup from ${DateFormat.yMMMd().add_jm().format(preview.created.toLocal())}\n\n${preview.relatives.length} relatives · ${preview.photos.length} photos\n\nThis replaces your current ${provider.relatives.length} relatives. A safety backup of your current family will be saved on this device first.',
      action: 'Replace and restore',
    );
    if (!approved || !mounted) return;
    await provider.restore(preview);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Family restored. Your previous family is in Safety backups.',
          ),
        ),
      );
    }
  }

  Future<void> _import() => _run(() async {
    final file = await openFile(confirmButtonText: 'Preview backup');
    if (file != null) await _restoreFile(file);
  });
  Future<void> _safetyBackups() => _run(() async {
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/backups',
    );
    final files = await directory.exists()
        ? await directory
              .list()
              .where((f) => f is File && f.path.endsWith('.usrohdex'))
              .cast<File>()
              .toList()
        : <File>[];
    files.sort((a, b) => b.path.compareTo(a.path));
    if (!mounted) return;
    final chosen = await showModalBottomSheet<File>(
      context: context,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Safety backups', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Saved automatically before each restore. These remain on this device.',
            ),
            const SizedBox(height: 12),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No restores yet.'),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in files)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        DateFormat.yMMMd().add_jm().format(
                          f.lastModifiedSync(),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(c, f),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) await _restoreFile(XFile(chosen.path));
  });
  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>(),
        provider = context.watch<RelativesProvider>();
    final ready =
        !_busy &&
        !provider.isLoading &&
        !provider.isSaving &&
        provider.error == null;
    final due =
        prefs.backupReminders &&
        provider.relatives.isNotEmpty &&
        (prefs.lastExport == null ||
            DateTime.now().difference(prefs.lastExport!).inDays >= 30);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              if (_busy) const LinearProgressIndicator(),
              const SectionTitle(
                'Your family. Your device.',
                subtitle: 'No account, no server, no automatic sync.',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Your family details and photos stay here. Export a backup to keep a copy when changing phones.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Backup & recovery'),
              if (due)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.backup_outlined),
                    title: Text('Time for a family backup'),
                    subtitle: Text(
                      'Save a copy of your latest connections and photos.',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                prefs.lastExport == null
                    ? 'No confirmed export yet'
                    : 'Last confirmed export: ${DateFormat.yMMMd().add_jm().format(prefs.lastExport!)}',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: ready ? _export : null,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export family & photos'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: ready ? _import : null,
                icon: const Icon(Icons.restore),
                label: const Text('Restore from backup'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: const Text('Safety backups'),
                subtitle: const Text(
                  'Recover your family from before a restore',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: ready ? _safetyBackups : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Backup reminders'),
                subtitle: const Text('Show a reminder here after 30 days'),
                value: prefs.backupReminders,
                onChanged: (v) => prefs.save(reminders: v),
              ),
              const Text(
                'Backups include personal information and photos. Keep them in a place you trust. Legacy database-only exports are not supported by this restore flow.',
              ),
              const SectionTitle('Appearance'),
              Card(
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      ListTile(
                        leading: Icon(switch (mode) {
                          ThemeMode.system => Icons.brightness_auto_outlined,
                          ThemeMode.light => Icons.light_mode_outlined,
                          ThemeMode.dark => Icons.dark_mode_outlined,
                        }),
                        title: Text(switch (mode) {
                          ThemeMode.system => 'Use device setting',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                        trailing: prefs.themeMode == mode
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => prefs.save(theme: mode),
                      ),
                  ],
                ),
              ),
              if (prefs.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(prefs.error!),
                ),
              const SectionTitle('About UsrohDex'),
              const Text(
                'A place for your family story to grow.\nBuilt around people, connections, and discovery.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
