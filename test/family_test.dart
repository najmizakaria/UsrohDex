import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:usrohdex/models/relative.dart';
import 'package:usrohdex/providers/relatives_provider.dart';
import 'package:usrohdex/services/backup_service.dart';
import 'package:usrohdex/services/family_validation.dart';
import 'package:usrohdex/utils/tree_layout.dart';

Relative person(
  String id, {
  int gen = 0,
  String? father,
  String? mother,
  List<String> partners = const [],
}) => Relative(
  id: id,
  givenName: id,
  isDiscovered: true,
  familySide: FamilySide.direct,
  generation: gen,
  fatherId: father,
  motherId: mother,
  partnerIds: partners,
);
void main() {
  test('nullable profile fields clear and new data round-trips', () {
    final r = person('a').copyWith(
      notes: 'A memory',
      nickname: 'Nickname',
      birthDate: DateTime(1990),
      phoneNumber: '123',
      photoPath: 'photo.jpg',
    );
    expect(Relative.fromMap(r.toMap()).toMap(), r.toMap());
    final cleared = r.copyWith(
      notes: null,
      nickname: null,
      birthDate: null,
      phoneNumber: null,
      photoPath: null,
    );
    expect([
      cleared.notes,
      cleared.nickname,
      cleared.birthDate,
      cleared.phoneNumber,
      cleared.photoPath,
    ], everyElement(isNull));
  });
  test('legacy rows without partners and notes still load', () {
    final map = person('legacy').toMap()
      ..remove('notes')
      ..remove('partnerIds');
    expect(Relative.fromMap(map).partnerIds, isEmpty);
  });
  test('relationship validation rejects invalid parent configurations', () {
    expect(
      () => validateFamily([person('a', father: 'a')]),
      throwsFormatException,
    );
    expect(
      () => validateFamily([person('a', father: 'missing')]),
      throwsFormatException,
    );
    expect(
      () => validateFamily([
        person('p', gen: 1),
        person('c', father: 'p', mother: 'p'),
      ]),
      throwsFormatException,
    );
    expect(
      () => validateFamily([person('p'), person('c', father: 'p')]),
      throwsFormatException,
    );
    expect(
      () => validateFamily([
        person('a', gen: 1, father: 'b'),
        person('b', father: 'a'),
      ]),
      throwsFormatException,
    );
    expect(
      () => validateFamily([person('p', gen: 3), person('c', father: 'p')]),
      returnsNormally,
    );
  });
  test(
    'partner links must reference different existing people and be mutual',
    () {
      expect(
        () => validateFamily([
          person('a', partners: ['a']),
        ]),
        throwsFormatException,
      );
      expect(
        () => validateFamily([
          person('a', partners: ['b']),
          person('b'),
        ]),
        throwsFormatException,
      );
      expect(
        () => validateFamily([
          person('a', partners: ['b']),
          person('b', partners: ['a']),
        ]),
        returnsNormally,
      );
    },
  );
  test(
    'provider saves reciprocal partners and disconnects deletions atomically',
    () async {
      var stored = [person('a'), person('b')];
      var writes = 0;
      final provider = RelativesProvider(
        read: () async => stored,
        write: (next) async {
          stored = next;
          writes++;
        },
      );
      await Future<void>.delayed(Duration.zero);
      await provider.updateRelative(stored.first.copyWith(partnerIds: ['b']));
      expect(provider.byId('b')!.partnerIds, ['a']);
      expect(writes, 1);
      await provider.deleteRelative('a');
      expect(provider.byId('b')!.partnerIds, isEmpty);
      expect(writes, 2);
      provider.dispose();
    },
  );
  test('failed persistence does not change in-memory family', () async {
    final provider = RelativesProvider(
      read: () async => [person('a')],
      write: (_) async => throw StateError('disk full'),
    );
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      provider.updateRelative(person('a').copyWith(givenName: 'Changed')),
      throwsStateError,
    );
    expect(provider.byId('a')!.givenName, 'a');
    expect(provider.isSaving, isFalse);
    provider.dispose();
  });
  test('load failures can be retried and do not permit writes', () async {
    var fail = true;
    final provider = RelativesProvider(
      read: () async {
        if (fail) throw StateError('locked');
        return [person('a')];
      },
      write: (_) async {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.error, isNotNull);
    await expectLater(
      provider.saveRelative(person('b')),
      throwsFormatException,
    );
    fail = false;
    await provider.reload();
    expect(provider.error, isNull);
    expect(provider.relatives, hasLength(1));
    provider.dispose();
  });
  test('adding a parent connects the source child in the same write', () async {
    var writes = 0;
    final provider = RelativesProvider(
      read: () async => [person('child')],
      write: (_) async {
        writes++;
      },
    );
    await Future<void>.delayed(Duration.zero);
    await provider.saveRelative(
      person('parent', gen: 1),
      linkTo: 'child',
      relationship: 'father',
    );
    expect(provider.byId('child')!.fatherId, 'parent');
    expect(writes, 1);
    provider.dispose();
  });
  test('backup validates version, relations, and rejects unrelated photos', () {
    final service = BackupService();
    Map<String, Object?> data() => {
      'format': 'usrohdex',
      'version': 1,
      'created': '2026-01-01T00:00:00Z',
      'relatives': [person('a').toMap()],
      'photos': <String, String>{},
    };
    List<int> encode(Map<String, Object?> d) => utf8.encode(jsonEncode(d));
    expect(service.decode(encode(data())).relatives.single.id, 'a');
    expect(
      () => service.decode(encode(data()..['version'] = 99)),
      throwsFormatException,
    );
    expect(
      () => service.decode(
        encode(
          data()
            ..['photos'] = {
              'missing': base64Encode([1, 2, 3]),
            },
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => service.decode(
        encode(
          data()..['relatives'] = [person('a', father: 'missing').toMap()],
        ),
      ),
      throwsFormatException,
    );
    expect(() => service.decode([1, 2, 3]), throwsFormatException);
  });
  test('layout handles generations beyond original range without clipped or overlapping nodes', () {
    final relatives = [
      person('ancestor', gen: 8),
      for (var i = 0; i < 20; i++)
        person('child$i', gen: 7, father: 'ancestor'),
      person('descendant', gen: -5),
    ];
    final layout = TreeLayout.compute(relatives);
    for (final a in relatives) {
      final p = layout.positionOf(a.id)!;
      expect(p.dx, greaterThanOrEqualTo(TreeLayout.nodeSize / 2));
      expect(p.dy, greaterThanOrEqualTo(TreeLayout.nodeSize / 2));
      expect(p.dx + TreeLayout.nodeSize / 2, lessThan(layout.canvasWidth));
      expect(p.dy + TreeLayout.nodeSize / 2, lessThan(layout.canvasHeight));
      for (final b in relatives.where(
        (b) => b.id != a.id && b.generation == a.generation,
      )) {
        expect(
          (p.dx - layout.positionOf(b.id)!.dx).abs(),
          greaterThanOrEqualTo(TreeLayout.nodeSize),
        );
      }
    }
    expect(
      layout.positionOf('ancestor')!.dy,
      lessThan(layout.positionOf('child0')!.dy),
    );
  });
}
