import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "GraminSwasthya.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
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
    return await db.query(
      'family_members',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> searchMedicines(String query) async {
    final db = await database;
    return await db.query(
      'medicines',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> searchReports(String query) async {
    final db = await database;
    return await db.query(
      'medical_reports',
      where: 'doctor_name LIKE ? OR notes LIKE ? OR type LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }
}
