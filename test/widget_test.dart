import 'package:flutter_test/flutter_test.dart';
import 'package:usrohdex/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const UsrohDexApp());
    expect(find.text('UsrohDex'), findsOneWidget);
  });
}