import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wayfinder/main.dart';

void main() {
  testWidgets('Wayfinder app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(const WayfinderApp());

    // In tests, auth/profile readiness may still be loading on first frame.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
