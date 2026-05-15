import 'package:flutter_test/flutter_test.dart';
import 'package:pratical_task/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScannerApp());

    // Verify that we are on the Card Scanner screen by checking for the title
    expect(find.text('Card Scanner'), findsOneWidget);
  });
}
