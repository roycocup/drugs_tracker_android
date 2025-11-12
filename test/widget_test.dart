// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:drugs_taken/database/database_helper.dart';
import 'package:drugs_taken/main.dart';
import 'package:drugs_taken/services/user_identity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home tabs render with floating action button', (tester) async {
    const testIdentity = UserIdentity(
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      userId: 'test-user-id',
    );
    await DatabaseHelper.instance.configureForUser(testIdentity.userId);

    await tester.pumpWidget(MyApp(initialIdentity: testIdentity));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Records'), findsWidgets);
    expect(find.text('Statistics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
