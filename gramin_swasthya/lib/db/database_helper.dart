import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart' as plaintext;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static const _databaseName = "GraminSwasthya.db";
  static const _databaseVersion = 3;
  static const _encryptionKeyName = 'gramin_swasthya_sqlcipher_key';
  static const _plaintextBackupSuffix = '.plaintext-backup';
  static const _secureStorage = FlutterSecureStorage();

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static dynamic _database;
  static final MockDatabase _mockDatabase = MockDatabase();

  Future<dynamic> get database async {
    if (kIsWeb) {
      return _mockDatabase;
    }
    if (_database != null) return _database!;
    _database = await _initEncryptedDatabase();
    return _database!;
  }

  Future<cipher.Database> _initEncryptedDatabase() async {
    final path = join(await cipher.getDatabasesPath(), _databaseName);
    var key = await _secureStorage.read(key: _encryptionKeyName);
    final databaseFile = File(path);

    if (key == null) {
      key = _generateKey();
      if (await databaseFile.exists()) {
        await _migratePlaintextDatabase(path, key);
      }
      await _secureStorage.write(key: _encryptionKeyName, value: key);
    }

    return cipher.openDatabase(
      path,
      password: key,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  String _generateKey() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _migratePlaintextDatabase(String path, String key) async {
    final oldDatabase = await plaintext.openDatabase(path, version: 2);
    final tables = [
      'family_members',
      'bp_readings',
      'sugar_readings',
      'weight_entries',
      'medical_reports',
      'medicines',
      'medicine_log',
    ];
    final snapshot = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      snapshot[table] = await oldDatabase.query(table);
    }
    await oldDatabase.close();

    final backupPath = '$path$_plaintextBackupSuffix';
    final backupFile = File(backupPath);
    if (await backupFile.exists()) await backupFile.delete();
    await databaseFile(path).rename(backupPath);

    try {
      final encrypted = await cipher.openDatabase(
        path,
        password: key,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
      for (final table in tables) {
        for (final row in snapshot[table]!) {
          await encrypted.insert(table, row);
        }
      }
      await encrypted.close();
      await backupFile.delete();
    } catch (_) {
      final encryptedFile = databaseFile(path);
      if (await encryptedFile.exists()) await encryptedFile.delete();
      await backupFile.rename(path);
      rethrow;
    }
  }

  File databaseFile(String path) => File(path);

  Future<void> _onUpgrade(
      cipher.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE family_members ADD COLUMN relation TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN phone TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN email TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN photo_url TEXT');
      await db.execute('ALTER TABLE family_members ADD COLUMN owner_uid TEXT');
    }
  }

  Future _onCreate(cipher.Database db, int version) async {
    await db.execute('''
      CREATE TABLE family_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id TEXT,
        name TEXT NOT NULL,
        relation TEXT,
        age INTEGER,
        gender TEXT,
        blood_group TEXT,
        phone TEXT,
        email TEXT,
        photo_url TEXT,
        owner_uid TEXT,
        diseases TEXT,
        emergency_contact TEXT,
        emergency_phone TEXT,
        photo_path TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bp_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        systolic INTEGER NOT NULL,
        diastolic INTEGER NOT NULL,
        pulse INTEGER,
        notes TEXT,
        recorded_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sugar_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        notes TEXT,
        recorded_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        height_cm REAL,
        notes TEXT,
        recorded_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        type TEXT,
        local_path TEXT NOT NULL,
        firebase_url TEXT,
        doctor_name TEXT,
        report_date TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        dosage TEXT,
        unit TEXT,
        times_json TEXT NOT NULL,
        duration_days INTEGER,
        start_date TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (member_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE medicine_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        taken_at TEXT,
        status TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Search Methods ---

  Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    final db = await database;
    if (kIsWeb) {
      return await db.query(
        'family_members',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
      );
    }
    return await (db as cipher.Database).query(
      'family_members',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> searchMedicines(String query) async {
    final db = await database;
    if (kIsWeb) {
      return await db.query(
        'medicines',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
      );
    }
    return await (db as cipher.Database).query(
      'medicines',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> searchReports(String query) async {
    final db = await database;
    if (kIsWeb) {
      return await db.query(
        'medical_reports',
        where: 'doctor_name LIKE ? OR notes LIKE ? OR type LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
    }
    return await (db as cipher.Database).query(
      'medical_reports',
      where: 'doctor_name LIKE ? OR notes LIKE ? OR type LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<void> eraseAllData() async {
    final db = await database;
    if (kIsWeb) {
      _mockDatabase._tables.forEach((key, value) {
        value.clear();
      });
      return;
    }
    final list = [
      'medicine_log',
      'medicines',
      'medical_reports',
      'weight_entries',
      'sugar_readings',
      'bp_readings',
      'family_members',
    ];
    for (final table in list) {
      await (db as cipher.Database).delete(table);
    }
  }
}

class MockDatabase {
  // In-memory mock tables
  final Map<String, List<Map<String, dynamic>>> _tables = {
    'family_members': [],
    'bp_readings': [],
    'sugar_readings': [],
    'weight_entries': [],
    'medical_reports': [],
    'medicines': [],
    'medicine_log': [],
  };

  int _nextId = 1;

  Future<int> insert(String table, Map<String, dynamic> values) async {
    final Map<String, dynamic> row = Map<String, dynamic>.from(values);
    row['id'] = _nextId++;
    _tables[table] ??= [];
    _tables[table]!.add(row);
    return row['id'];
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final list = _tables[table] ?? [];
    var result = list;
    if (where != null && whereArgs != null) {
      if (where.contains('synced = 0')) {
        result = result.where((r) => r['synced'] == 0).toList();
      } else if (where.contains('member_id = ?')) {
        final memberId = whereArgs[0];
        result = result
            .where((r) => r['member_id'].toString() == memberId.toString())
            .toList();
      } else if (where.contains('medicine_id = ?')) {
        final medicineId = whereArgs[0];
        result = result
            .where((r) => r['medicine_id'].toString() == medicineId.toString())
            .toList();
        if (where.contains('status = ?') && whereArgs.length > 1) {
          result = result
              .where((r) => r['status'].toString() == whereArgs[1].toString())
              .toList();
        }
      } else if (where.contains('id = ?')) {
        final idVal = whereArgs[0];
        result = result
            .where((r) => r['id'].toString() == idVal.toString())
            .toList();
      } else if (where.contains('name LIKE ?')) {
        final String match =
            (whereArgs[0] as String).replaceAll('%', '').toLowerCase();
        result = result.where((r) {
          final String name = (r['name'] as String? ?? '').toLowerCase();
          return name.contains(match);
        }).toList();
      } else if (where.contains('doctor_name LIKE ?')) {
        final String match =
            (whereArgs[0] as String).replaceAll('%', '').toLowerCase();
        result = result.where((r) {
          final String doc = (r['doctor_name'] as String? ?? '').toLowerCase();
          final String notes = (r['notes'] as String? ?? '').toLowerCase();
          final String type = (r['type'] as String? ?? '').toLowerCase();
          return doc.contains(match) ||
              notes.contains(match) ||
              type.contains(match);
        }).toList();
      }
    }
    if (orderBy != null) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final column = parts.first;
      final descending = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      result = List<Map<String, dynamic>>.from(result)
        ..sort((a, b) {
          final comparison =
              '${a[column] ?? ''}'.compareTo('${b[column] ?? ''}');
          return descending ? -comparison : comparison;
        });
    }
    return result;
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = _tables[table] ?? [];
    int count = 0;
    if (where != null && where.contains('id = ?') && whereArgs != null) {
      final idVal = whereArgs[0];
      for (var row in list) {
        if (row['id'].toString() == idVal.toString()) {
          values.forEach((k, v) {
            row[k] = v;
          });
          count++;
        }
      }
    }
    return count;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = _tables[table] ?? [];
    int count = 0;
    if (where != null && where.contains('id = ?') && whereArgs != null) {
      final idVal = whereArgs[0];
      final before = list.length;
      list.removeWhere((r) => r['id'].toString() == idVal.toString());
      count = before - list.length;
    } else if (where != null &&
        where.contains('medicine_id = ?') &&
        whereArgs != null) {
      final idVal = whereArgs[0];
      final before = list.length;
      list.removeWhere((r) => r['medicine_id'].toString() == idVal.toString());
      count = before - list.length;
    }
    return count;
  }
}
