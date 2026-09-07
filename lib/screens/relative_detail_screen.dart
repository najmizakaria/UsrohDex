import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';
import '../widgets/common.dart';
import 'add_relative_screen.dart';

class RelativeDetailScreen extends StatefulWidget {
  final String relativeId;
  const RelativeDetailScreen({super.key, required this.relativeId});
  @override
  State<RelativeDetailScreen> createState() => _RelativeDetailScreenState();
}

class _RelativeDetailScreenState extends State<RelativeDetailScreen> {
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

  Future<void> _photo(Relative r) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(c, 'gallery'),
            ),
            if (r.photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(c, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _run(() async {
      final provider = context.read<RelativesProvider>();
      if (source == 'remove') {
        await provider.setPhoto(r.id, null);
        return;
      }
      final image = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image != null) await provider.setPhoto(r.id, File(image.path));
    });
  }

  Future<void> _menu(String action, Relative r) async {
    final provider = context.read<RelativesProvider>();
    if (action == 'hide') {
      if (!await confirmAction(
            context,
            title: 'Mark as undiscovered?',
            message: 'Their details will stay saved, but their identity will be hidden until you discover them again.',
            action: 'Hide identity',
          ) ||
          !mounted) {
        return;
      }
      await _run(() => provider.setDiscovered(r.id, false));
    } else {
      final links = provider.childrenOf(r.id).length;
      if (!await confirmAction(
            context,
            title: 'Delete this relative?',
            message:
                'This permanently removes ${r.visibleName} and their photo. Parent links from $links children and all partner links will be disconnected. Other relatives will remain.',
            action: 'Delete relative',
          ) ||
          !mounted) {
        return;
      }
      await _run(() async {
        await provider.deleteRelative(r.id);
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _add(Relative r, String role) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddRelativeScreen(relatedTo: r, relationship: role),
    ),
  );
  Widget _relationship(String label, List<Relative> people) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(label),
      if (people.isEmpty) const Text('Not connected yet'),
      for (final p in people)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: PersonAvatar(relative: p),
              title: Text(p.visibleName),
              subtitle: Text(p.familySide.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RelativeDetailScreen(relativeId: p.id),
                ),
              ),
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    final r = provider.byId(widget.relativeId);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This relative no longer exists.')),
      );
    }
    final parents = [
      if (r.fatherId != null) provider.byId(r.fatherId!),
      if (r.motherId != null) provider.byId(r.motherId!),
    ].whereType<Relative>().toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family profile'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy && !provider.isSaving,
            onSelected: (v) => _menu(v, r),
            itemBuilder: (_) => [
              if (r.isDiscovered)
                const PopupMenuItem(
                  value: 'hide',
                  child: Text('Mark as undiscovered'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete relative'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (_busy) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Semantics(
                        label: r.isDiscovered
                            ? 'Change profile photo'
                            : 'Undiscovered relative',
                        button: r.isDiscovered,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(80),
                          onTap: r.isDiscovered && !_busy && !provider.isSaving
                              ? () => _photo(r)
                              : null,
                          child: PersonAvatar(relative: r, radius: 58),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        r.visibleName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (r.isDiscovered && r.displayName != r.givenName)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(r.givenName, textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          Chip(label: Text('${r.familySide.label} family')),
                          Chip(label: Text('Generation ${r.generation}')),
                        ],
                      ),
                      if (r.isDiscovered)
                        TextButton.icon(
                          onPressed: _busy || provider.isSaving
                              ? null
                              : () => _photo(r),
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 18,
                          ),
                          label: const Text('Change photo'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!r.isDiscovered) ...[
                const Text(
                  'A connection waiting to be discovered',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || provider.isSaving
                      ? null
                      : () => _run(() => provider.discover(r.id)),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Discover this relative'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _busy || provider.isSaving
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddRelativeScreen(relative: r),
                          ),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
                const SectionTitle('Personal details'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Birthday'),
                        subtitle: Text(
                          r.birthDate == null
                              ? 'Not added yet'
                              : DateFormat.yMMMMd().format(r.birthDate!),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: SelectableText(
                          r.phoneNumber?.isNotEmpty == true
                              ? r.phoneNumber!
                              : 'Not added yet',
                        ),
                      ),
                      if (r.dateDiscovered != null)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: const Text('Discovered'),
                          subtitle: Text(
                            DateFormat.yMMMd().format(r.dateDiscovered!),
                          ),
                        ),
                    ],
                  ),
                ),
                if (r.notes?.isNotEmpty == true) ...[
                  const SectionTitle('Their story'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(r.notes!),
                    ),
                  ),
                ],
                _relationship('Parents', parents),
                _relationship(
                  'Partners',
                  r.partnerIds
                      .map(provider.byId)
                      .whereType<Relative>()
                      .toList(),
                ),
                _relationship('Siblings', provider.siblingsOf(r)),
                _relationship('Children', provider.childrenOf(r.id)),
                const SectionTitle('Grow this family'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in [
                      if (r.fatherId == null) 'father',
                      if (r.motherId == null) 'mother',
                      'partner',
                      if (r.fatherId != null || r.motherId != null) 'sibling',
                      'child',
                    ])
                      OutlinedButton.icon(
                        onPressed: provider.isSaving
                            ? null
                            : () => _add(r, role),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Add $role'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
