import 'package:drugs_taken/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Records tab renders list layout', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Records'), findsWidgets);
    expect(find.byType(ListView), findsWidgets);
  });
}
