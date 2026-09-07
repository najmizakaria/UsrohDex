import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:usrohdex/data/database_helper.dart';
import 'package:usrohdex/models/relative.dart';
import 'package:usrohdex/providers/relatives_provider.dart';
import 'package:usrohdex/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('usrohdex-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => sandbox.path,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await sandbox.delete(recursive: true);
  });
  const relative = Relative(
    id: 'a',
    givenName: 'Existing person',
    isDiscovered: true,
    familySide: FamilySide.direct,
    generation: 0,
  );
  for (final version in [1, 2]) {
    test('database version $version migrates without losing relatives', () async {
      final path = '${sandbox.path}/family.db';
      final old = await openDatabase(
        path,
        version: version,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE relatives (id TEXT PRIMARY KEY, givenName TEXT NOT NULL, ${version == 2 ? 'nickname TEXT,' : ''} isDiscovered INTEGER NOT NULL, dateDiscovered INTEGER, photoPath TEXT, phoneNumber TEXT, birthDate INTEGER, fatherId TEXT, motherId TEXT, familySide TEXT NOT NULL, generation INTEGER NOT NULL)',
          );
        },
      );
      final map = relative.toMap()
        ..remove('notes')
        ..remove('partnerIds');
      if (version == 1) map.remove('nickname');
      await old.insert('relatives', map);
      await old.close();
      final helper = DatabaseHelper.forTesting(path);
      final people = await helper.getAllRelatives();
      expect(people.single.givenName, 'Existing person');
      expect(people.single.partnerIds, isEmpty);
      await helper.replaceAll([
        people.single.copyWith(notes: 'Preserved memory'),
      ]);
      expect((await helper.getAllRelatives()).single.notes, 'Preserved memory');
      await (await helper.database).close();
    });
  }
  test(
    'transaction rollback preserves original records on failed replacement',
    () async {
      final helper = DatabaseHelper.forTesting('${sandbox.path}/family.db');
      await helper.replaceAll([relative]);
      await expectLater(
        helper.replaceAll([relative, relative]),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await helper.getAllRelatives()).single.givenName,
        relative.givenName,
      );
      await (await helper.database).close();
    },
  );
  test(
    'complete backup restores photos and creates a recoverable safety backup',
    () async {
      final photo = await File('${sandbox.path}/original.png').writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0xQAAAAASUVORK5CYII=',
        ),
      );
      final service = BackupService();
      final exported = await service.export([
        relative.copyWith(photoPath: photo.path),
      ]);
      final preview = service.decode(await exported.readAsBytes());
      expect(preview.photos.length, 1);
      expect(preview.relatives.single.photoPath, isNull);
      var persisted = [relative.copyWith(givenName: 'Before restore')];
      final provider = RelativesProvider(
        read: () async => persisted,
        write: (next) async => persisted = next,
      );
      await Future<void>.delayed(Duration.zero);
      final safetyPath = await provider.restore(preview);
      expect(provider.relatives.single.givenName, 'Existing person');
      expect(
        await File(provider.relatives.single.photoPath!).readAsBytes(),
        await photo.readAsBytes(),
      );
      expect(
        service
            .decode(await File(safetyPath).readAsBytes())
            .relatives
            .single
            .givenName,
        'Before restore',
      );
      provider.dispose();
    },
  );
  test(
    'failed restore leaves current family intact and cleans staged photos',
    () async {
      final service = BackupService();
      final photo = await File('${sandbox.path}/original.png')
          .writeAsBytes([1, 2, 3]);
      final file = await service.export([
        relative.copyWith(photoPath: photo.path),
      ]);
      final preview = service.decode(await file.readAsBytes());
      final provider = RelativesProvider(
        read: () async => [relative.copyWith(givenName: 'Keep me')],
        write: (_) async => throw StateError('disk full'),
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(provider.restore(preview), throwsStateError);
      expect(provider.relatives.single.givenName, 'Keep me');
      expect(await (await provider.photos.directory).list().toList(), isEmpty);
      provider.dispose();
    },
  );
}
