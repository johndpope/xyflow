// This is a basic Flutter widget test for the XYFlow example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:xyflow_flutter_example/main.dart';

void main() {
  testWidgets('App loads and shows example selector', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the example selector is shown
    expect(find.text('XYFlow Flutter Examples'), findsOneWidget);

    // Verify that at least some example cards are displayed (visible in viewport)
    expect(find.text('Basic Flow'), findsOneWidget);
    expect(find.text('Drag & Drop'), findsOneWidget);
  });
}
