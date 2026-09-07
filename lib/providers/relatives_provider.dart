import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/relative.dart';
import '../services/backup_service.dart';
import '../services/family_validation.dart';
import '../services/photo_storage.dart';

class RelativesProvider extends ChangeNotifier {
  final Future<List<Relative>> Function() _read;
  final Future<void> Function(List<Relative>) _write;
  final photos = PhotoStorage();
  List<Relative> _relatives = [];
  bool isLoading = true, isSaving = false;
  bool _disposed = false;
  String? error;
  RelativesProvider({
    Future<List<Relative>> Function()? read,
    Future<void> Function(List<Relative>)? write,
  }) : _read = read ?? DatabaseHelper.instance.getAllRelatives,
       _write = write ?? DatabaseHelper.instance.replaceAll {
    reload();
  }
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<Relative> get relatives => List.unmodifiable(_relatives);
  int get discoveredCount => _relatives.where((r) => r.isDiscovered).length;
  Future<void> reload() async {
    isLoading = true;
    error = null;
    _notify();
    try {
      _relatives = await _read();
    } catch (_) {
      error = 'Your family could not be loaded. Please try again.';
    }
    isLoading = false;
    _notify();
  }

  Relative? byId(String id) {
    for (final r in _relatives) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Relative> childrenOf(String id) =>
      _relatives.where((r) => r.fatherId == id || r.motherId == id).toList();
  List<Relative> siblingsOf(Relative r) => _relatives
      .where(
        (p) =>
            p.id != r.id &&
            ((r.fatherId != null && p.fatherId == r.fatherId) ||
                (r.motherId != null && p.motherId == r.motherId)),
      )
      .toList();
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (isSaving || isLoading) {
      throw const FormatException(
        'Please wait for the current operation to finish.',
      );
    }
    if (error != null) {
      throw const FormatException(
        'Reload your family successfully before making changes.',
      );
    }
    isSaving = true;
    _notify();
    try {
      return await action();
    } finally {
      isSaving = false;
      _notify();
    }
  }

  Future<void> _commit(List<Relative> next) async {
    validateFamily(next);
    await _write(next);
    _relatives = next;
    _notify();
  }

  Future<void> saveRelative(
    Relative person, {
    String? linkTo,
    String? relationship,
  }) => _exclusive(() async {
    final next = [..._relatives];
    final index = next.indexWhere((r) => r.id == person.id);
    if (index < 0) {
      next.add(person);
    } else {
      next[index] = person;
    }
    for (var i = 0; i < next.length; i++) {
      final r = next[i];
      if (r.id == person.id) continue;
      final partners = {...r.partnerIds}..remove(person.id);
      if (person.partnerIds.contains(r.id)) partners.add(person.id);
      next[i] = r.copyWith(partnerIds: partners.toList());
    }
    if (linkTo != null &&
        (relationship == 'father' || relationship == 'mother')) {
      final i = next.indexWhere((r) => r.id == linkTo);
      if (i < 0) {
        throw const FormatException('The related person no longer exists.');
      }
      next[i] = relationship == 'father'
          ? next[i].copyWith(fatherId: person.id)
          : next[i].copyWith(motherId: person.id);
    }
    await _commit(next);
  });
  Future<void> updateRelative(Relative relative) async {
    if (byId(relative.id) == null) {
      throw const FormatException('This relative no longer exists.');
    }
    await saveRelative(relative);
  }

  Future<void> addRelative({
    required String givenName,
    required FamilySide familySide,
    required int generation,
    String? nickname,
    String? fatherId,
    String? motherId,
    bool discovered = false,
  }) => saveRelative(
    Relative(
      id: const Uuid().v4(),
      givenName: givenName,
      familySide: familySide,
      generation: generation,
      nickname: nickname,
      fatherId: fatherId,
      motherId: motherId,
      isDiscovered: discovered,
      dateDiscovered: discovered ? DateTime.now() : null,
    ),
  );
  Future<void> discover(String id) => setDiscovered(id, true);
  Future<void> setDiscovered(String id, bool value) async {
    final r = byId(id);
    if (r == null) return;
    await updateRelative(
      r.copyWith(
        isDiscovered: value,
        dateDiscovered: value ? DateTime.now() : null,
      ),
    );
  }

  Future<void> deleteRelative(String id) => _exclusive(() async {
    final old = byId(id);
    await _commit(
      _relatives
          .where((r) => r.id != id)
          .map(
            (r) => r.copyWith(
              clearFatherId: r.fatherId == id,
              clearMotherId: r.motherId == id,
              partnerIds: r.partnerIds.where((p) => p != id).toList(),
            ),
          )
          .toList(),
    );
    await photos.remove(old?.photoPath);
  });
  Future<void> setPhoto(String id, File? file) => _exclusive(() async {
    final r = byId(id);
    if (r == null) {
      throw const FormatException('This relative no longer exists.');
    }
    final path = file == null ? null : await photos.save(file);
    try {
      await _commit(
        _relatives
            .map((p) => p.id == id ? p.copyWith(photoPath: path) : p)
            .toList(),
      );
    } catch (_) {
      await photos.remove(path);
      rethrow;
    }
    await photos.remove(r.photoPath);
  });
  Future<String> restore(BackupPreview preview) => _exclusive(() async {
    final safety = await BackupService().export(_relatives, safety: true);
    final created = <String>[];
    final old = [..._relatives];
    try {
      final next = <Relative>[];
      for (final r in preview.relatives) {
        final bytes = preview.photos[r.id];
        final path = bytes == null ? null : await photos.saveBytes(bytes);
        if (path != null) created.add(path);
        next.add(r.copyWith(photoPath: path));
      }
      await _commit(next);
    } catch (_) {
      for (final path in created) {
        await photos.remove(path);
      }
      rethrow;
    }
    for (final r in old) {
      await photos.remove(r.photoPath);
    }
    return safety.path;
  });
}
