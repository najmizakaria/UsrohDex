import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/relatives_provider.dart';
import 'screens/family_list_screen.dart';

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
        home: const FamilyListScreen(),
      ),
    );
  }
}