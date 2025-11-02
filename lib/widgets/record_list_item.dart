import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/drug_record.dart';
import '../config/drug_config.dart';

class RecordListItem extends StatelessWidget {
  final DrugRecord record;
  final VoidCallback onDelete;

  const RecordListItem({
    super.key,
    required this.record,
    required this.onDelete,
  });

  Widget _buildDoseLabel(DrugRecord record) {
    final drugConfig = DrugConfig.getDrugByName(record.drugName);
    if (drugConfig != null) {
      final fractionText = drugConfig.convertMgToFraction(record.dose);
      // If it's a fraction like "1/2", add mg equivalent for clarity
      if (fractionText.contains('/')) {
        return Text('$fractionText (${record.dose.toStringAsFixed(1)}mg)');
      }
      // If it's a whole number
      if (fractionText.endsWith('.00')) {
        return Text('${fractionText.split('.')[0]} mg');
      }
    }
    // Default display
    return Text('${record.dose.toStringAsFixed(1)} mg');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            record.drugName[0],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          record.drugName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4.0),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(record.dateTime),
              style: const TextStyle(fontSize: 14.0),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: _buildDoseLabel(record),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
        isThreeLine: false,
      ),
    );
  }
}
