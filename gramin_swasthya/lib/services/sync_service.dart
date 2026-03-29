import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _firestore = FirebaseFirestore.instance;
  final _dbHelper = DatabaseHelper.instance;

  Future<void> syncAll() async {
    final db = await _dbHelper.database;
    
    // 1. Sync Family Members
    await _syncTable(db, 'family_members', 'family');
    
    // 2. Sync BP Readings
    await _syncTable(db, 'bp_readings', 'bp');
    
    // 3. Sync Sugar Readings
    await _syncTable(db, 'sugar_readings', 'sugar');
    
    // 4. Sync Weight Entries
    await _syncTable(db, 'weight_entries', 'weight');
    
    // 5. Sync Medicines
    await _syncTable(db, 'medicines', 'medicines');
    
    // 6. Sync Medicine Logs
    await _syncTable(db, 'medicine_log', 'medicine_logs');

    // 7. Sync Medical Reports (Basic implementation, file upload handles separately in a real app)
    await _syncTable(db, 'medical_reports', 'reports');

    debugPrint("Sync Complete!");
  }

  Future<void> _syncTable(var db, String tableName, String firestoreCollection) async {
    final unsynced = await db.query(tableName, where: 'synced = 0');
    
    for (var row in unsynced) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row);
      final int id = data['id'];
      
      // Remove local ID and synced flag for Firestore
      data.remove('id');
      data.remove('synced');
      
      try {
        await _firestore.collection(firestoreCollection).add({
          ...data,
          'syncedAt': FieldValue.serverTimestamp(),
          'localId': id,
        });
        
        await db.update(tableName, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint("Error syncing $tableName row $id: $e");
      }
    }
  }
}
