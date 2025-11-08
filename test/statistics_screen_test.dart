import 'package:drugs_taken/models/drug.dart';
import 'package:drugs_taken/screens/statistics_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('statistics screen toggles between data and pie views', (
    tester,
  ) async {
    final now = DateTime(2024, 1, 10);
    final presetKey = 'sevenDays';
    final initialData = StatisticsScreenInitialData(
      presetRanges: {
        presetKey: (
          'Last 7 Days',
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
        ),
      },
      presetTotals: {
        presetKey: {'Diazepam': 10.0},
      },
      drugs: const {'Diazepam': Drug(name: 'Diazepam', tabletDoseMg: 10.0)},
    );

    await tester.pumpWidget(
      MaterialApp(home: StatisticsScreen(initialData: initialData)),
    );
    await tester.pump();

    final toggleFinder = find.byType(ToggleButtons).first;
    final ToggleButtons initialToggle = tester.widget(toggleFinder);
    expect(initialToggle.isSelected, equals(const [true, false]));
    expect(find.byType(PieChart), findsNothing);

    await tester.tap(find.text('Pie').first);
    await tester.pump();

    final ToggleButtons pieToggle = tester.widget(toggleFinder);
    expect(pieToggle.isSelected, equals(const [false, true]));
    expect(find.byType(PieChart), findsWidgets);

    await tester.tap(find.text('Data').first);
    await tester.pump();

    final ToggleButtons backToData = tester.widget(toggleFinder);
    expect(backToData.isSelected, equals(const [true, false]));
    expect(find.byType(PieChart), findsNothing);
  });
}
