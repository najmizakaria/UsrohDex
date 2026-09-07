import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';
import '../widgets/common.dart';
import 'add_relative_screen.dart';
import 'relative_detail_screen.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});
  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  String query = '', status = 'All';
  FamilySide? side;
  void _add() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddRelativeScreen()),
  );
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RelativesProvider>();
    final people =
        provider.relatives
            .where(
              (r) =>
                  (side == null || r.familySide == side) &&
                  (status == 'All' ||
                      (status == 'Discovered'
                          ? r.isDiscovered
                          : !r.isDiscovered)) &&
                  (r.visibleName.toLowerCase().contains(query) ||
                      (r.isDiscovered &&
                          r.givenName.toLowerCase().contains(query))),
            )
            .toList()
          ..sort((a, b) => a.visibleName.compareTo(b.visibleName));
    return Scaffold(
      appBar: AppBar(title: const Text('Your family')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'directory-add-relative',
        onPressed: provider.isLoading || provider.error != null ? null : _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add relative'),
      ),
      body: FamilyStatus(
        provider: provider,
        child: provider.relatives.isEmpty
            ? EmptyFamily(onAdd: _add)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.discoveredCount} of ${provider.relatives.length} relatives discovered',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: provider.relatives.isEmpty
                                ? 0
                                : provider.discoveredCount /
                                      provider.relatives.length,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search name or nickname',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) =>
                              setState(() => query = v.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('All sides'),
                                selected: side == null,
                                onSelected: (_) => setState(() => side = null),
                              ),
                              for (final s in FamilySide.values)
                                ChoiceChip(
                                  label: Text(s.label),
                                  selected: side == s,
                                  onSelected: (_) => setState(() => side = s),
                                ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: status,
                          underline: const SizedBox(),
                          items: ['All', 'Discovered', 'Undiscovered']
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    '$s relatives',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => status = v!),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: people.isEmpty
                        ? const Center(
                            child: Text(
                              'No matches. Try another name or filter.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: people.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = people[i];
                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: PersonAvatar(relative: r),
                                  title: Text(
                                    r.visibleName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${r.familySide.label} · Generation ${r.generation}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RelativeDetailScreen(
                                        relativeId: r.id,
                                      ),
                                    ),
                                  ),
                                ),
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
