import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import 'family_provider.dart';

class MedicalReport {
  final String id; // DB autoincrement id as string
  final String memberId;
  final String type; // Prescription, Lab, X-Ray, Other
  final String doctorName;
  final DateTime date;
  final String? imagePath;
  final String? notes;

  MedicalReport({
    required this.id,
    required this.memberId,
    required this.type,
    required this.doctorName,
    required this.date,
    this.imagePath,
    this.notes,
  });
}

class ReportsRepo {
  final int? _memberId;
  final List<MedicalReport> _reportsDb = [];
  final _controller = StreamController<List<MedicalReport>>.broadcast();
  Future<List<MedicalReport>>? _loadFuture;

  ReportsRepo(this._memberId);

  Future<List<MedicalReport>> _loadFromDb() async {
    if (_memberId == null) {
      return const [];
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'medical_reports',
      where: 'member_id = ?',
      whereArgs: [_memberId],
      orderBy: 'report_date DESC',
    );

    for (final r in rows) {
      _reportsDb.add(MedicalReport(
        id: (r['id'] as int).toString(),
        memberId: _memberId.toString(),
        type: r['type'] as String? ?? 'अन्य',
        doctorName: r['doctor_name'] as String? ?? '',
        date: DateTime.tryParse(r['report_date'] as String? ?? '') ??
            DateTime.now(),
        imagePath: (r['firebase_url'] as String?)?.isNotEmpty == true
            ? r['firebase_url'] as String
            : r['local_path'] as String?,
        notes: r['notes'] as String?,
      ));
    }
    return List<MedicalReport>.from(_reportsDb);
  }

  Future<List<MedicalReport>> _ensureLoaded() {
    return _loadFuture ??= _loadFromDb();
  }

  Stream<List<MedicalReport>> watchReports() async* {
    // Load after StreamProvider subscribes; constructor-started loading could
    // emit before the listener existed and leave Reports on its spinner.
    yield await _ensureLoaded();
    yield* _controller.stream;
  }

  Future<MedicalReport> addReport(MedicalReport report) async {
    if (_memberId == null) return report;
    await _ensureLoaded();
    final db = await DatabaseHelper.instance.database;

    final isUrl = report.imagePath?.startsWith('http') ?? false;

    final insertedId = await db.insert('medical_reports', {
      'member_id': _memberId,
      'type': report.type,
      'local_path': isUrl ? '' : (report.imagePath ?? ''),
      'firebase_url': isUrl ? report.imagePath : '',
      'doctor_name': report.doctorName,
      'report_date': report.date.toIso8601String(),
      'notes': report.notes ?? '',
      'synced': isUrl ? 1 : 0,
    });

    final saved = MedicalReport(
      id: insertedId.toString(),
      memberId: _memberId.toString(),
      type: report.type,
      doctorName: report.doctorName,
      date: report.date,
      imagePath: report.imagePath,
      notes: report.notes,
    );
    _reportsDb.insert(0, saved);
    _controller.add(List.from(_reportsDb));
    return saved;
  }

  Future<void> deleteReport(String id) async {
    await _ensureLoaded();
    final db = await DatabaseHelper.instance.database;
    final dbId = int.tryParse(id);
    if (dbId != null) {
      await db.delete('medical_reports', where: 'id = ?', whereArgs: [dbId]);
    }
    _reportsDb.removeWhere((r) => r.id == id);
    _controller.add(List.from(_reportsDb));
  }
}

// Repo depends on selected family member
final reportsRepoProvider = Provider<ReportsRepo>((ref) {
  final selectedMember = ref.watch(selectedFamilyMemberProvider);
  final dbId = selectedMember != null ? int.tryParse(selectedMember.id) : null;
  return ReportsRepo(dbId);
});

final reportsStreamProvider =
    StreamProvider.autoDispose<List<MedicalReport>>((ref) {
  final repo = ref.watch(reportsRepoProvider);
  return repo.watchReports();
});

// State for filtering
final activeReportTypeFilterProvider = StateProvider<String>((ref) => 'All');

final filteredReportsProvider =
    Provider.autoDispose<AsyncValue<List<MedicalReport>>>((ref) {
  final reportsAsync = ref.watch(reportsStreamProvider);
  final activeType = ref.watch(activeReportTypeFilterProvider);

  return reportsAsync.whenData((reports) {
    if (activeType == 'All') return reports;
    return reports.where((r) {
      var normalized = r.type;
      for (final oldIcon in const [0x1F48A, 0x1F9EA, 0x1F4F7, 0x1F493]) {
        normalized = normalized.replaceAll(String.fromCharCode(oldIcon), '');
      }
      normalized = normalized
          .replaceAll('नुस्खा', 'Prescription')
          .replaceAll('लैब रिपोर्ट', 'Lab Report')
          .replaceAll('Lab रिपोर्ट', 'Lab Report')
          .replaceAll('अन्य', 'Other')
          .trim();
      return normalized == activeType;
    }).toList();
  });
});
