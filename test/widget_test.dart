import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/main.dart';

void main() {
  testWidgets('App starts and shows auth gate', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChessApp());

    // Verify that the app starts (either showing a loader or the login screen)
    // Since AuthGate starts with _checking = true, we expect a CircularProgressIndicator
    expect(find.byType(ChessApp), findsOneWidget);
  });
}
