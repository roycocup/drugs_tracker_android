import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:drugs_taken/database/database_helper.dart';
import 'package:drugs_taken/models/drug.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function() onImport;
  final Future<void> Function() onExport;
  final Future<void> Function()? onDrugsChanged;

  const SettingsScreen({
    super.key,
    required this.onImport,
    required this.onExport,
    this.onDrugsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                if (dialogContext.mounted) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drug added successfully')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${drug.name} deleted')),
      );
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
    final cardColor = Colors.white.withValues(alpha: 0.08);
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
            color: Colors.white.withValues(alpha: 0.08),
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

