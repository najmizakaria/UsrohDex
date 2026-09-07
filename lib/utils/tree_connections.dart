import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/relative.dart';
import 'tree_layout.dart';

class TreeSegment {
  final Offset start, end;
  const TreeSegment(this.start, this.end);
}

/// One exact set of known parents. Half-siblings belong to separate groups.
class FamilyConnection {
  final List<String> parentIds, childIds;
  final Offset junction;
  final List<TreeSegment> segments;
  const FamilyConnection({
    required this.parentIds,
    required this.childIds,
    required this.junction,
    required this.segments,
  });
}

List<FamilyConnection> familyConnections(
  List<Relative> people,
  TreeLayout layout,
) {
  final groups = <String, List<Relative>>{};
  final parentsByGroup = <String, List<String>>{};
  for (final child in people) {
    final parents =
        [child.fatherId, child.motherId]
            .whereType<String>()
            .where((id) => layout.positionOf(id) != null)
            .toSet()
            .toList()
          ..sort();
    if (parents.isEmpty || layout.positionOf(child.id) == null) continue;
    final key = jsonEncode(parents);
    parentsByGroup[key] = parents;
    groups.putIfAbsent(key, () => []).add(child);
  }
  final result = <FamilyConnection>[];
  const half = TreeLayout.nodeSize / 2;
  for (final entry in groups.entries) {
    final ids = parentsByGroup[entry.key]!;
    final parents = ids.map((id) => layout.positionOf(id)!).toList()
      ..sort((a, b) => a.dx.compareTo(b.dx));
    final segments = <TreeSegment>[];
    late Offset junction;
    if (parents.length == 1) {
      junction = parents.single + const Offset(0, half);
    } else {
      final left = parents.first, right = parents.last;
      final adjacent =
          left.dy == right.dy &&
          (right.dx - left.dx) <= TreeLayout.columnWidth + 1;
      if (adjacent) {
        // Join the inner edges of the two parent cards. Their children descend
        // from the middle of this line, not from either parent's card.
        junction = Offset((left.dx + right.dx) / 2, left.dy);
        segments.add(
          TreeSegment(
            left + const Offset(half, 0),
            right - const Offset(half, 0),
          ),
        );
      } else {
        // For separated parents use a bracket below both cards, rather than
        // drawing a horizontal connection through intervening cards.
        final y = (left.dy > right.dy ? left.dy : right.dy) + half + 20;
        junction = Offset((left.dx + right.dx) / 2, y);
        for (final p in parents) {
          segments.add(TreeSegment(p + const Offset(0, half), Offset(p.dx, y)));
        }
        segments.add(TreeSegment(Offset(left.dx, y), Offset(right.dx, y)));
      }
    }
    final rows = <double, List<Offset>>{};
    for (final child in entry.value) {
      final p = layout.positionOf(child.id)!;
      rows.putIfAbsent(p.dy, () => []).add(p - const Offset(0, half));
    }
    for (final row in rows.entries) {
      final children = row.value..sort((a, b) => a.dx.compareTo(b.dx));
      final lowestParentBottom = parents
          .map((p) => p.dy + half)
          .reduce((a, b) => a > b ? a : b);
      final startY = junction.dy > lowestParentBottom
          ? junction.dy
          : lowestParentBottom;
      final busY = (startY + children.first.dy) / 2;
      final minX = children.first.dx < junction.dx
          ? children.first.dx
          : junction.dx;
      final maxX = children.last.dx > junction.dx
          ? children.last.dx
          : junction.dx;
      segments.add(TreeSegment(junction, Offset(junction.dx, busY)));
      if (minX != maxX) {
        segments.add(TreeSegment(Offset(minX, busY), Offset(maxX, busY)));
      }
      for (final child in children) {
        segments.add(TreeSegment(Offset(child.dx, busY), child));
      }
    }
    result.add(
      FamilyConnection(
        parentIds: ids,
        childIds: entry.value.map((c) => c.id).toList(),
        junction: junction,
        segments: segments,
      ),
    );
  }
  return result;
}
