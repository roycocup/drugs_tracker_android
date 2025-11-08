import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/drug.dart';

class StatisticsScreenInitialData {
  final Map<String, (String label, DateTimeRange range)> presetRanges;
  final Map<String, Map<String, double>> presetTotals;
  final Map<String, Drug> drugs;
  final Map<String, double>? customTotals;
  final DateTimeRange? customRange;
  final bool showPieForCustomRange;
  final Map<String, bool>? showPieByPresetKey;

  const StatisticsScreenInitialData({
    required this.presetRanges,
    required this.presetTotals,
    required this.drugs,
    this.customTotals,
    this.customRange,
    this.showPieForCustomRange = false,
    this.showPieByPresetKey,
  });
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.initialData});

  final StatisticsScreenInitialData? initialData;

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
  Map<String, Drug> _drugByName = {};
  Map<String, bool> _showPieForPreset = {};
  bool _showPieForCustomRange = false;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    if (initialData != null) {
      _presetRanges = Map.unmodifiable(initialData.presetRanges);
      _presetTotals = initialData.presetTotals.map(
        (key, value) => MapEntry(key, Map<String, double>.from(value)),
      );
      _drugByName = Map<String, Drug>.from(initialData.drugs);
      _customTotals = initialData.customTotals == null
          ? null
          : Map<String, double>.from(initialData.customTotals!);
      _customRange = initialData.customRange;
      _showPieForPreset = initialData.showPieByPresetKey == null
          ? {for (final key in _presetRanges.keys) key: false}
          : Map<String, bool>.from(initialData.showPieByPresetKey!);
      _showPieForCustomRange = initialData.showPieForCustomRange;
      _isLoading = false;
      return;
    }
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
    final drugs = await DatabaseHelper.instance.getAllDrugs();
    final drugMap = {for (final drug in drugs) drug.name: drug};

    for (final entry in ranges.entries) {
      totals[entry.key] = await DatabaseHelper.instance.getDoseTotalsByDrug(
        start: entry.value.$2.start,
        end: entry.value.$2.end,
      );
    }

    if (!mounted) {
      return;
    }

    final updatedShowPie = {
      for (final key in ranges.keys) key: _showPieForPreset[key] ?? false,
    };

    setState(() {
      _drugByName = drugMap;
      _presetRanges = ranges;
      _presetTotals = totals;
      _showPieForPreset = updatedShowPie;
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
    final config = _drugByName[drugName];
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

  Color _colorForIndex(int index) {
    final palette = Colors.primaries;
    final materialColor = palette[index % palette.length];
    return materialColor[400] ?? materialColor;
  }

  Widget _buildLegend(List<({String name, double value, Color color})> data) {
    return Column(
      children: data
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(item.name),
              trailing: Text(_formatDose(item.name, item.value)),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPieChartWidget(
    List<({String name, double value, Color color})> data,
    double total,
  ) {
    final textStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ) ??
        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 32,
        borderData: FlBorderData(show: false),
        sections: data
            .map(
              (item) => PieChartSectionData(
                value: item.value,
                color: item.color,
                radius: 60,
                title: item.value / total >= 0.05
                    ? '${(item.value / total * 100).round()}%'
                    : '',
                titleStyle: textStyle,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPieLayout(
    List<({String name, double value, Color color})> data,
    double total,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        final availableWidth = constraints.maxWidth;
        final rawChartSize = availableWidth * 0.45;
        final chartSize = rawChartSize
            .clamp(140.0, isWide ? 220.0 : 200.0)
            .toDouble();
        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: _buildPieChartWidget(data, total),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 24.0),
                child: chart,
              ),
              Expanded(child: _buildLegend(data)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(child: chart),
            ),
            const SizedBox(height: 12),
            _buildLegend(data),
          ],
        );
      },
    );
  }

  Widget _buildTotalsContent(
    List<MapEntry<String, double>> entries,
    bool showPie,
  ) {
    if (entries.isEmpty) {
      return const Text('No records in this range');
    }

    final data = entries.asMap().entries.map((indexedEntry) {
      final index = indexedEntry.key;
      final entry = indexedEntry.value;
      return (
        name: entry.key,
        value: entry.value,
        color: _colorForIndex(index),
      );
    }).toList();

    final total = data.fold<double>(0, (sum, item) => sum + item.value);

    if (total <= 0) {
      return const Text('No records in this range');
    }

    if (showPie) {
      return _buildPieLayout(data, total);
    }

    return _buildLegend(data);
  }

  Widget _buildViewToggle({
    required bool showPie,
    required ValueChanged<bool> onChanged,
  }) {
    return ToggleButtons(
      borderRadius: BorderRadius.circular(8.0),
      constraints: const BoxConstraints(minHeight: 32, minWidth: 72),
      isSelected: [!showPie, showPie],
      onPressed: (index) => onChanged(index == 1),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('Data'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Text('Pie'),
        ),
      ],
    );
  }

  Widget _buildTotalsCard({
    required String title,
    required DateTimeRange range,
    required Map<String, double> totals,
    required bool showPie,
    required ValueChanged<bool> onShowPieChanged,
  }) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasData = entries.any((entry) => entry.value > 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        _formatRange(range),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (hasData)
                  _buildViewToggle(
                    showPie: showPie,
                    onChanged: onShowPieChanged,
                  ),
              ],
            ),
            const SizedBox(height: 12.0),
            if (!hasData)
              const Text('No records in this range')
            else
              _buildTotalsContent(entries, showPie),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTotalsSection() {
    if (_customTotals == null || _customTotals!.isEmpty) {
      return const Text('No records in this range');
    }

    final entries = _customTotals!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasData = entries.any((entry) => entry.value > 0);

    if (!hasData) {
      return const Text('No records in this range');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _buildViewToggle(
            showPie: _showPieForCustomRange,
            onChanged: (value) {
              setState(() {
                _showPieForCustomRange = value;
              });
            },
          ),
        ),
        const SizedBox(height: 12.0),
        _buildTotalsContent(entries, _showPieForCustomRange),
      ],
    );
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
              showPie: _showPieForPreset[entry.key] ?? false,
              onShowPieChanged: (value) {
                setState(() {
                  _showPieForPreset = {..._showPieForPreset, entry.key: value};
                });
              },
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
                    _buildCustomTotalsSection(),
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
