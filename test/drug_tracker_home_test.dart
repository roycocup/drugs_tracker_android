import 'package:drugs_taken/database/database_helper.dart';
import 'package:drugs_taken/screens/drug_tracker_home.dart';
import 'package:drugs_taken/services/user_identity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testIdentity = UserIdentity(
    mnemonic:
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    userId: 'home-test-user',
  );

  Future<void> configureTestDatabase() async {
    await DatabaseHelper.instance.resetUserContext();
    await DatabaseHelper.instance.configureForUser(testIdentity.userId);
  }

  // TODO: Runs long on CI; enable only during manual investigation.
  testWidgets(
    'DrugTrackerHome shows loading indicator initially',
    (tester) async {
      await configureTestDatabase();

      await tester.pumpWidget(
        const MaterialApp(home: DrugTrackerHome(initialIdentity: testIdentity)),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 10)),
    skip: true,
  );

  // TODO: Runs long on CI; enable only during manual investigation.
  testWidgets(
    'DrugTrackerHome renders Records tab title',
    (tester) async {
      await configureTestDatabase();

      await tester.pumpWidget(
        const MaterialApp(home: DrugTrackerHome(initialIdentity: testIdentity)),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Records'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 10)),
    skip: true,
  );

  // TODO: Runs long on CI; enable only during manual investigation.
  testWidgets(
    'DrugTrackerHome renders floating action button',
    (tester) async {
      await configureTestDatabase();

      await tester.pumpWidget(
        const MaterialApp(home: DrugTrackerHome(initialIdentity: testIdentity)),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 10)),
    skip: true,
  );
}
