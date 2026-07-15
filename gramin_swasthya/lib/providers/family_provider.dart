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
  final String? photoUrl;
  final String? phone;
  final String? email;
  final String? ownerUid;
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
    this.photoUrl,
    this.phone,
    this.email,
    this.ownerUid,
    this.diseases = const [],
    this.emergencyContactName,
    this.emergencyPhone,
  });
}

final familyProvider =
    StateNotifierProvider<FamilyNotifier, List<FamilyMember>>((ref) {
  return FamilyNotifier();
});

final selectedFamilyMemberProvider = StateProvider<FamilyMember?>((ref) {
  final members = ref.watch(familyProvider);
  return members.isNotEmpty ? members.first : null;
});

class FamilyNotifier extends StateNotifier<List<FamilyMember>> {
  late final Future<void> _loadFuture;

  FamilyNotifier() : super([]) {
    _loadFuture = _loadFromDb();
  }

  Future<void> get loaded => _loadFuture;

  Future<void> _loadFromDb() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('family_members', orderBy: 'id ASC');

    // db is dynamic (web mock support), so map() must pin its type argument
    // or the runtime produces List<dynamic> and the state assignment throws.
    state = rows.asMap().entries.map<FamilyMember>((entry) {
      final r = entry.value;
      return FamilyMember(
        id: r['id'].toString(),
        name: r['name'] as String,
        relation: (r['relation'] as String?) ?? 'Family',
        age: (r['age'] as int?) ?? 0,
        gender: (r['gender'] as String?) ?? 'पुरुष / Male',
        bloodGroup: (r['blood_group'] as String?) ?? 'अज्ञात / Unknown',
        isPrimary: entry.key == 0,
        photoPath: r['photo_path'] as String?,
        photoUrl: r['photo_url'] as String?,
        phone: r['phone'] as String?,
        email: r['email'] as String?,
        ownerUid: r['owner_uid'] as String?,
        diseases: _parseDiseases(r['diseases'] as String?),
        emergencyContactName: r['emergency_contact'] as String?,
        emergencyPhone: r['emergency_phone'] as String?,
      );
    }).toList();
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
    String? photoUrl,
    String? phone,
    String? email,
    String? ownerUid,
    List<String> diseases = const [],
    String? emergencyContactName,
    String? emergencyPhone,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final insertedId = await db.insert('family_members', {
      'name': name,
      'relation': relation,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'diseases': diseases.join(','),
      'emergency_contact': emergencyContactName,
      'emergency_phone': emergencyPhone,
      'photo_path': photoPath,
      'photo_url': photoUrl,
      'phone': phone,
      'email': email,
      'owner_uid': ownerUid,
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
      photoUrl: photoUrl,
      phone: phone,
      email: email,
      ownerUid: ownerUid,
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
      await db.update(
          'family_members',
          {
            'name': updatedMember.name,
            'relation': updatedMember.relation,
            'age': updatedMember.age,
            'gender': updatedMember.gender,
            'blood_group': updatedMember.bloodGroup,
            'diseases': updatedMember.diseases.join(','),
            'emergency_contact': updatedMember.emergencyContactName,
            'emergency_phone': updatedMember.emergencyPhone,
            'photo_path': updatedMember.photoPath,
            'photo_url': updatedMember.photoUrl,
            'phone': updatedMember.phone,
            'email': updatedMember.email,
            'owner_uid': updatedMember.ownerUid,
          },
          where: 'id = ?',
          whereArgs: [dbId]);
    }

    state = [
      for (final m in state)
        if (m.id == updatedMember.id) updatedMember else m,
    ];
  }

  Future<void> ensureGooglePrimaryProfile({
    required String uid,
    required String name,
    required String phone,
    String? email,
    String? photoUrl,
  }) async {
    await _loadFuture;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('family_members', orderBy: 'id ASC');

    Map<String, dynamic>? accountProfile;
    for (final row in rows) {
      if (row['owner_uid'] == uid) {
        accountProfile = row;
        break;
      }
    }

    if (accountProfile != null) {
      await db.update(
        'family_members',
        {
          'name': name,
          'relation': 'Self',
          'phone': phone,
          'email': email,
          'photo_url': photoUrl,
        },
        where: 'id = ?',
        whereArgs: [accountProfile['id']],
      );
    } else if (rows.isNotEmpty) {
      // Preserve health data created by older app versions by linking the
      // existing primary profile instead of creating a duplicate.
      await db.update(
        'family_members',
        {
          'owner_uid': uid,
          'name': name,
          'relation': 'Self',
          'phone': phone,
          'email': email,
          'photo_url': photoUrl,
        },
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    } else {
      await db.insert('family_members', {
        'family_id': uid,
        'owner_uid': uid,
        'name': name,
        'relation': 'Self',
        'age': 0,
        'gender': 'अन्य / Other',
        'blood_group': 'अज्ञात / Unknown',
        'phone': phone,
        'email': email,
        'photo_url': photoUrl,
        'diseases': '',
        'emergency_contact': null,
        'emergency_phone': null,
        'photo_path': null,
        'synced': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await _loadFromDb();
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
