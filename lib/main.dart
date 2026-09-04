import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/relatives_provider.dart';
import 'screens/family_tree_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const UsrohDexApp());
}

class UsrohDexApp extends StatelessWidget {
  const UsrohDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RelativesProvider(),
      child: MaterialApp(
        title: 'UsrohDex',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
        home: const _RootShell(),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [FamilyTreeScreen(), SettingsScreen()];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'Tree'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}