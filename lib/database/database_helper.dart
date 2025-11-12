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
  static const String _legacyUserId = 'default_user';
  String? _userId;

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
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drugs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        tablet_dose REAL NOT NULL,
        UNIQUE(user_id, name)
      )
    ''');

    await db.execute('''
      CREATE TABLE drug_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        drug_name TEXT NOT NULL,
        date_time TEXT NOT NULL,
        dose REAL NOT NULL,
        FOREIGN KEY (user_id, drug_name) REFERENCES drugs(user_id, name)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS drugs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
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
      await _seedDefaultDrugsForUser(db, _legacyUserId);
    }

    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE drugs RENAME TO drugs_old');
        await txn.execute('''
          CREATE TABLE drugs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            tablet_dose REAL NOT NULL,
            UNIQUE(user_id, name)
          )
        ''');

        final oldDrugs = await txn.query('drugs_old');
        for (final row in oldDrugs) {
          final data = {
            'id': row['id'],
            'user_id': _legacyUserId,
            'name': row['name'],
            'tablet_dose': row['tablet_dose'],
          };
          await txn.insert(
            'drugs',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.execute('DROP TABLE drugs_old');

        await txn
            .execute('ALTER TABLE drug_records RENAME TO drug_records_old');
        await txn.execute('''
          CREATE TABLE drug_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            drug_name TEXT NOT NULL,
            date_time TEXT NOT NULL,
            dose REAL NOT NULL,
            FOREIGN KEY (user_id, drug_name) REFERENCES drugs(user_id, name)
          )
        ''');

        final oldRecords = await txn.query('drug_records_old');
        for (final row in oldRecords) {
          final data = {
            'id': row['id'],
            'user_id': _legacyUserId,
            'drug_name': row['drug_name'],
            'date_time': row['date_time'],
            'dose': row['dose'],
          };
          await txn.insert(
            'drug_records',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await txn.execute('DROP TABLE drug_records_old');

        await _seedDefaultDrugsForUser(txn, _legacyUserId);
      });
    }
  }

  Future<void> configureForUser(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final db = await database;

    if (_userId == normalizedUserId) {
      await _seedDefaultDrugsForUser(db, normalizedUserId);
      return;
    }

    if (_userId == null) {
      await _migrateLegacyDataIfNecessary(db, normalizedUserId);
    }

    _userId = normalizedUserId;
    await _seedDefaultDrugsForUser(db, normalizedUserId);
  }

  Future<void> _seedDefaultDrugsForUser(
    DatabaseExecutor db,
    String userId,
  ) async {
    for (final drug in DrugConfig.defaultDrugs) {
      await db.insert(
        'drugs',
        {
          ...drug.toInsertMap(),
          'user_id': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _migrateLegacyDataIfNecessary(
    Database db,
    String targetUserId,
  ) async {
    final legacyDrugsCountResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM drugs
      WHERE user_id IS NULL OR user_id = ?
      ''',
      [_legacyUserId],
    );
    final legacyDrugsCount =
        (legacyDrugsCountResult.first['count'] as int?) ?? 0;

    if (legacyDrugsCount == 0) {
      return;
    }

    final existingForTargetResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM drugs
      WHERE user_id = ?
      ''',
      [targetUserId],
    );
    final existingForTarget =
        (existingForTargetResult.first['count'] as int?) ?? 0;

    if (existingForTarget > 0) {
      return;
    }

    await db.transaction((txn) async {
      await txn.update(
        'drugs',
        {'user_id': targetUserId},
        where: 'user_id IS NULL OR user_id = ?',
        whereArgs: [_legacyUserId],
      );
      await txn.update(
        'drug_records',
        {'user_id': targetUserId},
        where: 'user_id IS NULL OR user_id = ?',
        whereArgs: [_legacyUserId],
      );
    });
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('DatabaseHelper user not configured.');
    }
    return userId;
  }

  // Insert a new drug record
  Future<int> insertDrugRecord(DrugRecord record) async {
    final db = await database;
    final userId = _requireUserId();
    final data = Map<String, dynamic>.from(record.toMap())
      ..remove('id')
      ..['user_id'] = userId;
    return await db.insert('drug_records', data);
  }

  // CRUD operations for drugs
  Future<List<Drug>> getAllDrugs() async {
    final db = await database;
    final userId = _requireUserId();
    final results = await db.query(
      'drugs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return results.map(Drug.fromMap).toList();
  }

  Future<Drug?> getDrugById(int id) async {
    final db = await database;
    final userId = _requireUserId();
    final results = await db.query(
      'drugs',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (results.isEmpty) {
      return null;
    }
    return Drug.fromMap(results.first);
  }

  Future<Drug?> getDrugByName(String name) async {
    final db = await database;
    final userId = _requireUserId();
    final results = await db.query(
      'drugs',
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, name],
      limit: 1,
    );
    if (results.isEmpty) {
      return null;
    }
    return Drug.fromMap(results.first);
  }

  Future<int> insertDrug(Drug drug) async {
    final db = await database;
    final userId = _requireUserId();
    return await db.insert(
      'drugs',
      {
        ...drug.toInsertMap(),
        'user_id': userId,
      },
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
    final userId = _requireUserId();
    await db.transaction((txn) async {
      await txn.update(
        'drugs',
        {
          ...updatedDrug.toInsertMap(),
          'user_id': userId,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [updatedDrug.id, userId],
      );

      if (originalName != updatedDrug.name) {
        await txn.update(
          'drug_records',
          {'drug_name': updatedDrug.name},
          where: 'user_id = ? AND drug_name = ?',
          whereArgs: [userId, originalName],
        );
      }
    });
  }

  Future<int> deleteDrug(int id) async {
    final db = await database;
    final userId = _requireUserId();
    return await db.delete(
      'drugs',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // Batch insert multiple drug records
  Future<int> batchInsertDrugRecords(List<DrugRecord> records) async {
    if (records.isEmpty) return 0;

    final db = await database;
    final userId = _requireUserId();
    var insertedCount = 0;

    await db.transaction((txn) async {
      for (final record in records) {
        final result = await txn.rawInsert(
          '''
          INSERT INTO drug_records (user_id, drug_name, date_time, dose)
          SELECT ?, ?, ?, ?
          WHERE NOT EXISTS (
            SELECT 1 FROM drug_records
            WHERE user_id = ? AND drug_name = ? AND date_time = ? AND dose = ?
          )
          ''',
          [
            userId,
            record.drugName,
            record.dateTime.toIso8601String(),
            record.dose,
            userId,
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
    final db = await database;
    final userId = _requireUserId();
    final List<Map<String, dynamic>> maps = await db.query(
      'drug_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_time DESC',
    );

    return List.generate(maps.length, (i) => DrugRecord.fromMap(maps[i]));
  }

  Future<List<DrugRecord>> getDrugRecordsPaginated({
    required int limit,
    required int offset,
  }) async {
    final db = await database;
    final userId = _requireUserId();
    final results = await db.query(
      'drug_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_time DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(DrugRecord.fromMap).toList();
  }

  // Update a drug record
  Future<int> updateDrugRecord(DrugRecord record) async {
    final db = await database;
    final userId = _requireUserId();
    final data = Map<String, dynamic>.from(record.toMap())..remove('id');
    return await db.update(
      'drug_records',
      data,
      where: 'id = ? AND user_id = ?',
      whereArgs: [record.id, userId],
    );
  }

  // Delete a drug record
  Future<int> deleteDrugRecord(int id) async {
    final db = await database;
    final userId = _requireUserId();
    return await db.delete(
      'drug_records',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<Map<String, double>> getDoseTotalsByDrug({
    required DateTime start,
    required DateTime end,
  }) async {
    if (end.isBefore(start)) {
      return {};
    }

    final db = await database;
    final userId = _requireUserId();
    final results = await db.rawQuery(
      '''
      SELECT drug_name, SUM(dose) as total_dose
      FROM drug_records
      WHERE user_id = ? AND date_time BETWEEN ? AND ?
      GROUP BY drug_name
      ORDER BY drug_name ASC
      ''',
      [userId, start.toIso8601String(), end.toIso8601String()],
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
