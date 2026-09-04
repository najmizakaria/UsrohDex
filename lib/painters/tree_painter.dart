import 'package:flutter/material.dart';

import '../models/relative.dart';
import '../utils/tree_layout.dart';

/// Draws connector lines between each relative and their father/mother.
class TreePainter extends CustomPainter {
  final List<Relative> relatives;
  final TreeLayout layout;

  TreePainter({required this.relatives, required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final relative in relatives) {
      final childPos = layout.positionOf(relative.id);
      if (childPos == null) continue;

      for (final parentId in [relative.fatherId, relative.motherId]) {
        if (parentId == null) continue;
        final parentPos = layout.positionOf(parentId);
        if (parentPos == null) continue;

        // Elbow connector: down from parent, across, down into child.
        final midY = (parentPos.dy + childPos.dy) / 2;
        final path = Path()
          ..moveTo(parentPos.dx, parentPos.dy + TreeLayout.nodeSize / 2)
          ..lineTo(parentPos.dx, midY)
          ..lineTo(childPos.dx, midY)
          ..lineTo(childPos.dx, childPos.dy - TreeLayout.nodeSize / 2);

        canvas.drawPath(path, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreePainter oldDelegate) {
    return oldDelegate.relatives != relatives;
  }
}