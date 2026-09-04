import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/relative.dart';

class RelativesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<Relative> _relatives = [];
  bool _isLoading = true;

  List<Relative> get relatives => List.unmodifiable(_relatives);
  bool get isLoading => _isLoading;

  RelativesProvider() {
    _load();
  }

  Future<void> _load() async {
    _relatives = await _db.getAllRelatives();
    _isLoading = false;
    notifyListeners();
  }

  Relative? byId(String id) {
    try {
      return _relatives.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Relative> childrenOf(String parentId) {
    return _relatives.where((r) => r.fatherId == parentId || r.motherId == parentId).toList();
  }

  Future<void> addRelative({
    required String givenName,
    required FamilySide familySide,
    required int generation,
    String? fatherId,
    String? motherId,
    bool discovered = false,
  }) async {
    final relative = Relative(
      id: _uuid.v4(),
      givenName: givenName,
      isDiscovered: discovered,
      dateDiscovered: discovered ? DateTime.now() : null,
      familySide: familySide,
      generation: generation,
      fatherId: fatherId,
      motherId: motherId,
    );
    await _db.insertRelative(relative);
    _relatives.add(relative);
    notifyListeners();
  }

  Future<void> updateRelative(Relative updated) async {
    await _db.insertRelative(updated);
    final index = _relatives.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _relatives[index] = updated;
      notifyListeners();
    }
  }

  Future<void> discover(String id) async {
    final current = byId(id);
    if (current == null || current.isDiscovered) return;
    await updateRelative(current.copyWith(isDiscovered: true, dateDiscovered: DateTime.now()));
  }

  Future<void> deleteRelative(String id) async {
    final target = byId(id);
    if (target?.photoPath != null) {
      final file = File(target!.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.deleteRelative(id);
    _relatives.removeWhere((r) => r.id == id);
    _relatives = _relatives
        .map((r) => r.copyWith(
              clearFatherId: r.fatherId == id,
              clearMotherId: r.motherId == id,
            ))
        .toList();
    notifyListeners();
  }

  Future<String> savePhotoForRelative(String relativeId, File pickedFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/usrohdex_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final ext = pickedFile.path.contains('.') ? pickedFile.path.split('.').last : 'jpg';
    final destPath = '${photosDir.path}/$relativeId.$ext';
    final saved = await pickedFile.copy(destPath);
    return saved.path;
  }
}