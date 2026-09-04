import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../painters/tree_painter.dart';
import '../providers/relatives_provider.dart';
import '../utils/tree_layout.dart';
import '../widgets/relative_node.dart';
import 'add_relative_screen.dart';
import 'relative_detail_screen.dart';

class FamilyTreeScreen extends StatelessWidget {
  const FamilyTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RelativesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final relatives = provider.relatives;
        final layout = TreeLayout.compute(relatives);

        return Scaffold(
          appBar: AppBar(title: const Text('UsrohDex')),
          body: relatives.isEmpty
              ? const Center(child: Text('No one added yet. Tap + to start.'))
              : InteractiveViewer(
                  minScale: 0.4,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(400),
                  constrained: false,
                  child: SizedBox(
                    width: layout.canvasWidth,
                    height: layout.canvasHeight,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size(layout.canvasWidth, layout.canvasHeight),
                          painter: TreePainter(relatives: relatives, layout: layout),
                        ),
                        for (final relative in relatives)
                          if (layout.positionOf(relative.id) != null)
                            Positioned(
                              left: layout.positionOf(relative.id)!.dx - TreeLayout.nodeSize / 2,
                              top: layout.positionOf(relative.id)!.dy - TreeLayout.nodeSize / 2,
                              child: RelativeNode(
                                relative: relative,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RelativeDetailScreen(relativeId: relative.id),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddRelativeScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}