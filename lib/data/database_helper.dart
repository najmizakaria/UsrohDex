import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/relative.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'usrohdex.db';
  static const _dbVersion = 2;
  static const table = 'relatives';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id TEXT PRIMARY KEY,
            givenName TEXT NOT NULL,
            nickname TEXT,
            isDiscovered INTEGER NOT NULL DEFAULT 0,
            dateDiscovered INTEGER,
            photoPath TEXT,
            phoneNumber TEXT,
            birthDate INTEGER,
            fatherId TEXT,
            motherId TEXT,
            familySide TEXT NOT NULL,
            generation INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $table ADD COLUMN nickname TEXT');
        }
      },
    );
  }

  Future<void> insertRelative(Relative relative) async {
    final db = await database;
    await db.insert(table, relative.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Relative>> getAllRelatives() async {
    final db = await database;
    final rows = await db.query(table);
    return rows.map(Relative.fromMap).toList();
  }

  Future<void> deleteRelative(String id) async {
    final db = await database;
    await db.update(table, {'fatherId': null}, where: 'fatherId = ?', whereArgs: [id]);
    await db.update(table, {'motherId': null}, where: 'motherId = ?', whereArgs: [id]);
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, _dbName);
  }
}