import 'dart:io';

import 'package:flutter/material.dart';

import '../models/relative.dart';
import '../utils/tree_layout.dart';

class RelativeNode extends StatelessWidget {
  final Relative relative;
  final VoidCallback onTap;

  const RelativeNode({super.key, required this.relative, required this.onTap});

  Color get _sideColor {
    switch (relative.familySide) {
      case FamilySide.paternal:
        return Colors.indigo;
      case FamilySide.maternal:
        return Colors.teal;
      case FamilySide.direct:
        return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final discovered = relative.isDiscovered;
    final hasPhoto =
        discovered && relative.photoPath != null && File(relative.photoPath!).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: TreeLayout.nodeSize,
        height: TreeLayout.nodeSize + 28,
        child: Column(
          children: [
            Container(
              width: TreeLayout.nodeSize - 20,
              height: TreeLayout.nodeSize - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: discovered ? _sideColor : Colors.grey.shade700,
                  width: 3,
                ),
                color: discovered ? Colors.grey.shade200 : Colors.black87,
                image: hasPhoto
                    ? DecorationImage(image: FileImage(File(relative.photoPath!)), fit: BoxFit.cover)
                    : null,
              ),
              child: !discovered
                  ? const Icon(Icons.help_outline, color: Colors.white54, size: 32)
                  : (hasPhoto
                      ? null
                      : Center(
                          child: Text(
                            relative.displayName.isNotEmpty
                                ? relative.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _sideColor),
                          ),
                        )),
            ),
            const SizedBox(height: 4),
            Text(
              // Canvas shows the nickname (falls back to given name if none set).
              discovered ? relative.displayName : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: discovered ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}