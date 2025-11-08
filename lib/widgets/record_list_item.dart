import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/drug.dart';
import '../models/drug_record.dart';
import '../theme/app_theme.dart';
import '../utils/relative_date_formatter.dart';

class RecordListItem extends StatelessWidget {
  final DrugRecord record;
  final Drug? drug;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const RecordListItem({
    super.key,
    required this.record,
    this.drug,
    required this.onDelete,
    required this.onEdit,
  });

  Widget _buildDoseLabel() {
    if (drug != null) {
      final fractionText = drug!.convertMgToFraction(record.dose);
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
    final dismissibleKey = ValueKey(
      record.id ??
          '${record.drugName}-${record.dateTime.toIso8601String()}-${record.dose}',
    );
    return Slidable(
      key: dismissibleKey,
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: BorderRadius.circular(20),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
      child: Card(
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
            // leading: CircleAvatar(
            //   radius: 26,
            //   backgroundColor: colorScheme.secondary.withValues(alpha: 0.2),
            //   child: Text(
            //     record.drugName[0],
            //     style: TextStyle(
            //       color: colorScheme.secondary,
            //       fontWeight: FontWeight.bold,
            //       fontSize: 22,
            //     ),
            //   ),
            // ),
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
                  relativeDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            trailing: Chip(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.18),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              label: _buildDoseLabel(),
            ),
            isThreeLine: false,
          ),
        ),
      ),
    );
  }
}
