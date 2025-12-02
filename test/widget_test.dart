// Basic widget test for Trivora Provider App

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/main.dart';

void main() {
  testWidgets('Provider app should render successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TrivoraProviderApp(),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the app title is shown
    expect(find.text('Trivora Provider App'), findsOneWidget);
    expect(find.text('App is running successfully!'), findsOneWidget);
  });
}
