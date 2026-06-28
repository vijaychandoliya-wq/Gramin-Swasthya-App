import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import 'family_provider.dart';

// --- Models ---

class BpRecord {
  final String id;
  final int systolic;
  final int diastolic;
  final DateTime date;

  BpRecord({required this.id, required this.systolic, required this.diastolic, required this.date});
}

class SugarRecord {
  final String id;
  final double glucose; // stored in a REAL column; keep decimals intact
  final String type; // 'Fasting', 'Random', 'Post-meal'
  final DateTime date;

  SugarRecord({required this.id, required this.glucose, required this.type, required this.date});

  /// Glucose without a trailing ".0" for whole numbers (e.g. "110", "110.5").
  String get glucoseDisplay => glucose == glucose.truncateToDouble()
      ? glucose.toStringAsFixed(0)
      : glucose.toStringAsFixed(1);
}

class WeightRecord {
  final String id;
  final double weight;
  final DateTime date;

  WeightRecord({required this.id, required this.weight, required this.date});
}

// --- SQLite-backed Repository ---

class HealthRepo {
  final int? _memberId;

  // In-memory cache backed by SQLite
  List<BpRecord> _bpDb = [];
  List<SugarRecord> _sugarDb = [];
  List<WeightRecord> _weightDb = [];

  // Stream Controllers
  final _bpStreamController = StreamController<List<BpRecord>>.broadcast();
  final _sugarStreamController = StreamController<List<SugarRecord>>.broadcast();
  final _weightStreamController = StreamController<List<WeightRecord>>.broadcast();

  HealthRepo(this._memberId) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_memberId == null) {
      _emitAll();
      return;
    }

    final db = await DatabaseHelper.instance.database;

    // Load BP
    final bpRows = await db.query(
      'bp_readings',
      where: 'member_id = ?',
      whereArgs: [_memberId],
      orderBy: 'recorded_at DESC',
    );
    _bpDb = bpRows.map<BpRecord>((r) => BpRecord(
      id: r['id'].toString(),
      systolic: r['systolic'] as int,
      diastolic: r['diastolic'] as int,
      date: DateTime.parse(r['recorded_at'] as String),
    )).toList();

    // Load Sugar
    final sugarRows = await db.query(
      'sugar_readings',
      where: 'member_id = ?',
      whereArgs: [_memberId],
      orderBy: 'recorded_at DESC',
    );
    _sugarDb = sugarRows.map<SugarRecord>((r) => SugarRecord(
      id: r['id'].toString(),
      glucose: (r['value'] as num).toDouble(),
      type: r['type'] as String,
      date: DateTime.parse(r['recorded_at'] as String),
    )).toList();

    // Load Weight
    final weightRows = await db.query(
      'weight_entries',
      where: 'member_id = ?',
      whereArgs: [_memberId],
      orderBy: 'recorded_at DESC',
    );
    _weightDb = weightRows.map<WeightRecord>((r) => WeightRecord(
      id: r['id'].toString(),
      weight: (r['weight_kg'] as num).toDouble(),
      date: DateTime.parse(r['recorded_at'] as String),
    )).toList();

    _emitAll();
  }

  void _emitAll() {
    _bpStreamController.add(List.from(_bpDb));
    _sugarStreamController.add(List.from(_sugarDb));
    _weightStreamController.add(List.from(_weightDb));
  }

  // --- BP ---
  Stream<List<BpRecord>> get bpStream async* {
    // Emit cached data immediately so new subscribers get current state
    yield List.from(_bpDb);
    yield* _bpStreamController.stream;
  }

  Future<void> addBp(BpRecord record) async {
    if (_memberId == null) return;
    final db = await DatabaseHelper.instance.database;
    final insertedId = await db.insert('bp_readings', {
      'member_id': _memberId,
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'pulse': null,
      'notes': null,
      'recorded_at': record.date.toIso8601String(),
      'synced': 0,
    });
    final saved = BpRecord(
      id: insertedId.toString(),
      systolic: record.systolic,
      diastolic: record.diastolic,
      date: record.date,
    );
    _bpDb.insert(0, saved);
    _bpDb.sort((a, b) => b.date.compareTo(a.date));
    _bpStreamController.add(List.from(_bpDb));
  }

  Future<void> deleteBp(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('bp_readings', where: 'id = ?', whereArgs: [int.tryParse(id)]);
    _bpDb.removeWhere((item) => item.id == id);
    _bpStreamController.add(List.from(_bpDb));
  }

  // --- Sugar ---
  Stream<List<SugarRecord>> get sugarStream async* {
    yield List.from(_sugarDb);
    yield* _sugarStreamController.stream;
  }

  Future<void> addSugar(SugarRecord record) async {
    if (_memberId == null) return;
    final db = await DatabaseHelper.instance.database;
    final insertedId = await db.insert('sugar_readings', {
      'member_id': _memberId,
      'type': record.type,
      'value': record.glucose,
      'notes': null,
      'recorded_at': record.date.toIso8601String(),
      'synced': 0,
    });
    final saved = SugarRecord(
      id: insertedId.toString(),
      glucose: record.glucose,
      type: record.type,
      date: record.date,
    );
    _sugarDb.insert(0, saved);
    _sugarDb.sort((a, b) => b.date.compareTo(a.date));
    _sugarStreamController.add(List.from(_sugarDb));
  }

  Future<void> deleteSugar(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sugar_readings', where: 'id = ?', whereArgs: [int.tryParse(id)]);
    _sugarDb.removeWhere((item) => item.id == id);
    _sugarStreamController.add(List.from(_sugarDb));
  }

  // --- Weight ---
  Stream<List<WeightRecord>> get weightStream async* {
    yield List.from(_weightDb);
    yield* _weightStreamController.stream;
  }

  Future<void> addWeight(WeightRecord record) async {
    if (_memberId == null) return;
    final db = await DatabaseHelper.instance.database;
    final insertedId = await db.insert('weight_entries', {
      'member_id': _memberId,
      'weight_kg': record.weight,
      'height_cm': null,
      'notes': null,
      'recorded_at': record.date.toIso8601String(),
      'synced': 0,
    });
    final saved = WeightRecord(
      id: insertedId.toString(),
      weight: record.weight,
      date: record.date,
    );
    _weightDb.insert(0, saved);
    _weightDb.sort((a, b) => b.date.compareTo(a.date));
    _weightStreamController.add(List.from(_weightDb));
  }

  Future<void> deleteWeight(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('weight_entries', where: 'id = ?', whereArgs: [int.tryParse(id)]);
    _weightDb.removeWhere((item) => item.id == id);
    _weightStreamController.add(List.from(_weightDb));
  }
}

// --- Riverpod Providers ---

// HealthRepo depends on selected family member's DB id
final healthRepoProvider = Provider<HealthRepo>((ref) {
  final selectedMember = ref.watch(selectedFamilyMemberProvider);
  final dbId = selectedMember != null ? int.tryParse(selectedMember.id) : null;
  return HealthRepo(dbId);
});

// Streams
final bpStreamProvider = StreamProvider<List<BpRecord>>((ref) {
  final repo = ref.watch(healthRepoProvider);
  return repo.bpStream;
});

final sugarStreamProvider = StreamProvider<List<SugarRecord>>((ref) {
  final repo = ref.watch(healthRepoProvider);
  return repo.sugarStream;
});

final weightStreamProvider = StreamProvider<List<WeightRecord>>((ref) {
  final repo = ref.watch(healthRepoProvider);
  return repo.weightStream;
});
