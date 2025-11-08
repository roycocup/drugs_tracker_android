import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/drug_config.dart';
import '../database/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DateFormat _rangeFormatter = DateFormat.yMMMd();
  bool _isLoading = true;
  bool _isCustomLoading = false;
  DateTimeRange? _customRange;
  Map<String, (String label, DateTimeRange range)> _presetRanges = {};
  Map<String, Map<String, double>> _presetTotals = {};
  Map<String, double>? _customTotals;

  @override
  void initState() {
    super.initState();
    _loadPresetStatistics();
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }

  Map<String, (String label, DateTimeRange range)> _buildPresetRanges(
    DateTime now,
  ) {
    final end = _endOfDay(now);
    return {
      'oneWeek': (
        'Last 7 Days',
        DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 6))),
          end: end,
        ),
      ),
      'fourWeeks': (
        'Last 4 Weeks',
        DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 27))),
          end: end,
        ),
      ),
      'oneMonth': (
        'Last 1 Month',
        DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 29))),
          end: end,
        ),
      ),
      'threeMonths': (
        'Last 3 Months',
        DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 89))),
          end: end,
        ),
      ),
    };
  }

  Future<void> _loadPresetStatistics() async {
    setState(() {
      _isLoading = true;
    });

    final ranges = _buildPresetRanges(DateTime.now());
    final totals = <String, Map<String, double>>{};

    for (final entry in ranges.entries) {
      totals[entry.key] = await DatabaseHelper.instance.getDoseTotalsByDrug(
        start: entry.value.$2.start,
        end: entry.value.$2.end,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _presetRanges = ranges;
      _presetTotals = totals;
      _isLoading = false;
    });
  }

  String _formatRange(DateTimeRange range) {
    final startText = _rangeFormatter.format(range.start);
    final endText = _rangeFormatter.format(range.end);
    if (startText == endText) {
      return startText;
    }
    return '$startText – $endText';
  }

  String _formatDose(String drugName, double totalMg) {
    final config = DrugConfig.getDrugByName(drugName);
    final mgText = '${totalMg.toStringAsFixed(1)} mg';

    if (config == null || config.tabletDoseMg <= 0) {
      return mgText;
    }

    final tablets = totalMg / config.tabletDoseMg;
    if ((tablets - tablets.round()).abs() < 0.01) {
      final rounded = tablets.round();
      final suffix = rounded == 1 ? 'tablet' : 'tablets';
      return '$mgText ($rounded $suffix)';
    }

    return '$mgText (${tablets.toStringAsFixed(2)} tablets)';
  }

  Widget _buildTotalsCard({
    required String title,
    required DateTimeRange range,
    required Map<String, double> totals,
  }) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4.0),
            Text(
              _formatRange(range),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12.0),
            if (entries.isEmpty)
              const Text('No records in this range')
            else
              ...entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  trailing: Text(_formatDose(entry.key, entry.value)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCustomTotalsContent() {
    if (_customTotals == null || _customTotals!.isEmpty) {
      return const [Text('No records in this range')];
    }

    final entries = _customTotals!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            trailing: Text(_formatDose(entry.key, entry.value)),
          ),
        )
        .toList();
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 6)),
            end: DateTime.now(),
          ),
    );

    if (picked == null) {
      return;
    }

    final normalizedRange = DateTimeRange(
      start: _startOfDay(picked.start),
      end: _endOfDay(picked.end),
    );

    setState(() {
      _customRange = normalizedRange;
      _isCustomLoading = true;
    });

    final totals = await DatabaseHelper.instance.getDoseTotalsByDrug(
      start: normalizedRange.start,
      end: normalizedRange.end,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _customTotals = totals;
      _isCustomLoading = false;
    });
  }

  Future<void> _refresh() async {
    await _loadPresetStatistics();
    if (_customRange != null) {
      final totals = await DatabaseHelper.instance.getDoseTotalsByDrug(
        start: _customRange!.start,
        end: _customRange!.end,
      );
      if (mounted) {
        setState(() {
          _customTotals = totals;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          for (final entry in _presetRanges.entries)
            _buildTotalsCard(
              title: entry.value.$1,
              range: entry.value.$2,
              totals: _presetTotals[entry.key] ?? const <String, double>{},
            ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Range',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12.0),
                  ElevatedButton.icon(
                    onPressed: _isCustomLoading ? null : _selectCustomRange,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Select Date Range'),
                  ),
                  if (_isCustomLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: LinearProgressIndicator(),
                    )
                  else if (_customRange == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: Text('Choose a range to see totals'),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        _formatRange(_customRange!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    ..._buildCustomTotalsContent(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
