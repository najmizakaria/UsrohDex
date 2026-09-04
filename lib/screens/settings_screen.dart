import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportBackup(BuildContext context) async {
    final path = await DatabaseHelper.instance.getDatabaseFilePath();
    final file = File(path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data yet — add a relative first.')),
        );
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'UsrohDex backup — keep this file safe.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'UsrohDex stores everything only on this device. There is no account, '
            'no server, and no automatic sync. Export a backup regularly so you '
            'never lose your tree if you switch phones.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _exportBackup(context),
            icon: const Icon(Icons.ios_share),
            label: const Text('Export backup'),
          ),
        ],
      ),
    );
  }
}