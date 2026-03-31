import 'package:flutter_test/flutter_test.dart';

import 'package:wayfinder/main.dart';

void main() {
  testWidgets('Wayfinder role selection renders', (WidgetTester tester) async {
    await tester.pumpWidget(const WayfinderApp());
    expect(find.text('Choose Account Type'), findsOneWidget);
  });
}
