import 'package:flutter_test/flutter_test.dart';
import 'package:aal_app/main.dart';

void main() {
  testWidgets('SmartNest loads successfully', (WidgetTester tester) async {

    // Build the SmartNest app
    await tester.pumpWidget(const SmartNestApp());

    // Verify splash screen loads
    expect(find.text('SmartNest'), findsWidgets);

  });
}
