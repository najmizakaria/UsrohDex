import 'package:flutter/material.dart';

import '../models/relative.dart';
import '../utils/tree_connections.dart';
import '../utils/tree_layout.dart';

class TreePainter extends CustomPainter {
  final List<Relative> relatives;
  final TreeLayout layout;
  final Color color;
  TreePainter({
    required this.relatives,
    required this.layout,
    this.color = const Color(0xFFB7A393),
  });
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final families = familyConnections(relatives, layout);
    for (final family in families) {
      for (final segment in family.segments) {
        canvas.drawLine(segment.start, segment.end, pen);
      }
      if (family.parentIds.length == 2) {
        canvas.drawCircle(family.junction, 3, Paint()..color = color);
      }
    }
    // Only childless partner links are dashed. A parent couple already has
    // its solid union line; drawing both would make the relationship ambiguous.
    final drawn = <String>{};
    for (final r in relatives) {
      final position = layout.positionOf(r.id);
      if (position == null) continue;
      for (final id in r.partnerIds) {
        final pair = [r.id, id]..sort();
        final key = pair.join('\u0000');
        if (!drawn.add(key)) continue;
        if (families.any(
          (f) =>
              f.parentIds.length == 2 &&
              f.parentIds.contains(r.id) &&
              f.parentIds.contains(id),
        )) {
          continue;
        }
        final partner = layout.positionOf(id);
        if (partner == null) continue;
        final delta = partner - position;
        if (delta.distance <= TreeLayout.nodeSize) continue;
        final unit = delta / delta.distance;
        final start = position + unit * (TreeLayout.nodeSize / 2),
            end = partner - unit * (TreeLayout.nodeSize / 2);
        final vector = end - start, length = vector.distance;
        for (var d = 0.0; d < length; d += 12) {
          canvas.drawLine(
            start + vector / length * d,
            start + vector / length * ((d + 6).clamp(0, length)),
            pen,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.relatives != relatives ||
      oldDelegate.color != color;
}
