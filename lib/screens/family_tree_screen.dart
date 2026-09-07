import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../painters/tree_painter.dart';
import '../providers/relatives_provider.dart';
import '../utils/tree_layout.dart';
import '../widgets/common.dart';
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
  final _transform = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Size _viewport = Size.zero;
  String? _selected;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..addListener(() {
          if (_animation != null) _transform.value = _animation!.value;
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _move(Matrix4 target) {
    _animation = Matrix4Tween(begin: _transform.value.clone(), end: target)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward(from: 0);
  }

  void _focus(Iterable<Relative> people, TreeLayout layout) {
    final points = people
        .map((r) => layout.positionOf(r.id))
        .whereType<Offset>()
        .toList();
    if (points.isEmpty || _viewport.isEmpty) return;
    var bounds = Rect.fromCenter(
      center: points.first,
      width: TreeLayout.nodeSize,
      height: TreeLayout.nodeSize,
    );
    for (final point in points.skip(1)) {
      bounds = bounds.expandToInclude(
        Rect.fromCenter(
          center: point,
          width: TreeLayout.nodeSize,
          height: TreeLayout.nodeSize,
        ),
      );
    }
    bounds = bounds.inflate(48);
    final scale = (_viewport.width / bounds.width).clamp(.01, 1.5);
    final heightScale =
        ((_viewport.height - 160).clamp(100.0, double.infinity) / bounds.height)
            .clamp(.01, 1.5);
    final zoom = scale < heightScale ? scale : heightScale;
    _move(
      Matrix4.identity()
        ..translateByDouble(
          _viewport.width / 2 - bounds.center.dx * zoom,
          _viewport.height / 2 - bounds.center.dy * zoom,
          0,
          1,
        )
        ..scaleByDouble(zoom, zoom, 1, 1),
    );
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.01, 3.0);
    final ratio = next / current;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _move(matrix * _transform.value);
  }

  void _add() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddRelativeScreen()),
  );
  void _legend() => showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading your family tree',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final side in FamilySide.values)
              ListTile(
                leading: Icon(Icons.circle, color: sideColor(side), size: 18),
                title: Text('${side.label} family'),
              ),
            const Text(
              'Parents join at a dot. One line descends to a shared bar for their children. Dashed lines connect partners who have no shared children. Older generations appear above younger ones.\n\nLocked cards are relatives you have not discovered yet. Tap a card to open their profile. Pinch to zoom and drag to explore.',
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    final relatives = provider.relatives;
    final layout = TreeLayout.compute(relatives);
    if (relatives.isEmpty) _initialized = false;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UsrohDex'),
            Text('Your family, connected', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Find a relative',
            onPressed: relatives.isEmpty
                ? null
                : () async {
                    final person = await pickPerson(
                      context,
                      relatives,
                      title: 'Find on tree',
                    );
                    if (person != null && mounted) {
                      setState(() => _selected = person.id);
                      _focus([person], layout);
                    }
                  },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Tree guide',
            onPressed: _legend,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tree-add-relative',
        onPressed: provider.isLoading || provider.error != null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Add relative'),
      ),
      body: FamilyStatus(
        provider: provider,
        child: relatives.isEmpty
            ? EmptyFamily(onAdd: _add)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${provider.discoveredCount} of ${relatives.length} discovered',
                          ),
                        ),
                        PopupMenuButton<FamilySide>(
                          tooltip: 'Focus family side',
                          onSelected: (side) {
                            final group = relatives
                                .where((r) => r.familySide == side)
                                .toList();
                            if (group.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No relatives on this side yet.',
                                  ),
                                ),
                              );
                              return;
                            }
                            _focus(group, layout);
                          },
                          itemBuilder: (_) => [
                            for (final s in FamilySide.values)
                              PopupMenuItem(
                                value: s,
                                child: Text('${s.label} family'),
                              ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text('Focus side'),
                                Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _viewport = constraints.biggest;
                        if (!_initialized) {
                          _initialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _focus(relatives, layout);
                          });
                        }
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: InteractiveViewer(
                                transformationController: _transform,
                                minScale: .01,
                                maxScale: 3,
                                onInteractionStart: (_) =>
                                    _animationController.stop(),
                                boundaryMargin: const EdgeInsets.all(
                                  double.infinity,
                                ),
                                constrained: false,
                                child: SizedBox(
                                  width: layout.canvasWidth,
                                  height: layout.canvasHeight,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(
                                          layout.canvasWidth,
                                          layout.canvasHeight,
                                        ),
                                        painter: TreePainter(
                                          relatives: relatives,
                                          layout: layout,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: .55),
                                        ),
                                      ),
                                      for (final r in relatives)
                                        Positioned(
                                          left:
                                              layout.positionOf(r.id)!.dx -
                                              TreeLayout.nodeSize / 2,
                                          top:
                                              layout.positionOf(r.id)!.dy -
                                              TreeLayout.nodeSize / 2,
                                          child: RelativeNode(
                                            relative: r,
                                            selected: _selected == r.id,
                                            onTap: () {
                                              setState(() => _selected = r.id);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      RelativeDetailScreen(
                                                        relativeId: r.id,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: 12,
                              child: Card(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Zoom in',
                                      onPressed: () => _zoom(1.3),
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: 'Zoom out',
                                      onPressed: () => _zoom(1 / 1.3),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    IconButton(
                                      tooltip: 'Fit entire tree',
                                      onPressed: () {
                                        setState(() => _selected = null);
                                        _focus(relatives, layout);
                                      },
                                      icon: const Icon(Icons.fit_screen),
                                    ),
                                    IconButton(
                                      tooltip: 'Reset view',
                                      onPressed: () {
                                        setState(() => _selected = null);
                                        _focus(relatives, layout);
                                      },
                                      icon: const Icon(Icons.restart_alt),
                                    ),
                                    if (_selected != null &&
                                        provider.byId(_selected!) != null)
                                      IconButton(
                                        tooltip: 'Focus selected family',
                                        onPressed: () {
                                          final r = provider.byId(_selected!)!;
                                          final ids = {
                                            r.id,
                                            r.fatherId,
                                            r.motherId,
                                            ...r.partnerIds,
                                            ...provider
                                                .childrenOf(r.id)
                                                .map((c) => c.id),
                                            ...provider
                                                .siblingsOf(r)
                                                .map((c) => c.id),
                                          };
                                          _focus(
                                            relatives.where(
                                              (r) => ids.contains(r.id),
                                            ),
                                            layout,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.center_focus_strong,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
