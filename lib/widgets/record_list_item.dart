import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/drug_record.dart';
import '../theme/app_theme.dart';
import '../utils/relative_date_formatter.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat(
      'yyyy-MM-dd • HH:mm',
    ).format(record.dateTime);
    final relativeDate = RelativeDateFormatter.format(record.dateTime);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 14.0,
          ),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.secondary.withOpacity(0.2),
            child: Text(
              record.drugName[0],
              style: TextStyle(
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          title: Text(
            record.drugName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6.0),
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relativeDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                backgroundColor: colorScheme.primary.withOpacity(0.18),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                label: _buildDoseLabel(record),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          isThreeLine: false,
        ),
      ),
    );
  }
}
