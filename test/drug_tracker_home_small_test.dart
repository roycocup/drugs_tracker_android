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
    userId: 'test-user-id',
  );

  setUp(() async {
    await DatabaseHelper.instance.resetUserContext();
  });

  test('configureForUser completes promptly', () async {
    await DatabaseHelper.instance
        .configureForUser(testIdentity.userId)
        .timeout(const Duration(seconds: 5));
  });

  test('getAllDrugs resolves after configuration', () async {
    await DatabaseHelper.instance.configureForUser(testIdentity.userId);
    final drugs = await DatabaseHelper.instance.getAllDrugs().timeout(
      const Duration(seconds: 5),
    );
    expect(drugs, isNotNull);
  });

  // NOTE: Enable manually when debugging DrugTrackerHome widget hangs.
  testWidgets(
    'DrugTrackerHome builds static shell once database prepared',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseHelper.instance.configureForUser(testIdentity.userId);
      });

      await tester.pumpWidget(
        MaterialApp(home: DrugTrackerHome(initialIdentity: testIdentity)),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Records'), findsWidgets);
      expect(find.text('Statistics'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
