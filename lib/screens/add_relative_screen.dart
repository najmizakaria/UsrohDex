import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';

class AddRelativeScreen extends StatefulWidget {
  const AddRelativeScreen({super.key});

  @override
  State<AddRelativeScreen> createState() => _AddRelativeScreenState();
}

class _AddRelativeScreenState extends State<AddRelativeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();

  FamilySide _familySide = FamilySide.direct;
  int _generation = 0;
  String? _fatherId;
  String? _motherId;
  bool _markDiscovered = true;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    final possibleParents =
        provider.relatives.where((r) => r.generation > _generation).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add relative')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'e.g. Ahmad bin Ismail',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname (optional)',
                hintText: 'e.g. Ayah — shown on the tree canvas instead of the full name',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FamilySide>(
              initialValue: _familySide,
              decoration: const InputDecoration(labelText: 'Family side'),
              items: FamilySide.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _familySide = v ?? FamilySide.direct),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _generation,
              decoration: const InputDecoration(
                labelText: 'Generation',
                helperText: '2 = Grandparents, 1 = Parents, 0 = You, -1 = Children',
              ),
              items: const [
                DropdownMenuItem(value: 2, child: Text('2 — Grandparents')),
                DropdownMenuItem(value: 1, child: Text('1 — Parents')),
                DropdownMenuItem(value: 0, child: Text('0 — You / Siblings')),
                DropdownMenuItem(value: -1, child: Text('-1 — Children')),
              ],
              onChanged: (v) => setState(() {
                _generation = v ?? 0;
                _fatherId = null;
                _motherId = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _fatherId,
              decoration: const InputDecoration(labelText: 'Father (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— none —')),
                ...possibleParents.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.givenName)),
                ),
              ],
              onChanged: (v) => setState(() => _fatherId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _motherId,
              decoration: const InputDecoration(labelText: 'Mother (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— none —')),
                ...possibleParents.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.givenName)),
                ),
              ],
              onChanged: (v) => setState(() => _motherId = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Already discovered'),
              subtitle: const Text('Off = starts as a locked shadow slot'),
              value: _markDiscovered,
              onChanged: (v) => setState(() => _markDiscovered = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save relative'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<RelativesProvider>().addRelative(
          givenName: _nameController.text.trim(),
          nickname: _nicknameController.text.trim().isEmpty
              ? null
              : _nicknameController.text.trim(),
          familySide: _familySide,
          generation: _generation,
          fatherId: _fatherId,
          motherId: _motherId,
          discovered: _markDiscovered,
        );
    if (mounted) Navigator.of(context).pop();
  }
}