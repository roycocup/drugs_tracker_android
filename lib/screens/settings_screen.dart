import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'package:drugs_taken/database/database_helper.dart';
import 'package:drugs_taken/models/drug.dart';
import 'package:drugs_taken/services/user_identity_service.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function() onImport;
  final Future<void> Function() onExport;
  final Future<void> Function()? onDrugsChanged;
  final UserIdentity identity;
  final Future<UserIdentity> Function(String mnemonic) onImportMnemonic;
  final Future<UserIdentity> Function() onLogout;

  const SettingsScreen({
    super.key,
    required this.onImport,
    required this.onExport,
    this.onDrugsChanged,
    required this.identity,
    required this.onImportMnemonic,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoadingDrugs = true;
  List<Drug> _drugs = [];
  late UserIdentity _identity;

  @override
  void initState() {
    super.initState();
    _identity = widget.identity;
    _loadDrugs();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.userId != widget.identity.userId ||
        oldWidget.identity.mnemonic != widget.identity.mnemonic) {
      setState(() {
        _identity = widget.identity;
      });
      _loadDrugs();
    }
  }

  Future<void> _promptImportMnemonic() async {
    final controller = TextEditingController();
    String? errorText;
    bool isSubmitting = false;
    UserIdentity? importedIdentity;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSubmit() async {
              final mnemonic = controller.text.trim();
              if (mnemonic.isEmpty) {
                setDialogState(() {
                  errorText = 'Mnemonic is required.';
                });
                return;
              }
              setDialogState(() {
                errorText = null;
                isSubmitting = true;
              });
              try {
                final identity = await widget.onImportMnemonic(mnemonic);
                importedIdentity = identity;
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on InvalidMnemonicException catch (error) {
                setDialogState(() {
                  errorText = error.message;
                  isSubmitting = false;
                });
              } catch (_) {
                setDialogState(() {
                  errorText = 'Failed to import mnemonic. Please try again.';
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Import Mnemonic'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste the 12-word mnemonic associated with your account.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Mnemonic',
                      hintText: 'example: word1 word2 ... word12',
                      errorText: errorText,
                    ),
                    enabled: !isSubmitting,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : handleSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && importedIdentity != null && mounted) {
      setState(() {
        _identity = importedIdentity!;
      });
      await _loadDrugs();
      if (widget.onDrugsChanged != null) {
        await widget.onDrugsChanged!();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mnemonic imported successfully')),
      );
    }
  }

  Future<void> _copyToClipboard(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Logging out will generate a new mnemonic for this device. '
          'Keep a copy of your current mnemonic if you want to return to this account later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final identity = await widget.onLogout();
      if (!mounted) {
        return;
      }
      setState(() {
        _identity = identity;
      });
      await _loadDrugs();
      if (widget.onDrugsChanged != null) {
        await widget.onDrugsChanged!();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out. A new mnemonic was created.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to log out. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildIdentityCard(BuildContext context) {
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
              'Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Store this mnemonic safely. You will need it to access your data on another device.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      _identity.mnemonic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy mnemonic',
                    onPressed: () => _copyToClipboard(
                      _identity.mnemonic,
                      'Mnemonic copied to clipboard',
                    ),
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'User ID',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      _identity.userId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy user ID',
                    onPressed: () => _copyToClipboard(
                      _identity.userId,
                      'User ID copied to clipboard',
                    ),
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _promptImportMnemonic,
              icon: const Icon(Icons.key),
              label: const Text('Import Mnemonic'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
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
          _buildIdentityCard(context),
          const SizedBox(height: 16),
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
