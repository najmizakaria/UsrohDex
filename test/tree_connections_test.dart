import 'package:flutter_test/flutter_test.dart';
import 'package:usrohdex/models/relative.dart';
import 'package:usrohdex/utils/tree_connections.dart';
import 'package:usrohdex/utils/tree_layout.dart';

Relative person(
  String id, {
  int generation = 0,
  String? father,
  String? mother,
}) => Relative(
  id: id,
  givenName: id,
  isDiscovered: true,
  familySide: FamilySide.direct,
  generation: generation,
  fatherId: father,
  motherId: mother,
);
void main() {
  test(
    'parents join once and siblings share one bar with separate child drops',
    () {
      final people = [
        person('dad', generation: 1),
        person('mom', generation: 1),
        for (final id in ['a', 'b', 'c'])
          person(id, father: 'dad', mother: 'mom'),
      ];
      final layout = TreeLayout.compute(people);
      final family = familyConnections(people, layout).single;
      final dad = layout.positionOf('dad')!, mom = layout.positionOf('mom')!;
      expect((dad.dx - mom.dx).abs(), TreeLayout.columnWidth);
      expect(family.junction.dx, (dad.dx + mom.dx) / 2);
      expect(family.junction.dy, dad.dy);
      final bars = family.segments
          .where((s) => s.start.dy == s.end.dy && s.start.dy > dad.dy)
          .toList();
      expect(bars, hasLength(1));
      expect(
        family.segments.where((s) => s.start == family.junction),
        hasLength(1),
      );
      for (final id in ['a', 'b', 'c']) {
        final child = layout.positionOf(id)!;
        final drop = family.segments.singleWhere(
          (s) =>
              s.end.dx == child.dx &&
              s.end.dy == child.dy - TreeLayout.nodeSize / 2,
        );
        expect(drop.start.dy, bars.single.start.dy);
        expect(drop.start.dx, drop.end.dx);
      }
    },
  );
  test(
    'half siblings with different parent pairs never share a family bar',
    () {
      final people = [
        person('dad', generation: 1),
        person('mom1', generation: 1),
        person('mom2', generation: 1),
        person('a', father: 'dad', mother: 'mom1'),
        person('b', father: 'dad', mother: 'mom2'),
      ];
      final families = familyConnections(people, TreeLayout.compute(people));
      expect(families, hasLength(2));
      expect(
        families.map((f) => f.childIds.single),
        unorderedEquals(['a', 'b']),
      );
      expect(families.first.parentIds, isNot(families.last.parentIds));
    },
  );
  test(
    'single known parent connects siblings without inventing a second parent',
    () {
      final people = [
        person('mom', generation: 1),
        person('a', mother: 'mom'),
        person('b', mother: 'mom'),
      ];
      final layout = TreeLayout.compute(people);
      final family = familyConnections(people, layout).single;
      expect(family.parentIds, ['mom']);
      expect(
        family.junction.dy,
        layout.positionOf('mom')!.dy + TreeLayout.nodeSize / 2,
      );
      expect(family.childIds, hasLength(2));
    },
  );
  test('a single child receives a drop and no fabricated siblings', () {
    final people = [
      person('dad', generation: 1),
      person('mom', generation: 1),
      person('only', father: 'dad', mother: 'mom'),
    ];
    final layout = TreeLayout.compute(people);
    final family = familyConnections(people, layout).single;
    expect(family.childIds, ['only']);
    final child = layout.positionOf('only')!;
    expect(
      family.segments.where(
        (s) => s.end.dy == child.dy - TreeLayout.nodeSize / 2,
      ),
      hasLength(1),
    );
  });
  test('parents in different generations have a joint below both cards', () {
    final people = [
      person('dad', generation: 2),
      person('mom', generation: 1),
      person('child', father: 'dad', mother: 'mom'),
    ];
    final layout = TreeLayout.compute(people);
    final family = familyConnections(people, layout).single;
    expect(
      family.junction.dy,
      greaterThan(layout.positionOf('mom')!.dy + TreeLayout.nodeSize / 2),
    );
    expect(
      family.junction.dy,
      lessThan(layout.positionOf('child')!.dy - TreeLayout.nodeSize / 2),
    );
  });
}
