import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';
import '../widgets/common.dart';

class AddRelativeScreen extends StatefulWidget {
  final Relative? relative, relatedTo;
  final String? relationship;
  const AddRelativeScreen({
    super.key,
    this.relative,
    this.relatedTo,
    this.relationship,
  });
  @override
  State<AddRelativeScreen> createState() => _AddRelativeScreenState();
}

class _AddRelativeScreenState extends State<AddRelativeScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _nickname,
      _phone,
      _notes,
      _generation;
  late final String _id;
  FamilySide _side = FamilySide.direct;
  bool _discovered = true, _saving = false;
  DateTime? _birthDate;
  String? _father, _mother;
  List<String> _partners = [];
  @override
  void initState() {
    super.initState();
    final r = widget.relative, source = widget.relatedTo;
    _id = r?.id ?? const Uuid().v4();
    _name = TextEditingController(text: r?.givenName);
    _nickname = TextEditingController(text: r?.nickname);
    _phone = TextEditingController(text: r?.phoneNumber);
    _notes = TextEditingController(text: r?.notes);
    _side = r?.familySide ?? source?.familySide ?? FamilySide.direct;
    var gen = r?.generation ?? source?.generation ?? 0;
    if (r == null && source != null) {
      if (widget.relationship == 'child') gen--;
      if (widget.relationship == 'father' || widget.relationship == 'mother') {
        gen++;
      }
      if (widget.relationship == 'sibling') {
        _father = source.fatherId;
        _mother = source.motherId;
      }
      if (widget.relationship == 'partner') _partners = [source.id];
    }
    _generation = TextEditingController(text: '$gen');
    _father = r?.fatherId ?? _father;
    _mother = r?.motherId ?? _mother;
    _partners = r?.partnerIds.toList() ?? _partners;
    _discovered = r?.isDiscovered ?? true;
    _birthDate = r?.birthDate;
  }

  @override
  void dispose() {
    for (final c in [_name, _nickname, _phone, _notes, _generation]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final provider = context.read<RelativesProvider>();
    final duplicates = provider.relatives.where(
      (r) =>
          r.id != _id &&
          r.isDiscovered &&
          r.givenName.trim().toLowerCase() == _name.text.trim().toLowerCase(),
    );
    setState(() => _saving = true);
    try {
      if (duplicates.isNotEmpty &&
          !await confirmAction(
            context,
            title: 'A similar name exists',
            message: 'Someone with this full name is already in your family. Save this person anyway?',
            action: 'Save anyway',
          )) {
        return;
      }
      if (!mounted) return;
      final original = widget.relative;
      var person = Relative(
        id: _id,
        givenName: _name.text.trim(),
        nickname: _optional(_nickname.text),
        phoneNumber: _optional(_phone.text),
        notes: _optional(_notes.text),
        birthDate: _birthDate,
        familySide: _side,
        generation: int.parse(_generation.text),
        fatherId: _father,
        motherId: _mother,
        partnerIds: _partners,
        isDiscovered: _discovered,
        photoPath: original?.photoPath,
        dateDiscovered: _discovered
            ? original?.dateDiscovered ?? DateTime.now()
            : null,
      );
      if (widget.relationship == 'child' && widget.relatedTo != null) {
        // The user chooses the existing person's parental role below.
        if (_childRole == 'father') {
          person = person.copyWith(fatherId: widget.relatedTo!.id);
        } else {
          person = person.copyWith(motherId: widget.relatedTo!.id);
        }
      }
      await provider.saveRelative(
        person,
        linkTo: widget.relatedTo?.id,
        relationship: widget.relationship,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Relative saved')));
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _childRole = 'father';
  Future<void> _chooseParent(bool father) async {
    final gen = int.tryParse(_generation.text);
    if (gen == null) {
      showFailure(context, const FormatException('Enter a generation first.'));
      return;
    }
    final candidates = context
        .read<RelativesProvider>()
        .relatives
        .where(
          (r) =>
              r.id != _id &&
              r.generation > gen &&
              r.id != (father ? _mother : _father),
        )
        .toList();
    final person = await pickPerson(
      context,
      candidates,
      title: father ? 'Choose father' : 'Choose mother',
    );
    if (person != null && mounted) {
      setState(() {
        if (father) {
          _father = person.id;
        } else {
          _mother = person.id;
        }
      });
    }
  }

  Widget _parent(bool father) {
    final id = father ? _father : _mother;
    final person = id == null
        ? null
        : context.read<RelativesProvider>().byId(id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(father ? 'Father' : 'Mother'),
      subtitle: Text(person?.visibleName ?? 'Not connected'),
      onTap: () => _chooseParent(father),
      trailing: id == null
          ? const Icon(Icons.person_add_alt)
          : IconButton(
              tooltip: 'Disconnect ${father ? 'father' : 'mother'}',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                if (father) {
                  _father = null;
                } else {
                  _mother = null;
                }
              }),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.relative == null ? 'Add relative' : 'Edit relative',
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _form,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    if (widget.relatedTo != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Adding ${widget.relationship} for ${widget.relatedTo!.visibleName}',
                          ),
                        ),
                      ),
                    const SectionTitle(
                      'The person',
                      subtitle: 'Start with a name. Everything else can grow over time.',
                    ),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => v?.trim().isEmpty != false
                          ? 'Enter a full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: 'Nickname',
                        helperText: 'Used on the tree and in the directory',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Birthday'),
                      subtitle: Text(
                        _birthDate == null
                            ? 'Not set'
                            : DateFormat.yMMMd().format(_birthDate!),
                      ),
                      trailing: _birthDate == null
                          ? const Icon(Icons.calendar_month_outlined)
                          : IconButton(
                              tooltip: 'Clear birthday',
                              onPressed: () =>
                                  setState(() => _birthDate = null),
                              icon: const Icon(Icons.close),
                            ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime(2000),
                          firstDate: DateTime(1000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted) {
                          setState(() => _birthDate = date);
                        }
                      },
                    ),
                    const SectionTitle('Family connections'),
                    DropdownButtonFormField<FamilySide>(
                      initialValue: _side,
                      decoration: const InputDecoration(
                        labelText: 'Family side',
                      ),
                      items: FamilySide.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (s) => setState(() => _side = s!),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _generation,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Generation',
                        helperText: '0 = you / siblings, 1 = parents, 2 = grandparents, -1 = children',
                        helperMaxLines: 3,
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < -50 || n > 50
                            ? 'Enter a whole number from -50 to 50'
                            : null;
                      },
                    ),
                    if (widget.relationship == 'child')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: _childRole,
                          decoration: InputDecoration(
                            labelText:
                                '${widget.relatedTo!.visibleName} is their',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'father',
                              child: Text('Father'),
                            ),
                            DropdownMenuItem(
                              value: 'mother',
                              child: Text('Mother'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _childRole = v!),
                        ),
                      ),
                    if (widget.relationship != 'child' ||
                        _childRole != 'father')
                      _parent(true),
                    if (widget.relationship != 'child' ||
                        _childRole != 'mother')
                      _parent(false),
                    const Divider(),
                    for (final id in _partners)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          provider.byId(id)?.visibleName ?? 'Missing relative',
                        ),
                        subtitle: const Text('Partner'),
                        trailing: IconButton(
                          tooltip: 'Disconnect partner',
                          onPressed: () => setState(() => _partners.remove(id)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        final p = await pickPerson(
                          context,
                          provider.relatives
                              .where(
                                (r) => r.id != _id && !_partners.contains(r.id),
                              )
                              .toList(),
                          title: 'Choose partner',
                        );
                        if (p != null && mounted) {
                          setState(() => _partners.add(p.id));
                        }
                      },
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Connect partner'),
                    ),
                    const SectionTitle('Their story'),
                    TextFormField(
                      controller: _notes,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        alignLabelWithHint: true,
                        hintText: 'Memories, places, or things to remember…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Discovered'),
                      subtitle: const Text(
                        'Turn off to hide their identity in a shadow slot.',
                      ),
                      value: _discovered,
                      onChanged: (v) => setState(() => _discovered = v),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving || provider.isSaving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : 'Save relative'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
