import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../models/drug_record.dart';

class CsvImportService {
  /// Parses a CSV file and converts it to DrugRecord objects
  /// Expected headers: "Timestamp", "Drug name", "Quantity", "When", "Time"
  ///
  /// CSV format:
  /// - "When" is date in dd/mm/yyyy format
  /// - "Time" is time in HH:MM format
  /// - "Timestamp" is ignored if "When" and "Time" are provided
  /// - "Quantity" can be in fraction format (e.g., "1/2", "1/4") or plain number
  static Future<List<DrugRecord>> parseCsvFile(String csvContent) async {
    final lines = csvContent
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final drugCatalog = await DatabaseHelper.instance.getAllDrugs();
    final drugByName = {for (final drug in drugCatalog) drug.name: drug};

    // Parse header
    final headerLine = lines[0].trim();
    final headers = _parseCsvLine(headerLine);

    // Find column indices
    final timestampIndex = headers.indexOf('Timestamp');
    final drugNameIndex = headers.indexOf('Drug name');
    final quantityIndex = headers.indexOf('Quantity');
    final whenIndex = headers.indexOf('When');
    final timeIndex = headers.indexOf('Time');

    if (drugNameIndex == -1 || quantityIndex == -1) {
      throw Exception('Required columns "Drug name" and "Quantity" not found');
    }

    final List<DrugRecord> records = [];

    // Parse data rows
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final values = _parseCsvLine(line);

        // Extract drug name
        if (drugNameIndex >= values.length) continue;
        final drugName = values[drugNameIndex].trim();
        if (drugName.isEmpty) continue;

        // Extract quantity
        if (quantityIndex >= values.length) continue;
        final quantity = values[quantityIndex].trim();
        if (quantity.isEmpty) continue;

        // Determine the drug configuration
        final drugConfig = drugByName[drugName];
        if (drugConfig == null) {
          throw Exception('Unknown drug: $drugName');
        }

        // Convert quantity to mg
        final doseInMg = drugConfig.convertFractionToMg(quantity);
        if (doseInMg == null || doseInMg <= 0) {
          throw Exception('Invalid quantity format: $quantity');
        }

        // Extract date and time
        DateTime dateTime;

        if (whenIndex != -1 &&
            timeIndex != -1 &&
            whenIndex < values.length &&
            timeIndex < values.length) {
          // Use "When" and "Time" columns
          final dateStr = values[whenIndex].trim();
          final timeStr = values[timeIndex].trim();

          if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
            dateTime = _parseDateTime(dateStr, timeStr);
          } else if (timestampIndex != -1 && timestampIndex < values.length) {
            // Fallback to Timestamp column
            final timestamp = values[timestampIndex].trim();
            dateTime = DateTime.parse(timestamp);
          } else {
            // Use current date/time if no valid datetime found
            dateTime = DateTime.now();
          }
        } else if (timestampIndex != -1 && timestampIndex < values.length) {
          // Use Timestamp column
          final timestamp = values[timestampIndex].trim();
          dateTime = DateTime.parse(timestamp);
        } else {
          // Use current date/time if no valid datetime found
          dateTime = DateTime.now();
        }

        // Create record
        final record = DrugRecord(
          drugName: drugName,
          dateTime: dateTime,
          dose: doseInMg,
        );

        records.add(record);
      } catch (e) {
        // Log error but continue parsing other rows
        print('Error parsing row ${i + 1}: $e');
      }
    }

    return records;
  }

  /// Parses a CSV line handling quoted values
  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          current.write('"');
          i++;
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // End of field
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }

    // Add last field
    result.add(current.toString());

    return result;
  }

  /// Parses date in dd/mm/yyyy format and time in HH:MM format
  static DateTime _parseDateTime(String dateStr, String timeStr) {
    // Parse date: dd/mm/yyyy
    final dateParts = dateStr.split('/');
    if (dateParts.length != 3) {
      throw Exception('Invalid date format: $dateStr. Expected dd/mm/yyyy');
    }

    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);

    // Parse time: HH:MM
    final timeParts = timeStr.split(':');
    if (timeParts.length < 2) {
      throw Exception('Invalid time format: $timeStr. Expected HH:MM');
    }

    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(year, month, day, hour, minute);
  }

  /// Imports records from a CSV file picked by the user
  static Future<List<DrugRecord>> importFromCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    final fileContent = await File(result.files.single.path!).readAsString();

    return await parseCsvFile(fileContent);
  }
}
