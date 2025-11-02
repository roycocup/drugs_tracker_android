import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/drug_record.dart';
import '../database/database_helper.dart';
import '../config/drug_config.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doseController = TextEditingController();

  String? _selectedDrug;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  DrugConfig? get _currentDrugConfig {
    if (_selectedDrug == null) return null;
    return DrugConfig.getDrugByName(_selectedDrug!);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDrug == null || _currentDrugConfig == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a drug')));
        return;
      }

      // Convert dose input to mg (handles fractions like "1/2" or plain numbers)
      final doseString = _doseController.text.trim();
      final doseInMg = _currentDrugConfig!.convertFractionToMg(doseString);
      
      if (doseInMg == null || doseInMg <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid dose (e.g., 1/2, 1/4, or a number)')),
        );
        return;
      }

      // Combine date and time
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final record = DrugRecord(
        drugName: _selectedDrug!,
        dateTime: dateTime,
        dose: doseInMg,
      );

      await DatabaseHelper.instance.insertDrugRecord(record);

      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate a record was added
      }
    }
  }

  @override
  void dispose() {
    _doseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Drug Record')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Drug Selection
            DropdownMenu<String>(
              initialSelection: _selectedDrug,
              label: const Text('Drug'),
              dropdownMenuEntries: DrugConfig.drugs.map((DrugConfig drug) {
                return DropdownMenuEntry<String>(
                  value: drug.name,
                  label: '${drug.name} (${drug.tabletDoseMg.toInt()}mg)',
                );
              }).toList(),
              onSelected: (String? newValue) {
                setState(() {
                  _selectedDrug = newValue;
                });
              },
            ),
            const SizedBox(height: 24.0),

            // Date Selection
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),

            // Time Selection
            InkWell(
              onTap: () => _selectTime(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedTime.format(context)),
                    const Icon(Icons.access_time),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),

            // Dose Input
            TextFormField(
              controller: _doseController,
              decoration: InputDecoration(
                labelText: 'Dose',
                hintText: _currentDrugConfig == null
                    ? 'e.g., 1/2, 1/4, or a number'
                    : 'e.g., 1/2 (${(_currentDrugConfig!.tabletDoseMg / 2).toStringAsFixed(0)}mg), 1/4, or mg',
                helperText: _currentDrugConfig == null
                    ? 'Select a drug first'
                    : '1 tablet = ${_currentDrugConfig!.tabletDoseMg.toInt()}mg',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a dose';
                }
                // Validation will be done in _saveRecord for proper fraction handling
                return null;
              },
            ),
            const SizedBox(height: 32.0),

            // Save Button
            ElevatedButton(
              onPressed: _saveRecord,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text(
                'Save Record',
                style: TextStyle(fontSize: 16.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
