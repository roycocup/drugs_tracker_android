import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'models/drug_record.dart';
import 'screens/add_record_screen.dart';
import 'widgets/record_list_item.dart';
import 'services/csv_import_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drug Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DrugTrackerHome(),
    );
  }
}

class DrugTrackerHome extends StatefulWidget {
  const DrugTrackerHome({super.key});

  @override
  State<DrugTrackerHome> createState() => _DrugTrackerHomeState();
}

class _DrugTrackerHomeState extends State<DrugTrackerHome> {
  List<DrugRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
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

      // Batch insert records
      await DatabaseHelper.instance.batchInsertDrugRecords(records);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${records.length} record(s)'),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Drug Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: _importFromCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'No drug records yet',
                    style: TextStyle(fontSize: 18.0, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Tap the + button to add a record',
                    style: TextStyle(fontSize: 14.0, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: ListView.builder(
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return RecordListItem(
                    record: record,
                    onDelete: () => _deleteRecord(record),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewRecord,
        tooltip: 'Add Drug Record',
        child: const Icon(Icons.add),
      ),
    );
  }
}
