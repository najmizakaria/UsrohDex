import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/relative.dart';

class DatabaseHelper {
  DatabaseHelper._internal() : pathOverride = null;
  DatabaseHelper.forTesting(this.pathOverride);
  final String? pathOverride;
  static final instance = DatabaseHelper._internal();
  static const table = 'relatives';
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await openDatabase(
        pathOverride ?? p.join(await getDatabasesPath(), 'usrohdex.db'),
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE relatives (id TEXT PRIMARY KEY, givenName TEXT NOT NULL, nickname TEXT, isDiscovered INTEGER NOT NULL DEFAULT 0, dateDiscovered INTEGER, photoPath TEXT, phoneNumber TEXT, birthDate INTEGER, fatherId TEXT, motherId TEXT, familySide TEXT NOT NULL, generation INTEGER NOT NULL, notes TEXT, partnerIds TEXT NOT NULL DEFAULT \'[]\')',
          );
        },
        onUpgrade: (db, old, _) async {
          if (old < 2) {
            await db.execute('ALTER TABLE relatives ADD COLUMN nickname TEXT');
          }
          if (old < 3) {
            await db.execute('ALTER TABLE relatives ADD COLUMN notes TEXT');
            await db.execute(
              'ALTER TABLE relatives ADD COLUMN partnerIds TEXT NOT NULL DEFAULT \'[]\'',
            );
          }
        },
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<List<Relative>> getAllRelatives() async =>
      (await (await database).query(table)).map(Relative.fromMap).toList();

  /// All relationship changes are committed together, including reciprocal partners.
  Future<void> replaceAll(List<Relative> people) async {
    await (await database).transaction((txn) async {
      await txn.delete(table);
      final batch = txn.batch();
      for (final r in people) {
        batch.insert(table, r.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
