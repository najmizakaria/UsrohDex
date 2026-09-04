import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../painters/tree_painter.dart';
import '../providers/relatives_provider.dart';
import '../utils/tree_layout.dart';
import '../widgets/relative_node.dart';
import 'add_relative_screen.dart';
import 'relative_detail_screen.dart';

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (_animation != null) {
          _controller.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Animates the canvas to center on and zoom into a group of relatives
  /// (e.g. everyone on Ayah's side).
  void _focusOn(List<Relative> group, TreeLayout layout, Size viewportSize) {
    if (group.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No one in this group yet.')),
      );
      return;
    }

    final points = group
        .map((r) => layout.positionOf(r.id))
        .whereType<Offset>()
        .toList();
    if (points.isEmpty) return;

    final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

    final groupCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final groupWidth = (maxX - minX) + TreeLayout.columnWidth * 2;
    final groupHeight = (maxY - minY) + TreeLayout.rowHeight;

    final scaleX = viewportSize.width / groupWidth;
    final scaleY = viewportSize.height / groupHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final clampedScale = scale.clamp(0.6, 2.2);

    final target = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(clampedScale, clampedScale, clampedScale, 1)
      ..translateByDouble(-groupCenter.dx, -groupCenter.dy, 0, 1);

    _animation = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _animController.forward(from: 0);
  }

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
          appBar: AppBar(
            title: const Text('UsrohDex'),
            actions: [
              PopupMenuButton<FamilySide>(
                icon: const Icon(Icons.center_focus_strong),
                tooltip: 'Auto-focus',
                onSelected: (side) {
                  final size = MediaQuery.of(context).size;
                  final group =
                      relatives.where((r) => r.familySide == side).toList();
                  _focusOn(group, layout, size);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: FamilySide.paternal,
                    child: Text("Focus: Ayah's side"),
                  ),
                  PopupMenuItem(
                    value: FamilySide.maternal,
                    child: Text("Focus: Ibu's side"),
                  ),
                  PopupMenuItem(
                    value: FamilySide.direct,
                    child: Text('Focus: Direct family'),
                  ),
                ],
              ),
            ],
          ),
          body: relatives.isEmpty
              ? const Center(child: Text('No one added yet. Tap + to start.'))
              : InteractiveViewer(
                  transformationController: _controller,
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
                              left: layout.positionOf(relative.id)!.dx -
                                  TreeLayout.nodeSize / 2,
                              top: layout.positionOf(relative.id)!.dy -
                                  TreeLayout.nodeSize / 2,
                              child: RelativeNode(
                                relative: relative,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RelativeDetailScreen(relativeId: relative.id),
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