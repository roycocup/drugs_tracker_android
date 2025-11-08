import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database/database_helper.dart';
import 'models/drug.dart';
import 'models/drug_record.dart';
import 'services/csv_export_service.dart';
import 'services/csv_import_service.dart';
import 'screens/add_record_screen.dart';
import 'screens/statistics_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/record_list_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drug Tracker',
      theme: AppTheme.buildTheme(),
      home: const DrugTrackerHome(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted && !_tabController.indexIsChanging) {
          setState(() {});
        }
      });
    _loadDrugs();
    _loadRecords();
  }

  @override
  void dispose() {
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
    });

    final records = await DatabaseHelper.instance.getAllDrugRecords();

    setState(() {
      _records = records;
      _isLoading = false;
    });
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

  Future<void> _importFromCsv() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Import records from CSV
      final records = await CsvImportService.importFromCsvFile();

      if (records.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid records found in CSV file')),
          );
        }
        return;
      }

      // Batch insert records, skipping duplicates
      final insertedCount = await DatabaseHelper.instance
          .batchInsertDrugRecords(records);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
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
        Navigator.pop(context); // Close loading dialog
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
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV exported to $exportedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
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
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return RecordListItem(
            record: record,
            drug: _drugLookup[record.drugName],
            onDelete: () => _deleteRecord(record),
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
          title: const SafeArea(bottom: false, child: SizedBox(height: 36)),
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
                  color: Colors.white.withOpacity(0.08),
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
              child: _SettingsTab(
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
                  Icon(
                    Icons.medication_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.secondary,
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

class _SettingsTab extends StatefulWidget {
  final Future<void> Function() onImport;
  final Future<void> Function() onExport;
  final Future<void> Function()? onDrugsChanged;

  const _SettingsTab({
    required this.onImport,
    required this.onExport,
    this.onDrugsChanged,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _isLoadingDrugs = true;
  List<Drug> _drugs = [];

  @override
  void initState() {
    super.initState();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    setState(() {
      _isLoadingDrugs = true;
    });

    final drugs = await DatabaseHelper.instance.getAllDrugs();

    if (!mounted) {
      return;
    }

    setState(() {
      _drugs = drugs;
      _isLoadingDrugs = false;
    });
  }

  Future<void> _refreshDrugs() async {
    await _loadDrugs();
    if (widget.onDrugsChanged != null) {
      await widget.onDrugsChanged!();
    }
  }

  Future<bool?> _showDrugForm({Drug? drug}) async {
    final nameController = TextEditingController(text: drug?.name ?? '');
    final doseController = TextEditingController(
      text: drug != null
          ? (drug.tabletDoseMg % 1 == 0
                ? drug.tabletDoseMg.toStringAsFixed(0)
                : drug.tabletDoseMg.toStringAsFixed(2))
          : '',
    );
    final formKey = GlobalKey<FormState>();
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSubmit() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final name = nameController.text.trim();
              final dose = double.parse(doseController.text.trim());

              try {
                if (drug == null) {
                  await DatabaseHelper.instance.insertDrug(
                    Drug(name: name, tabletDoseMg: dose),
                  );
                } else {
                  await DatabaseHelper.instance.updateDrug(
                    updatedDrug: drug.copyWith(name: name, tabletDoseMg: dose),
                    originalName: drug.name,
                  );
                }
                if (mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on DatabaseException catch (e) {
                if (e.isUniqueConstraintError()) {
                  setDialogState(() {
                    errorText = 'A drug with this name already exists.';
                  });
                } else {
                  setDialogState(() {
                    errorText = 'Failed to save drug. Please try again.';
                  });
                }
              } catch (_) {
                setDialogState(() {
                  errorText = 'Failed to save drug. Please try again.';
                });
              }
            }

            return AlertDialog(
              title: Text(drug == null ? 'Add Drug' : 'Edit Drug'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: doseController,
                      decoration: const InputDecoration(
                        labelText: '1 tablet dose (mg)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Dose is required';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: handleSubmit,
                  child: Text(drug == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addDrug() async {
    final result = await _showDrugForm();
    if (result == true) {
      await _refreshDrugs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Drug added successfully')));
    }
  }

  Future<void> _editDrug(Drug drug) async {
    final result = await _showDrugForm(drug: drug);
    if (result == true) {
      await _refreshDrugs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drug updated successfully')),
      );
    }
  }

  Future<void> _deleteDrug(Drug drug) async {
    if (drug.id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Drug'),
        content: Text(
          'Are you sure you want to delete ${drug.name}? '
          'Existing records will keep this drug name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteDrug(drug.id!);
      await _refreshDrugs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${drug.name} deleted')));
    }
  }

  Widget _buildDrugTile(Drug drug) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        drug.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        '1 tablet = ${drug.tabletDoseMg.toStringAsFixed(1)} mg',
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit',
            onPressed: () => _editDrug(drug),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: () => _deleteDrug(drug),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugManagementCard(BuildContext context) {
    final cardColor = Colors.white.withOpacity(0.08);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drug Catalog',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingDrugs)
              const Center(child: CircularProgressIndicator())
            else if (_drugs.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No drugs available. Add your first drug to use it when recording doses.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addDrug,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Drug'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _drugs.length; i++) ...[
                    _buildDrugTile(_drugs[i]),
                    if (i != _drugs.length - 1)
                      const Divider(height: 16, color: Colors.white12),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _addDrug,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Drug'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildDrugManagementCard(context),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Management',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async => widget.onImport(),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import from CSV'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async => widget.onExport(),
                    icon: const Icon(Icons.download),
                    label: const Text('Export to CSV'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
