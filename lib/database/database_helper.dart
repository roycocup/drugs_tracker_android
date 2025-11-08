import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/drug_record.dart';

class DatabaseHelper {
  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  static bool _initialized = false;

  Future<Database> get database async {
    // Initialize database factory once for desktop platforms
    if (!_initialized) {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        databaseFactory = databaseFactoryFfi;
      }
      _initialized = true;
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'drugs_database.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drug_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drug_name TEXT NOT NULL,
        date_time TEXT NOT NULL,
        dose REAL NOT NULL
      )
    ''');
  }

  // Insert a new drug record
  Future<int> insertDrugRecord(DrugRecord record) async {
    Database db = await database;
    return await db.insert('drug_records', record.toMap());
  }

  // Batch insert multiple drug records
  Future<void> batchInsertDrugRecords(List<DrugRecord> records) async {
    if (records.isEmpty) return;

    Database db = await database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert('drug_records', record.toMap());
    }

    await batch.commit(noResult: true);
  }

  // Query all drug records, ordered by date_time descending (most recent first)
  Future<List<DrugRecord>> getAllDrugRecords() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drug_records',
      orderBy: 'date_time DESC',
    );

    return List.generate(maps.length, (i) => DrugRecord.fromMap(maps[i]));
  }

  // Update a drug record
  Future<int> updateDrugRecord(DrugRecord record) async {
    Database db = await database;
    return await db.update(
      'drug_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // Delete a drug record
  Future<int> deleteDrugRecord(int id) async {
    Database db = await database;
    return await db.delete('drug_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getDoseTotalsByDrug({
    required DateTime start,
    required DateTime end,
  }) async {
    if (end.isBefore(start)) {
      return {};
    }

    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT drug_name, SUM(dose) as total_dose
      FROM drug_records
      WHERE date_time BETWEEN ? AND ?
      GROUP BY drug_name
      ORDER BY drug_name ASC
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final totals = <String, double>{};
    for (final row in results) {
      final name = row['drug_name'] as String?;
      final total = row['total_dose'] as num?;
      if (name != null && total != null) {
        totals[name] = total.toDouble();
      }
    }

    return totals;
  }
}
