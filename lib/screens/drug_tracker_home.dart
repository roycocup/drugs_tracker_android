import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:drugs_taken/database/database_helper.dart';
import 'package:drugs_taken/models/drug.dart';
import 'package:drugs_taken/models/drug_record.dart';
import 'package:drugs_taken/screens/add_record_screen.dart';
import 'package:drugs_taken/screens/settings_screen.dart';
import 'package:drugs_taken/screens/statistics_screen.dart';
import 'package:drugs_taken/services/csv_export_service.dart';
import 'package:drugs_taken/services/csv_import_service.dart';
import 'package:drugs_taken/theme/app_theme.dart';
import 'package:drugs_taken/widgets/record_list_item.dart';

class DrugTrackerHome extends StatefulWidget {
  const DrugTrackerHome({super.key});

  @override
  State<DrugTrackerHome> createState() => _DrugTrackerHomeState();
}

class _DrugTrackerHomeState extends State<DrugTrackerHome>
    with SingleTickerProviderStateMixin {
  List<DrugRecord> _records = [];
  bool _isLoading = true;
  Map<String, Drug> _drugLookup = {};
  late final TabController _tabController;
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;
  bool _hasMoreRecords = true;
  static const int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted && !_tabController.indexIsChanging) {
          setState(() {});
        }
      });
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadDrugs();
    _loadRecords();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrugs() async {
    final drugs = await DatabaseHelper.instance.getAllDrugs();
    if (!mounted) {
      return;
    }
    setState(() {
      _drugLookup = {for (final drug in drugs) drug.name: drug};
    });
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMoreRecords = true;
      _records = [];
    });

    final records = await DatabaseHelper.instance.getDrugRecordsPaginated(
      limit: _pageSize,
      offset: 0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _records = records;
      _isLoading = false;
      _hasMoreRecords = records.length == _pageSize;
    });
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoading || _isLoadingMore || !_hasMoreRecords) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final records = await DatabaseHelper.instance.getDrugRecordsPaginated(
      limit: _pageSize,
      offset: _records.length,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _records = [..._records, ...records];
      _isLoadingMore = false;
      if (records.length < _pageSize) {
        _hasMoreRecords = false;
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMoreRecords) {
      return;
    }

    if (_scrollController.position.extentAfter < 200) {
      _loadMoreRecords();
    }
  }

  Future<void> _deleteRecord(DrugRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete this ${record.drugName} record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null) {
      await DatabaseHelper.instance.deleteDrugRecord(record.id!);
      _loadRecords();
    }
  }

  Future<void> _addNewRecord() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddRecordScreen()),
    );

    if (result == true) {
      _loadRecords();
    }
  }

  Future<void> _editRecord(DrugRecord record) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecordScreen(
          record: record,
        ),
      ),
    );

    if (result == true) {
      _loadRecords();
    }
  }

  Future<void> _importFromCsv() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final records = await CsvImportService.importFromCsvFile();

      if (records.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid records found in CSV file')),
          );
        }
        return;
      }

      final insertedCount =
          await DatabaseHelper.instance.batchInsertDrugRecords(records);

      if (mounted) {
        Navigator.pop(context);
        final skippedCount = records.length - insertedCount;
        final message = skippedCount > 0
            ? 'Imported $insertedCount record(s). Skipped $skippedCount duplicate(s).'
            : 'Successfully imported $insertedCount record(s).';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _loadRecords();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCsv() async {
    if (_records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No records available to export')),
        );
      }
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final exportedPath = await CsvExportService.exportToCsvFile(
        List.of(_records),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported to $exportedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e.toString().contains('cancelled by user')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('CSV export cancelled')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildRecordsContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return _EmptyState(onAddRecord: _addNewRecord);
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        controller: _scrollController,
        itemCount: _records.length + (_hasMoreRecords ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _records.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : const SizedBox(height: 24),
              ),
            );
          }

          final record = _records[index];
          return RecordListItem(
            record: record,
            drug: _drugLookup[record.drugName],
            onDelete: () => _deleteRecord(record),
            onEdit: () => _editRecord(record),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 24,
          title: SafeArea(
            bottom: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/logo.svg',
                  height: 32,
                  semanticsLabel: 'Drugs Taken brand',
                ),
                const SizedBox(width: 12),
                const Text(
                  'Drug Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.appBarGradient,
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.primary,
                      ],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.list), text: 'Records'),
                    Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
                    Tab(icon: Icon(Icons.settings), text: 'Settings'),
                  ],
                ),
              ),
            ),
          ),
          actions: const [SizedBox(width: 12)],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildRecordsContent(),
              ),
            ),
            const SafeArea(child: StatisticsScreen()),
            SafeArea(
              child: SettingsScreen(
                onImport: _importFromCsv,
                onExport: _exportToCsv,
                onDrugsChanged: _loadDrugs,
              ),
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: _addNewRecord,
                icon: const Icon(Icons.add, size: 26),
                label: const Text('Add Record'),
              )
            : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddRecord;

  const _EmptyState({required this.onAddRecord});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/logo.svg',
                    height: 72,
                    semanticsLabel: 'Drugs Taken brand',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No drug records yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bring your treatment history into focus by adding your first record.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: onAddRecord,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add your first record',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
