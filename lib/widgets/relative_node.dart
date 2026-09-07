import 'package:flutter/material.dart';

import '../models/relative.dart';
import '../utils/tree_layout.dart';
import 'common.dart';

class RelativeNode extends StatelessWidget {
  final Relative relative;
  final VoidCallback onTap;
  final bool selected;
  const RelativeNode({
    super.key,
    required this.relative,
    required this.onTap,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${relative.visibleName}, ${relative.familySide.label}, generation ${relative.generation}',
    child: SizedBox(
      width: TreeLayout.nodeSize,
      height: TreeLayout.nodeSize,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PersonAvatar(relative: relative, radius: 25),
                const SizedBox(height: 8),
                Text(
                  relative.isDiscovered ? relative.displayName : 'Undiscovered',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
