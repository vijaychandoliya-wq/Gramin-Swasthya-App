import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static const _databaseName = "GraminSwasthya.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static dynamic _database;
  static final MockDatabase _mockDatabase = MockDatabase();

  Future<dynamic> get database async {
    if (kIsWeb) {
      return _mockDatabase;
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE family_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id TEXT,
        name TEXT NOT NULL,
        age INTEGER,
        gender TEXT,
        blood_group TEXT,
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
    return await (db as Database).query(
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
    return await (db as Database).query(
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
    return await (db as Database).query(
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
      await (db as Database).delete(table);
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
    // Copy so filtering/sorting never mutates the backing table.
    var result = List<Map<String, dynamic>>.from(list);
    if (where != null && whereArgs != null) {
      if (where.contains('synced = 0')) {
        result = result.where((r) => r['synced'] == 0).toList();
      } else if (where.contains('member_id = ?')) {
        // Must be checked before the generic 'id = ?' branch (which 'member_id'
        // also contains) so per-member reads aren't returned unfiltered.
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
          final status = whereArgs[1];
          result = result
              .where((r) => r['status'].toString() == status.toString())
              .toList();
        }
      } else if (where.contains('id = ?')) {
        final idVal = whereArgs[0];
        result = result.where((r) => r['id'].toString() == idVal.toString()).toList();
      } else if (where.contains('name LIKE ?')) {
        final String match = (whereArgs[0] as String).replaceAll('%', '').toLowerCase();
        result = result.where((r) {
          final String name = (r['name'] as String? ?? '').toLowerCase();
          return name.contains(match);
        }).toList();
      } else if (where.contains('doctor_name LIKE ?')) {
        final String match = (whereArgs[0] as String).replaceAll('%', '').toLowerCase();
        result = result.where((r) {
          final String doc = (r['doctor_name'] as String? ?? '').toLowerCase();
          final String notes = (r['notes'] as String? ?? '').toLowerCase();
          final String type = (r['type'] as String? ?? '').toLowerCase();
          return doc.contains(match) || notes.contains(match) || type.contains(match);
        }).toList();
      }
    }

    // Honor orderBy (e.g. 'recorded_at DESC') so mock results match sqflite.
    if (orderBy != null && orderBy.trim().isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final col = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      result.sort((a, b) {
        final av = a[col];
        final bv = b[col];
        if (av == null && bv == null) return 0;
        if (av == null) return desc ? 1 : -1;
        if (bv == null) return desc ? -1 : 1;
        final int cmp = (av is num && bv is num)
            ? av.compareTo(bv)
            : av.toString().compareTo(bv.toString());
        return desc ? -cmp : cmp;
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
    } else if (where != null && where.contains('medicine_id = ?') && whereArgs != null) {
      final idVal = whereArgs[0];
      final before = list.length;
      list.removeWhere((r) => r['medicine_id'].toString() == idVal.toString());
      count = before - list.length;
    }
    return count;
  }
}
