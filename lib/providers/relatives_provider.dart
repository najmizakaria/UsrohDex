import 'package:flutter/foundation.dart';
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
}