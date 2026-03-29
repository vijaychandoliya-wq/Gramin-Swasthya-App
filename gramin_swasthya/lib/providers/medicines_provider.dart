import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import 'family_provider.dart';

class Medicine {
  final String id; // DB autoincrement id as string
  final String memberId;
  final String name;
  final String dosage;
  final String unit;
  final List<TimeOfDay> times;
  final bool isActive;
  final int durationDays; // -1 for always
  final DateTime startDate;
  final List<DateTime> takenHistory;

  Medicine({
    required this.id,
    required this.memberId,
    required this.name,
    required this.dosage,
    required this.unit,
    required this.times,
    this.isActive = true,
    this.durationDays = -1,
    DateTime? startDate,
    this.takenHistory = const [],
  }) : startDate = startDate ?? DateTime.now();

  Medicine copyWith({
    bool? isActive,
    List<DateTime>? takenHistory,
  }) {
    return Medicine(
      id: id,
      memberId: memberId,
      name: name,
      dosage: dosage,
      unit: unit,
      times: times,
      isActive: isActive ?? this.isActive,
      durationDays: durationDays,
      startDate: startDate,
      takenHistory: takenHistory ?? this.takenHistory,
    );
  }

  // Serialize times to JSON for DB storage
  static String timesToJson(List<TimeOfDay> times) {
    return jsonEncode(times.map((t) => {'h': t.hour, 'm': t.minute}).toList());
  }

  // Deserialize times from JSON
  static List<TimeOfDay> timesFromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((m) => TimeOfDay(hour: m['h'] as int, minute: m['m'] as int)).toList();
    } catch (_) {
      return [];
    }
  }
}

class MedicinesRepo {
  final int? _memberId;
  final List<Medicine> _medicinesDb = [];
  final _controller = StreamController<List<Medicine>>.broadcast();

  MedicinesRepo(this._memberId) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (_memberId == null) {
      _emit();
      return;
    }

    final db = await DatabaseHelper.instance.database;

    // Load medicines
    final rows = await db.query(
      'medicines',
      where: 'member_id = ?',
      whereArgs: [_memberId],
      orderBy: 'id DESC',
    );

    for (final r in rows) {
      final medId = r['id'] as int;

      // Load taken history from medicine_log
      final logs = await db.query(
        'medicine_log',
        where: 'medicine_id = ? AND status = ?',
        whereArgs: [medId, 'taken'],
        orderBy: 'taken_at DESC',
      );

      final takenHistory = logs
          .where((l) => l['taken_at'] != null)
          .map((l) => DateTime.parse(l['taken_at'] as String))
          .toList();

      _medicinesDb.add(Medicine(
        id: medId.toString(),
        memberId: _memberId.toString(),
        name: r['name'] as String,
        dosage: r['dosage'] as String? ?? '',
        unit: r['unit'] as String? ?? 'Tablet',
        times: Medicine.timesFromJson(r['times_json'] as String? ?? '[]'),
        isActive: (r['is_active'] as int?) == 1,
        durationDays: (r['duration_days'] as int?) ?? -1,
        startDate: DateTime.tryParse(r['start_date'] as String? ?? '') ?? DateTime.now(),
        takenHistory: takenHistory,
      ));
    }
    _emit();
  }

  void _emit() => _controller.add(List.from(_medicinesDb));

  Stream<List<Medicine>> watchMedicines() async* {
    // Emit cached data immediately so new subscribers get current state
    yield List.from(_medicinesDb);
    yield* _controller.stream;
  }

  Future<Medicine> addMedicine(Medicine med) async {
    if (_memberId == null) return med;
    final db = await DatabaseHelper.instance.database;

    final insertedId = await db.insert('medicines', {
      'member_id': _memberId,
      'name': med.name,
      'dosage': med.dosage,
      'unit': med.unit,
      'times_json': Medicine.timesToJson(med.times),
      'duration_days': med.durationDays,
      'start_date': med.startDate.toIso8601String(),
      'is_active': med.isActive ? 1 : 0,
      'synced': 0,
    });

    final saved = Medicine(
      id: insertedId.toString(),
      memberId: _memberId.toString(),
      name: med.name,
      dosage: med.dosage,
      unit: med.unit,
      times: med.times,
      isActive: med.isActive,
      durationDays: med.durationDays,
      startDate: med.startDate,
      takenHistory: [],
    );
    _medicinesDb.insert(0, saved);
    _emit();
    return saved;
  }

  Future<void> deleteMedicine(String id) async {
    final db = await DatabaseHelper.instance.database;
    final dbId = int.tryParse(id);
    if (dbId != null) {
      await db.delete('medicine_log', where: 'medicine_id = ?', whereArgs: [dbId]);
      await db.delete('medicines', where: 'id = ?', whereArgs: [dbId]);
    }
    _medicinesDb.removeWhere((m) => m.id == id);
    _emit();
  }

  Future<void> toggleActive(String id) async {
    final idx = _medicinesDb.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final newActive = !_medicinesDb[idx].isActive;
      _medicinesDb[idx] = _medicinesDb[idx].copyWith(isActive: newActive);

      final db = await DatabaseHelper.instance.database;
      final dbId = int.tryParse(id);
      if (dbId != null) {
        await db.update('medicines', {'is_active': newActive ? 1 : 0},
            where: 'id = ?', whereArgs: [dbId]);
      }
      _emit();
    }
  }

  Future<void> markAsTaken(String id) async {
    final idx = _medicinesDb.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final now = DateTime.now();
      final newHistory = List<DateTime>.from(_medicinesDb[idx].takenHistory)..add(now);
      _medicinesDb[idx] = _medicinesDb[idx].copyWith(takenHistory: newHistory);

      final db = await DatabaseHelper.instance.database;
      final dbId = int.tryParse(id);
      if (dbId != null) {
        await db.insert('medicine_log', {
          'medicine_id': dbId,
          'scheduled_at': now.toIso8601String(),
          'taken_at': now.toIso8601String(),
          'status': 'taken',
          'synced': 0,
        });
      }
      _emit();
    }
  }

  Future<void> updateMedicine(Medicine med) async {
    final db = await DatabaseHelper.instance.database;
    final dbId = int.tryParse(med.id);
    if (dbId != null) {
      await db.update('medicines', {
        'name': med.name,
        'dosage': med.dosage,
        'unit': med.unit,
        'times_json': Medicine.timesToJson(med.times),
        'duration_days': med.durationDays,
        'start_date': med.startDate.toIso8601String(),
        'is_active': med.isActive ? 1 : 0,
      }, where: 'id = ?', whereArgs: [dbId]);
    }

    final idx = _medicinesDb.indexWhere((m) => m.id == med.id);
    if (idx != -1) {
      _medicinesDb[idx] = med;
    }
    _emit();
  }
}

// Repo depends on selected family member
final medicinesRepoProvider = Provider<MedicinesRepo>((ref) {
  final selectedMember = ref.watch(selectedFamilyMemberProvider);
  final dbId = selectedMember != null ? int.tryParse(selectedMember.id) : null;
  return MedicinesRepo(dbId);
});

final medicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final repo = ref.watch(medicinesRepoProvider);
  return repo.watchMedicines();
});

// Selector for filtered medicines by member
final filteredMedicinesProvider = Provider.family<AsyncValue<List<Medicine>>, String?>((ref, memberId) {
  final medicinesAsync = ref.watch(medicinesStreamProvider);
  return medicinesAsync.whenData((list) {
    if (memberId == null) return list;
    return list.where((m) => m.memberId == memberId).toList();
  });
});

// Adherence state for today
class AdherenceData {
  final int taken;
  final int total;
  double get fraction => total == 0 ? 0 : taken / total;
  AdherenceData(this.taken, this.total);
}

final dailyAdherenceProvider = Provider.family<AdherenceData, String?>((ref, memberId) {
  final medicinesAsync = ref.watch(filteredMedicinesProvider(memberId));
  return medicinesAsync.maybeWhen(
    data: (list) {
      int totalDoses = 0;
      int takenDoses = 0;
      final now = DateTime.now();

      for (var med in list) {
        if (!med.isActive) continue;

        totalDoses += med.times.length;

        final todayEntries = med.takenHistory.where((dt) =>
          dt.year == now.year && dt.month == now.month && dt.day == now.day
        ).length;

        takenDoses += todayEntries > med.times.length ? med.times.length : todayEntries;
      }
      return AdherenceData(takenDoses, totalDoses);
    },
    orElse: () => AdherenceData(0, 0),
  );
});
