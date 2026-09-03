import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/relative.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'usrohdex.db';
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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id TEXT PRIMARY KEY,
            givenName TEXT NOT NULL,
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
}