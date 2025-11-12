import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/drug_config.dart';
import '../models/drug.dart';
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
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drugs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        tablet_dose REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE drug_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drug_name TEXT NOT NULL,
        date_time TEXT NOT NULL,
        dose REAL NOT NULL
      )
    ''');

    await _seedDefaultDrugs(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS drugs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          tablet_dose REAL NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS drug_records(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          drug_name TEXT NOT NULL,
          date_time TEXT NOT NULL,
          dose REAL NOT NULL
        )
      ''');
      await _seedDefaultDrugs(db);
    }
  }

  Future<void> _seedDefaultDrugs(Database db) async {
    for (final drug in DrugConfig.defaultDrugs) {
      await db.insert(
        'drugs',
        drug.toInsertMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // Insert a new drug record
  Future<int> insertDrugRecord(DrugRecord record) async {
    Database db = await database;
    return await db.insert('drug_records', record.toMap());
  }

  // CRUD operations for drugs
  Future<List<Drug>> getAllDrugs() async {
    final db = await database;
    final results = await db.query('drugs', orderBy: 'name COLLATE NOCASE ASC');
    return results.map(Drug.fromMap).toList();
  }

  Future<Drug?> getDrugById(int id) async {
    final db = await database;
    final results = await db.query(
      'drugs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) {
      return null;
    }
    return Drug.fromMap(results.first);
  }

  Future<Drug?> getDrugByName(String name) async {
    final db = await database;
    final results = await db.query(
      'drugs',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (results.isEmpty) {
      return null;
    }
    return Drug.fromMap(results.first);
  }

  Future<int> insertDrug(Drug drug) async {
    final db = await database;
    return await db.insert(
      'drugs',
      drug.toInsertMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateDrug({
    required Drug updatedDrug,
    required String originalName,
  }) async {
    if (updatedDrug.id == null) {
      throw ArgumentError('Drug id is required for update');
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'drugs',
        updatedDrug.toInsertMap(),
        where: 'id = ?',
        whereArgs: [updatedDrug.id],
      );

      if (originalName != updatedDrug.name) {
        await txn.update(
          'drug_records',
          {'drug_name': updatedDrug.name},
          where: 'drug_name = ?',
          whereArgs: [originalName],
        );
      }
    });
  }

  Future<int> deleteDrug(int id) async {
    final db = await database;
    return await db.delete('drugs', where: 'id = ?', whereArgs: [id]);
  }

  // Batch insert multiple drug records
  Future<int> batchInsertDrugRecords(List<DrugRecord> records) async {
    if (records.isEmpty) return 0;

    final db = await database;
    var insertedCount = 0;

    await db.transaction((txn) async {
      for (final record in records) {
        final result = await txn.rawInsert(
          '''
          INSERT INTO drug_records (drug_name, date_time, dose)
          SELECT ?, ?, ?
          WHERE NOT EXISTS (
            SELECT 1 FROM drug_records
            WHERE drug_name = ? AND date_time = ? AND dose = ?
          )
          ''',
          [
            record.drugName,
            record.dateTime.toIso8601String(),
            record.dose,
            record.drugName,
            record.dateTime.toIso8601String(),
            record.dose,
          ],
        );

        if (result > 0) {
          insertedCount++;
        }
      }
    });

    return insertedCount;
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

  Future<List<DrugRecord>> getDrugRecordsPaginated({
    required int limit,
    required int offset,
  }) async {
    final db = await database;
    final results = await db.query(
      'drug_records',
      orderBy: 'date_time DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(DrugRecord.fromMap).toList();
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
