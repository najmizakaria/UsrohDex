import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usrohdex/main.dart';
import 'package:usrohdex/models/relative.dart';
import 'package:usrohdex/providers/app_preferences.dart';
import 'package:usrohdex/providers/relatives_provider.dart';
import 'package:usrohdex/screens/add_relative_screen.dart';
import 'package:usrohdex/screens/relative_detail_screen.dart';

void main() {
  final sample = [
    const Relative(
      id: 'parent',
      givenName: 'Ahmad bin Ismail',
      nickname: 'Ayah',
      isDiscovered: true,
      familySide: FamilySide.paternal,
      generation: 1,
    ),
    const Relative(
      id: 'child',
      givenName: 'Najmi',
      isDiscovered: true,
      familySide: FamilySide.direct,
      generation: 0,
      fatherId: 'parent',
    ),
    const Relative(
      id: 'hidden',
      givenName: 'Secret Name',
      isDiscovered: false,
      familySide: FamilySide.maternal,
      generation: 1,
    ),
  ];
  Future<void> launch(
    WidgetTester tester,
    List<Relative> people, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    final provider = RelativesProvider(
      read: () async => people,
      write: (_) async {},
    );
    final prefs = AppPreferences()..themeMode = mode;
    await tester.pumpWidget(
      UsrohDexApp(relatives: provider, preferences: prefs),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty app launches and has three working tabs', (tester) async {
    await launch(tester, []);
    expect(find.text('UsrohDex'), findsOneWidget);
    expect(find.text('Every family has a story'), findsOneWidget);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.text('Your family'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Backup & recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'directory hides undiscovered names, searches nicknames, and opens editor',
    (tester) async {
      await launch(tester, sample);
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Secret Name'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Ayah');
      await tester.pumpAndSettle();
      expect(find.text('Ayah', findRichText: false).last, findsOneWidget);
      expect(find.text('Najmi'), findsNothing);
      await tester.tap(find.text('Ayah').last);
      await tester.pumpAndSettle();
      expect(find.byType(RelativeDetailScreen), findsOneWidget);
      expect(find.text('Ahmad bin Ismail'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AddRelativeScreen), findsOneWidget);
      expect(find.text('Edit relative'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow screen supports large text and dark appearance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await launch(tester, sample, mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ayah'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'add form persists a relative and returns to the family directory',
    (tester) async {
      var saved = <Relative>[];
      final provider = RelativesProvider(
        read: () async => saved,
        write: (next) async {
          saved = next;
        },
      );
      await tester.pumpWidget(
        UsrohDexApp(relatives: provider, preferences: AppPreferences()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your first relative'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Nur Aisyah');
      await tester.enterText(find.byType(TextFormField).at(1), 'Kakak');
      await tester.scrollUntilVisible(
        find.text('Save relative'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AddRelativeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Save relative'));
      await tester.pumpAndSettle();
      expect(saved.single.givenName, 'Nur Aisyah');
      expect(saved.single.nickname, 'Kakak');
      expect(find.text('Your family'), findsOneWidget);
      expect(find.text('Kakak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed form save keeps entered details available for retry', (
    tester,
  ) async {
    final provider = RelativesProvider(
      read: () async => [],
      write: (_) async => throw StateError('disk full'),
    );
    await tester.pumpWidget(
      UsrohDexApp(relatives: provider, preferences: AppPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first relative'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Keep this name');
    await tester.scrollUntilVisible(
      find.text('Save relative'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AddRelativeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save relative'));
    await tester.pumpAndSettle();
    expect(find.byType(AddRelativeScreen), findsOneWidget);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Keep this name'),
      -300,
      scrollable: find
          .descendant(
            of: find.byType(AddRelativeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Keep this name'), findsOneWidget);
    expect(provider.relatives, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
