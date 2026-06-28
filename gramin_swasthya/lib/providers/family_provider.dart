import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';

class FamilyMember {
  final String id; // DB autoincrement id as string
  final String name;
  final String relation;
  final int age;
  final String gender;
  final String bloodGroup;
  final bool isPrimary;
  final String? photoPath;
  final List<String> diseases;
  final String? emergencyContactName;
  final String? emergencyPhone;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    this.isPrimary = false,
    this.photoPath,
    this.diseases = const [],
    this.emergencyContactName,
    this.emergencyPhone,
  });
}

final familyProvider = StateNotifierProvider<FamilyNotifier, List<FamilyMember>>((ref) {
  return FamilyNotifier();
});

final selectedFamilyMemberProvider = StateProvider<FamilyMember?>((ref) {
  final members = ref.watch(familyProvider);
  return members.isNotEmpty ? members.first : null;
});

class FamilyNotifier extends StateNotifier<List<FamilyMember>> {
  FamilyNotifier() : super([]) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('family_members', orderBy: 'id ASC');

    // DatabaseHelper.database is typed `dynamic`, so `rows` is dynamic and a
    // bare `.map(...)` infers `List<dynamic>` — which fails to assign to the
    // `List<FamilyMember>` state at runtime. Pin the element type explicitly.
    state = rows.map<FamilyMember>((r) => FamilyMember(
      id: r['id'].toString(),
      name: r['name'] as String,
      relation: (r['gender'] as String?) ?? 'Family',
      age: (r['age'] as int?) ?? 0,
      gender: (r['gender'] as String?) ?? 'पुरुष / Male',
      bloodGroup: (r['blood_group'] as String?) ?? 'O+',
      isPrimary: r['id'] == 1, // first member is primary
      photoPath: r['photo_path'] as String?,
      diseases: _parseDiseases(r['diseases'] as String?),
      emergencyContactName: r['emergency_contact'] as String?,
      emergencyPhone: r['emergency_phone'] as String?,
    )).toList();
  }

  static List<String> _parseDiseases(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> addMember({
    required String name,
    required String relation,
    required int age,
    required String gender,
    required String bloodGroup,
    String? photoPath,
    List<String> diseases = const [],
    String? emergencyContactName,
    String? emergencyPhone,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final insertedId = await db.insert('family_members', {
      'name': name,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'diseases': diseases.join(','),
      'emergency_contact': emergencyContactName,
      'emergency_phone': emergencyPhone,
      'photo_path': photoPath,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    final newMember = FamilyMember(
      id: insertedId.toString(),
      name: name,
      relation: relation,
      age: age,
      gender: gender,
      bloodGroup: bloodGroup,
      photoPath: photoPath,
      diseases: diseases,
      emergencyContactName: emergencyContactName,
      emergencyPhone: emergencyPhone,
      isPrimary: state.isEmpty, // first member added is primary
    );
    state = [...state, newMember];
  }

  Future<void> updateMember(FamilyMember updatedMember) async {
    final db = await DatabaseHelper.instance.database;
    final dbId = int.tryParse(updatedMember.id);
    if (dbId != null) {
      await db.update('family_members', {
        'name': updatedMember.name,
        'age': updatedMember.age,
        'gender': updatedMember.gender,
        'blood_group': updatedMember.bloodGroup,
        'diseases': updatedMember.diseases.join(','),
        'emergency_contact': updatedMember.emergencyContactName,
        'emergency_phone': updatedMember.emergencyPhone,
        'photo_path': updatedMember.photoPath,
      }, where: 'id = ?', whereArgs: [dbId]);
    }

    state = [
      for (final m in state)
        if (m.id == updatedMember.id) updatedMember else m,
    ];
  }

  Future<void> deleteMember(String id) async {
    final db = await DatabaseHelper.instance.database;
    final dbId = int.tryParse(id);
    if (dbId != null) {
      await db.delete('family_members', where: 'id = ?', whereArgs: [dbId]);
    }
    state = state.where((m) => m.id != id).toList();
  }
}
