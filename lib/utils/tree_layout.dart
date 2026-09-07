import 'package:flutter/material.dart';

import '../models/relative.dart';

/// Relationship-aware rows. Siblings share a block; partner blocks are merged.
/// A barycentric sweep pulls each block toward its parents without node overlap.
class TreeLayout {
  static const double columnWidth = 160, rowHeight = 210, nodeSize = 116;
  final Map<String, Offset> positions;
  final double canvasWidth, canvasHeight;
  TreeLayout._(this.positions, this.canvasWidth, this.canvasHeight);
  factory TreeLayout.compute(List<Relative> relatives) {
    if (relatives.isEmpty) return TreeLayout._({}, 640, 480);
    final rows = <int, List<Relative>>{};
    for (final r in relatives) {
      rows.putIfAbsent(r.generation, () => []).add(r);
    }
    final generations = rows.keys.toList()..sort((a, b) => b.compareTo(a));
    final positions = <String, Offset>{};
    // Sharing children also makes a visual couple; no partner record is required.
    final partners = <String, Set<String>>{};
    for (final r in relatives) {
      partners.putIfAbsent(r.id, () => {}).addAll(r.partnerIds);
      if (r.fatherId != null && r.motherId != null) {
        partners.putIfAbsent(r.fatherId!, () => {}).add(r.motherId!);
        partners.putIfAbsent(r.motherId!, () => {}).add(r.fatherId!);
      }
    }
    final rowGroups = <int, List<List<Relative>>>{};
    int sideOrder(FamilySide side) => switch (side) {
      FamilySide.paternal => 0,
      FamilySide.direct => 1,
      FamilySide.maternal => 2,
    };
    for (final gen in generations) {
      final people = rows[gen]!;
      final byId = {for (final r in people) r.id: r};
      final visited = <String>{};
      final groups = <List<Relative>>[];
      for (final r in people) {
        if (visited.contains(r.id)) continue;
        final group = <Relative>[];
        void collect(Relative p) {
          if (!visited.add(p.id)) return;
          group.add(p);
          for (final other in people) {
            final sibling =
                (p.fatherId != null && p.fatherId == other.fatherId) ||
                (p.motherId != null && p.motherId == other.motherId);
            if (sibling || partners[p.id]!.contains(other.id)) collect(other);
          }
        }

        collect(r);
        group.sort((a, b) => a.id.compareTo(b.id));
        // Put partners adjacent within the block where possible.
        final ordered = <Relative>[];
        for (final person in group) {
          if (ordered.contains(person)) continue;
          ordered.add(person);
          for (final id in partners[person.id]!.toList()..sort()) {
            final partner = byId[id];
            if (partner != null &&
                group.contains(partner) &&
                !ordered.contains(partner)) {
              ordered.add(partner);
            }
          }
        }
        groups.add(ordered);
      }
      double anchor(List<Relative> group) {
        final parents = group
            .expand((r) => [r.fatherId, r.motherId])
            .whereType<String>()
            .toSet()
            .map((id) => positions[id]?.dx)
            .whereType<double>()
            .toList();
        if (parents.isNotEmpty) {
          return parents.reduce((a, b) => a + b) / parents.length;
        }
        return sideOrder(group.first.familySide) * 10000.0;
      }

      groups.sort((a, b) {
        final compare = anchor(a).compareTo(anchor(b));
        return compare != 0 ? compare : a.first.id.compareTo(b.first.id);
      });
      rowGroups[gen] = groups;
      var x = 80.0;
      for (final group in groups) {
        for (final r in group) {
          positions[r.id] = Offset(
            x,
            (generations.first - gen) * rowHeight + 100,
          );
          x += columnWidth;
        }
        x += 40;
      }
    }
    final maxRowWidth = rowGroups.values
        .map(
          (groups) => groups.fold<double>(
            0,
            (sum, g) => sum + g.length * columnWidth + 40,
          ),
        )
        .reduce((a, b) => a > b ? a : b);
    // Center short rows, then align parents with the mean position of children.
    for (final gen in generations.reversed) {
      final people = rows[gen]!;
      final width = rowGroups[gen]!.fold<double>(
        0,
        (sum, g) => sum + g.length * columnWidth + 40,
      );
      for (final r in people) {
        positions[r.id] =
            positions[r.id]! + Offset((maxRowWidth - width) / 2, 0);
      }
      final sorted = [...people]
        ..sort((a, b) => positions[a.id]!.dx.compareTo(positions[b.id]!.dx));
      var previous = 0.0;
      final placed = <String>{};
      for (final r in sorted) {
        if (!placed.add(r.id)) continue;
        final couple = [r];
        for (final candidate in sorted) {
          if (!placed.contains(candidate.id) &&
              partners[r.id]!.contains(candidate.id)) {
            couple.add(candidate);
            placed.add(candidate.id);
            break;
          }
        }
        final ids = couple.map((p) => p.id).toSet();
        final children = relatives
            .where((c) => ids.contains(c.fatherId) || ids.contains(c.motherId))
            .map((c) => positions[c.id]!.dx)
            .toList();
        var x = children.isEmpty
            ? positions[r.id]!.dx
            : (children.reduce((a, b) => a < b ? a : b) +
                          children.reduce((a, b) => a > b ? a : b)) /
                      2 -
                  (couple.length - 1) * columnWidth / 2;
        if (x < previous + columnWidth) x = previous + columnWidth;
        for (final member in couple) {
          positions[member.id] = Offset(x, positions[member.id]!.dy);
          previous = x;
          x += columnWidth;
        }
      }
    }
    // A parent block can be pushed sideways by its own siblings. Move each
    // descendant block beneath that final parent junction, preserving couples
    // and spacing, rather than leaving the children behind at the old center.
    for (final gen in generations) {
      final groups = [...rowGroups[gen]!]
        ..sort(
          (a, b) =>
              positions[a.first.id]!.dx.compareTo(positions[b.first.id]!.dx),
        );
      var rightEdge = -columnWidth;
      for (final group in groups) {
        final minX = group
            .map((r) => positions[r.id]!.dx)
            .reduce((a, b) => a < b ? a : b);
        final connected = group
            .where(
              (r) =>
                  positions.containsKey(r.fatherId) ||
                  positions.containsKey(r.motherId),
            )
            .toList();
        var shift = 0.0;
        if (connected.isNotEmpty) {
          final parentIds = connected
              .expand((r) => [r.fatherId, r.motherId])
              .whereType<String>()
              .where(positions.containsKey)
              .toSet();
          final parentCenter =
              parentIds.map((id) => positions[id]!.dx).reduce((a, b) => a + b) /
              parentIds.length;
          final xs = connected.map((r) => positions[r.id]!.dx).toList()..sort();
          shift = parentCenter - (xs.first + xs.last) / 2;
        }
        final minimumShift = rightEdge + columnWidth - minX;
        if (shift < minimumShift) shift = minimumShift;
        if (minX + shift < 80) shift = 80 - minX;
        for (final r in group) {
          positions[r.id] = positions[r.id]! + Offset(shift, 0);
        }
        rightEdge = group
            .map((r) => positions[r.id]!.dx)
            .reduce((a, b) => a > b ? a : b);
      }
    }
    final maxX = positions.values
        .map((p) => p.dx)
        .reduce((a, b) => a > b ? a : b);
    final maxY = positions.values
        .map((p) => p.dy)
        .reduce((a, b) => a > b ? a : b);
    return TreeLayout._(positions, maxX + 180, maxY + 180);
  }
  Offset? positionOf(String id) => positions[id];
}
