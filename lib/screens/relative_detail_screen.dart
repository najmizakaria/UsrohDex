import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';

class RelativeDetailScreen extends StatefulWidget {
  final String relativeId;
  const RelativeDetailScreen({super.key, required this.relativeId});

  @override
  State<RelativeDetailScreen> createState() => _RelativeDetailScreenState();
}

class _RelativeDetailScreenState extends State<RelativeDetailScreen> {
  final _picker = ImagePicker();
  final _dateFmt = DateFormat.yMMMd();

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;

    final provider = context.read<RelativesProvider>();
    final relative = provider.byId(widget.relativeId);
    if (relative == null) return;

    final savedPath = await provider.savePhotoForRelative(relative.id, File(picked.path));
    await provider.updateRelative(relative.copyWith(photoPath: savedPath));
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Relative relative) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete relative?'),
        content: Text('This removes ${relative.givenName} and their photo permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<RelativesProvider>().deleteRelative(relative.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _editDialog(Relative relative, List<Relative> possibleParents) {
    final nameController = TextEditingController(text: relative.givenName);
    final nicknameController = TextEditingController(text: relative.nickname ?? '');
    final phoneController = TextEditingController(text: relative.phoneNumber ?? '');
    DateTime? birthDate = relative.birthDate;
    String? fatherId = relative.fatherId;
    String? motherId = relative.motherId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Nickname (optional)',
                    helperText: 'Shown on the tree canvas instead of the full name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(birthDate == null ? 'No birth date set' : _dateFmt.format(birthDate!)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: birthDate ?? DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => birthDate = picked);
                        }
                      },
                      child: const Text('Pick date'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: fatherId,
                  decoration: const InputDecoration(labelText: 'Father'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    ...possibleParents.map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.givenName)),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => fatherId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: motherId,
                  decoration: const InputDecoration(labelText: 'Mother'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    ...possibleParents.map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.givenName)),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => motherId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await context.read<RelativesProvider>().updateRelative(
                      relative.copyWith(
                        givenName: nameController.text.trim().isEmpty
                            ? relative.givenName
                            : nameController.text.trim(),
                        nickname: nicknameController.text.trim(),
                        clearNickname: nicknameController.text.trim().isEmpty,
                        phoneNumber: phoneController.text.trim(),
                        birthDate: birthDate,
                        fatherId: fatherId,
                        motherId: motherId,
                        clearFatherId: fatherId == null,
                        clearMotherId: motherId == null,
                      ),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    final relative = provider.byId(widget.relativeId);

    if (relative == null) {
      return const Scaffold(body: Center(child: Text('This relative no longer exists.')));
    }

    final father = relative.fatherId != null ? provider.byId(relative.fatherId!) : null;
    final mother = relative.motherId != null ? provider.byId(relative.motherId!) : null;
    final children = provider.childrenOf(relative.id);
    final hasPhoto = relative.photoPath != null && File(relative.photoPath!).existsSync();
    // Anyone in an older generation can be picked as a parent (same rule as Add screen).
    final possibleParents =
        provider.relatives.where((r) => r.generation > relative.generation && r.id != relative.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(relative.isDiscovered ? relative.displayName : 'Shadow Slot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(relative),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: relative.isDiscovered ? _showPhotoSourceSheet : null,
              child: CircleAvatar(
                radius: 64,
                backgroundColor: relative.isDiscovered ? Colors.grey.shade200 : Colors.black87,
                backgroundImage: hasPhoto ? FileImage(File(relative.photoPath!)) : null,
                child: !hasPhoto
                    ? Icon(
                        relative.isDiscovered ? Icons.camera_alt : Icons.help_outline,
                        color: Colors.white70,
                        size: 32,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!relative.isDiscovered)
            FilledButton.icon(
              onPressed: () => context.read<RelativesProvider>().discover(relative.id),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Discover this relative'),
            )
          else ...[
            // Full name is only ever shown here in the detail view.
            _InfoRow(label: 'Full name', value: relative.givenName),
            if (relative.nickname != null && relative.nickname!.isNotEmpty)
              _InfoRow(label: 'Nickname', value: relative.nickname!),
            _InfoRow(label: 'Family side', value: relative.familySide.label),
            _InfoRow(label: 'Generation', value: relative.generation.toString()),
            if (relative.birthDate != null)
              _InfoRow(label: 'Birth date', value: _dateFmt.format(relative.birthDate!)),
            if (relative.phoneNumber != null && relative.phoneNumber!.isNotEmpty)
              _InfoRow(label: 'Phone', value: relative.phoneNumber!),
            _InfoRow(label: 'Father', value: father?.givenName ?? '—'),
            _InfoRow(label: 'Mother', value: mother?.givenName ?? '—'),
            if (children.isNotEmpty)
              _InfoRow(
                label: 'Children',
                value: children.map((c) => c.isDiscovered ? c.givenName : '???').join(', '),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _editDialog(relative, possibleParents),
              icon: const Icon(Icons.edit),
              label: const Text('Edit details'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}