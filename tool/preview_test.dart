// Render deterministic demo screens without touching the user's family database.
// flutter test tool/preview_test.dart --dart-define=FONT_PATH=<Flutter SDK>/bin/cache/artifacts/material_fonts/roboto-regular.ttf
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usrohdex/main.dart';
import 'package:usrohdex/models/relative.dart';
import 'package:usrohdex/providers/app_preferences.dart';
import 'package:usrohdex/providers/relatives_provider.dart';

void main() {
  testWidgets('render demo screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    const fontPath = String.fromEnvironment('FONT_PATH');
    if (fontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(fontPath).readAsBytes()),
            ),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  fontPath.replaceAll(
                    'roboto-regular.ttf',
                    'materialicons-regular.otf',
                  ),
                ).readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
    }
    final relatives = [
      const Relative(
        id: 'grandfather',
        givenName: 'Ismail bin Abdullah',
        nickname: 'Tok Ayah',
        isDiscovered: true,
        familySide: FamilySide.paternal,
        generation: 2,
        partnerIds: ['grandmother'],
      ),
      const Relative(
        id: 'grandmother',
        givenName: 'Fatimah',
        nickname: 'Tok Ma',
        isDiscovered: true,
        familySide: FamilySide.paternal,
        generation: 2,
        partnerIds: ['grandfather'],
      ),
      Relative(
        id: 'father',
        givenName: 'Ahmad bin Ismail',
        nickname: 'Ayah',
        isDiscovered: true,
        familySide: FamilySide.paternal,
        generation: 1,
        fatherId: 'grandfather',
        motherId: 'grandmother',
        partnerIds: const ['mother'],
        birthDate: DateTime(1970, 5, 12),
        phoneNumber: '012 345 6789',
        notes: 'Loves gardening and telling stories about his hometown.',
      ),
      const Relative(
        id: 'mother',
        givenName: 'Siti Aminah',
        nickname: 'Ibu',
        isDiscovered: true,
        familySide: FamilySide.maternal,
        generation: 1,
        partnerIds: ['father'],
      ),
      const Relative(
        id: 'aunt',
        givenName: 'Maryam',
        isDiscovered: false,
        familySide: FamilySide.paternal,
        generation: 1,
        fatherId: 'grandfather',
        motherId: 'grandmother',
      ),
      const Relative(
        id: 'self',
        givenName: 'Najmi',
        isDiscovered: true,
        familySide: FamilySide.direct,
        generation: 0,
        fatherId: 'father',
        motherId: 'mother',
      ),
      const Relative(
        id: 'sibling',
        givenName: 'Aisyah',
        isDiscovered: true,
        familySide: FamilySide.direct,
        generation: 0,
        fatherId: 'father',
        motherId: 'mother',
      ),
    ];
    final prefs = AppPreferences()..themeMode = ThemeMode.light;
    final provider = RelativesProvider(
      read: () async => relatives,
      write: (_) async {},
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UsrohDexApp(relatives: provider, preferences: prefs),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/previews');
        await directory.create(recursive: true);
        await File('${directory.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('tree-light');
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await capture('family-light');
    await tester.tap(find.text('Ayah'));
    await tester.pumpAndSettle();
    await capture('profile-light');
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await capture('editor-light');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await capture('settings-light');
    prefs.themeMode = ThemeMode.dark;
    // Rebuild through a supported preference action to capture the real dark theme.
    await tester.runAsync(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async =>
                (await Directory.systemTemp.createTemp('usrohdex-preview-'))
                    .path,
          );
      await prefs.save(theme: ThemeMode.dark);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await capture('family-dark');
    debugDisableShadows = true;
  });
}
