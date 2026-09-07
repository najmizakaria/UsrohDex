import 'dart:io';

import 'package:flutter/material.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';

Color sideColor(FamilySide side) => switch (side) {
  FamilySide.paternal => const Color(0xFF6574BC),
  FamilySide.maternal => const Color(0xFF328A80),
  FamilySide.direct => const Color(0xFFC87940),
};
void showFailure(BuildContext context, Object error) {
  final message = error is FormatException
      ? error.message
      : error is FileSystemException
      ? error.message
      : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class PersonAvatar extends StatelessWidget {
  final Relative relative;
  final double radius;
  const PersonAvatar({super.key, required this.relative, this.radius = 25});
  @override
  Widget build(BuildContext context) {
    final path = relative.isDiscovered ? relative.photoPath : null;
    final color = sideColor(relative.familySide);
    return Container(
      width: radius * 2,
      height: radius * 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .16),
        border: Border.all(color: color.withValues(alpha: .5), width: 2),
      ),
      child: path == null
          ? _fallback(color)
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(color),
            ),
    );
  }

  Widget _fallback(Color color) => Center(
    child: relative.isDiscovered
        ? Text(
            relative.displayName.characters.firstOrNull?.toUpperCase() ?? '?',
            style: TextStyle(
              fontSize: radius * .65,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          )
        : Icon(Icons.lock_outline_rounded, color: color, size: radius),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    ),
  );
}

class FamilyStatus extends StatelessWidget {
  final RelativesProvider provider;
  final Widget child;
  const FamilyStatus({super.key, required this.provider, required this.child});
  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: provider.reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}

class EmptyFamily extends StatelessWidget {
  final VoidCallback onAdd;
  const EmptyFamily({super.key, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diversity_1_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Every family has a story',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Start with yourself or someone you know. Add connections as your family story grows.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add your first relative'),
          ),
        ],
      ),
    ),
  );
}

Future<Relative?> pickPerson(
  BuildContext context,
  List<Relative> candidates, {
  String title = 'Choose a relative',
}) => showModalBottomSheet<Relative>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _PersonPicker(candidates: candidates, title: title),
);

class _PersonPicker extends StatefulWidget {
  final List<Relative> candidates;
  final String title;
  const _PersonPicker({required this.candidates, required this.title});
  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final people =
        widget.candidates
            .where(
              (r) =>
                  r.visibleName.toLowerCase().contains(query) ||
                  (r.isDiscovered && r.givenName.toLowerCase().contains(query)),
            )
            .toList()
          ..sort((a, b) => a.visibleName.compareTo(b.visibleName));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search family',
              ),
              onChanged: (s) => setState(() => query = s.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: people.isEmpty
                  ? const Center(child: Text('No matching relatives'))
                  : ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (c, i) {
                        final r = people[i];
                        return ListTile(
                          leading: PersonAvatar(relative: r),
                          title: Text(r.visibleName),
                          subtitle: Text(
                            '${r.familySide.label} · Generation ${r.generation}',
                          ),
                          onTap: () => Navigator.pop(context, r),
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
