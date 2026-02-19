import 'package:flutter_test/flutter_test.dart';
import 'package:aal_app/main.dart';

void main() {
  testWidgets('SafeNest loads successfully', (WidgetTester tester) async {

    // Build the SafeNest app
    await tester.pumpWidget(const SafeNestApp());

    // Verify splash screen loads
    expect(find.text('SafeNest'), findsWidgets);

  });
}
