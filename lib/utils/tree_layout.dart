import 'package:flutter/material.dart';

import '../models/relative.dart';

/// Turns the flat list of Relatives into (x, y) canvas positions,
/// grouped by generation (rows) and ordered Paternal -> Direct -> Maternal
/// within each row.
class TreeLayout {
  static const double columnWidth = 140;
  static const double rowHeight = 220;
  static const double nodeSize = 96;

  final Map<String, Offset> positions;
  final double canvasWidth;
  final double canvasHeight;

  TreeLayout._(this.positions, this.canvasWidth, this.canvasHeight);

  factory TreeLayout.compute(List<Relative> relatives) {
    if (relatives.isEmpty) {
      return TreeLayout._({}, columnWidth * 4, rowHeight * 3);
    }

    final byGeneration = <int, List<Relative>>{};
    for (final r in relatives) {
      byGeneration.putIfAbsent(r.generation, () => []).add(r);
    }

    int sideOrder(FamilySide s) {
      switch (s) {
        case FamilySide.paternal:
          return 0;
        case FamilySide.direct:
          return 1;
        case FamilySide.maternal:
          return 2;
      }
    }

    for (final list in byGeneration.values) {
      list.sort((a, b) {
        final sideCompare = sideOrder(a.familySide).compareTo(sideOrder(b.familySide));
        if (sideCompare != 0) return sideCompare;
        return a.givenName.compareTo(b.givenName);
      });
    }

    final positions = <String, Offset>{};
    // Track the actual furthest-right / furthest-down point we use,
    // so the canvas is always guaranteed big enough to fit every node.
    double maxX = 0;
    double maxY = 0;

    final generations = byGeneration.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final gen in generations) {
      final people = byGeneration[gen]!;
      // Row index: generation 2 -> row 0 (top), generation -1 -> row 3, etc.
      final y = (2 - gen) * rowHeight + rowHeight / 2;

      for (var i = 0; i < people.length; i++) {
        final x = i * columnWidth + columnWidth / 2;
        positions[people[i].id] = Offset(x, y);
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    return TreeLayout._(
      positions,
      maxX + columnWidth * 1.5,
      maxY + rowHeight,
    );
  }

  Offset? positionOf(String id) => positions[id];
}