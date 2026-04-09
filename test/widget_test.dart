import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SupermarketApp());

    // Verify that the app builds without crashing.
    expect(find.byType(SupermarketApp), findsOneWidget);
  });
}
