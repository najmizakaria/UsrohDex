import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'add_relative_screen.dart';

import '../models/relative.dart';
import '../providers/relatives_provider.dart';

class FamilyListScreen extends StatelessWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UsrohDex')),
      body: Consumer<RelativesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.relatives.isEmpty) {
            return const Center(child: Text('No one added yet. Tap + to start.'));
          }
          return ListView.builder(
            itemCount: provider.relatives.length,
            itemBuilder: (context, index) {
              final r = provider.relatives[index];
              return ListTile(
                leading: CircleAvatar(child: Text(r.givenName[0])),
                title: Text(r.givenName),
                subtitle: Text('${r.familySide.label} · Gen ${r.generation}'),
              );
            },
          );
        },
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
  }
}