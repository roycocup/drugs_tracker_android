import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../config/drug_config.dart';
import '../models/drug_record.dart';

class CsvExportService {
  CsvExportService._();

  static String _formatQuantity(DrugRecord record) {
    final config = DrugConfig.getDrugByName(record.drugName);
    if (config != null) {
      final fraction = config.convertMgToFraction(record.dose);
      if (fraction.contains('/')) {
        return fraction;
      }
      if (fraction.endsWith('.00')) {
        return fraction.split('.')[0];
      }
      return fraction;
    }
    return record.dose.toStringAsFixed(1);
  }

  static String generateCsvContent(List<DrugRecord> records) {
    final buffer = StringBuffer()
      ..writeln('Timestamp,Drug name,Quantity,When,Time');
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('HH:mm');

    for (final record in records) {
      final timestamp = record.dateTime.toIso8601String();
      final drugName = _escapeCsv(record.drugName);
      final quantity = _escapeCsv(_formatQuantity(record));
      final when = dateFormatter.format(record.dateTime);
      final time = timeFormatter.format(record.dateTime);

      buffer.writeln('$timestamp,$drugName,$quantity,$when,$time');
    }

    return buffer.toString();
  }

  static Future<String> exportToCsvFile(List<DrugRecord> records) async {
    if (records.isEmpty) {
      throw Exception('There are no records to export.');
    }

    if (kIsWeb) {
      throw Exception('CSV export is not supported on web platforms.');
    }

    final defaultFileName =
        'drug_records_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final csvContent = generateCsvContent(records);
    final csvBytes = Uint8List.fromList(utf8.encode(csvContent));

    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV File',
      fileName: defaultFileName,
      allowedExtensions: ['csv'],
      type: FileType.custom,
      bytes: isMobile ? csvBytes : null,
    );

    if (savePath == null) {
      throw Exception('Export cancelled by user.');
    }

    if (isMobile) {
      return savePath;
    }

    if (!savePath.toLowerCase().endsWith('.csv')) {
      savePath += '.csv';
    }

    final file = File(savePath);
    await file.writeAsBytes(csvBytes, flush: true);

    return file.path;
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }
}

