import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../db/database_helper.dart';
import 'auth_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveService {
  GoogleDriveService._privateConstructor();
  static final GoogleDriveService instance =
      GoogleDriveService._privateConstructor();

  GoogleSignIn get _googleSignIn => AuthService.instance.googleSignIn;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return null;

      final granted = await _googleSignIn.requestScopes(
        [drive.DriveApi.driveFileScope],
      );
      if (!granted) return null;
      return account;
    } catch (e) {
      debugPrint("Google Sign-In error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<bool> isSignedIn() async {
    if (_googleSignIn.currentUser != null) return true;
    return await _googleSignIn.signInSilently() != null;
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<void> backupProfiles(BuildContext context) async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) {
      throw Exception(
          "Google account is not linked. Please link your account first.");
    }

    final driveScopeGranted = await _googleSignIn.requestScopes(
      [drive.DriveApi.driveFileScope],
    );
    if (!driveScopeGranted) {
      throw Exception('Google Drive permission was not granted.');
    }

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // 1. Get root backups folder "Gramin Swasthya Backups"
    String? rootFolderId =
        await _findFolder(driveApi, "Gramin Swasthya Backups", "root");
    rootFolderId ??=
        await _createFolder(driveApi, "Gramin Swasthya Backups", "root");

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // 2. Fetch all profiles
    final List<Map<String, dynamic>> members = kIsWeb
        ? await db.query('family_members')
        : await (db).query('family_members');

    for (final member in members) {
      final memberId = member['id'];
      final name = member['name'] as String;

      // Create a specific folder for this member's profile
      String? memberFolderId = await _findFolder(driveApi, name, rootFolderId);
      memberFolderId ??= await _createFolder(driveApi, name, rootFolderId);

      // Fetch related data
      final bpReadings = kIsWeb
          ? await db.query('bp_readings',
              where: 'member_id = ?', whereArgs: [memberId])
          : await (db).query('bp_readings',
              where: 'member_id = ?', whereArgs: [memberId]);

      final sugarReadings = kIsWeb
          ? await db.query('sugar_readings',
              where: 'member_id = ?', whereArgs: [memberId])
          : await (db).query('sugar_readings',
              where: 'member_id = ?', whereArgs: [memberId]);

      final weightEntries = kIsWeb
          ? await db.query('weight_entries',
              where: 'member_id = ?', whereArgs: [memberId])
          : await (db).query('weight_entries',
              where: 'member_id = ?', whereArgs: [memberId]);

      final medicines = kIsWeb
          ? await db
              .query('medicines', where: 'member_id = ?', whereArgs: [memberId])
          : await (db).query('medicines',
              where: 'member_id = ?', whereArgs: [memberId]);

      final List<Map<String, dynamic>> medicineLogs = [];
      for (final med in medicines) {
        final medId = med['id'];
        final logs = kIsWeb
            ? await db.query('medicine_log',
                where: 'medicine_id = ?', whereArgs: [medId])
            : await (db).query('medicine_log',
                where: 'medicine_id = ?', whereArgs: [medId]);
        medicineLogs.addAll(logs);
      }

      final medicalReports = kIsWeb
          ? await db.query('medical_reports',
              where: 'member_id = ?', whereArgs: [memberId])
          : await (db).query('medical_reports',
              where: 'member_id = ?', whereArgs: [memberId]);

      // Upload JSON files
      await _uploadJsonFile(driveApi, "profile.json", member, memberFolderId);
      await _uploadJsonFile(
          driveApi, "bp_readings.json", bpReadings, memberFolderId);
      await _uploadJsonFile(
          driveApi, "sugar_readings.json", sugarReadings, memberFolderId);
      await _uploadJsonFile(
          driveApi, "weight_entries.json", weightEntries, memberFolderId);
      await _uploadJsonFile(
          driveApi, "medicines.json", medicines, memberFolderId);
      await _uploadJsonFile(
          driveApi, "medicine_log.json", medicineLogs, memberFolderId);

      // Handle reports and their binary files
      final List<Map<String, dynamic>> updatedReportsMetadata = [];
      String? reportsFolderId;

      for (final report in medicalReports) {
        final Map<String, dynamic> reportMeta =
            Map<String, dynamic>.from(report);
        final localPath = report['local_path'] as String?;

        if (localPath != null && localPath.isNotEmpty && !kIsWeb) {
          final file = File(localPath);
          if (await file.exists()) {
            reportsFolderId ??= await _findFolder(
                driveApi, "medical_reports_files", memberFolderId);
            reportsFolderId ??= await _createFolder(
                driveApi, "medical_reports_files", memberFolderId);

            final filename = path.basename(localPath);
            final driveFileId = await _uploadBinaryFile(
                driveApi, filename, file, reportsFolderId);
            reportMeta['drive_file_id'] = driveFileId;
          }
        }
        updatedReportsMetadata.add(reportMeta);
      }

      await _uploadJsonFile(driveApi, "medical_reports.json",
          updatedReportsMetadata, memberFolderId);
    }
  }

  Future<List<Map<String, String>>> listBackupFolders() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) return [];

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final rootFolderId =
        await _findFolder(driveApi, "Gramin Swasthya Backups", "root");
    if (rootFolderId == null) return [];

    final query =
        "'$rootFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');

    final List<Map<String, String>> folders = [];
    if (fileList.files != null) {
      for (final f in fileList.files!) {
        folders.add({
          'id': f.id!,
          'name': f.name!,
        });
      }
    }
    return folders;
  }

  Future<void> importProfile(String folderId) async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) {
      throw Exception("Google account is not linked.");
    }

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // 1. Download all JSON files
    final memberData =
        await _downloadJsonFile(driveApi, "profile.json", folderId);
    if (memberData == null) {
      throw Exception("Profile data is missing in selected folder.");
    }

    final bpData =
        (await _downloadJsonFile(driveApi, "bp_readings.json", folderId)
                as List?) ??
            [];
    final sugarData =
        (await _downloadJsonFile(driveApi, "sugar_readings.json", folderId)
                as List?) ??
            [];
    final weightData =
        (await _downloadJsonFile(driveApi, "weight_entries.json", folderId)
                as List?) ??
            [];
    final medicinesData =
        (await _downloadJsonFile(driveApi, "medicines.json", folderId)
                as List?) ??
            [];
    final logsData =
        (await _downloadJsonFile(driveApi, "medicine_log.json", folderId)
                as List?) ??
            [];
    final reportsData =
        (await _downloadJsonFile(driveApi, "medical_reports.json", folderId)
                as List?) ??
            [];

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // 2. Insert member profile
    final Map<String, dynamic> cleanMember =
        Map<String, dynamic>.from(memberData);
    cleanMember.remove('id'); // let SQLite auto-increment
    cleanMember['synced'] = 0;

    final newMemberId = kIsWeb
        ? await db.insert('family_members', cleanMember)
        : await (db).insert('family_members', cleanMember);

    // Helper map to map old medicine ID to new medicine ID
    final Map<String, int> medicineIdMap = {};

    // 3. Insert BP readings
    for (final bp in bpData) {
      final cleanBp = Map<String, dynamic>.from(bp);
      cleanBp.remove('id');
      cleanBp['member_id'] = newMemberId;
      cleanBp['synced'] = 0;
      kIsWeb
          ? await db.insert('bp_readings', cleanBp)
          : await (db).insert('bp_readings', cleanBp);
    }

    // 4. Insert Sugar readings
    for (final sugar in sugarData) {
      final cleanSugar = Map<String, dynamic>.from(sugar);
      cleanSugar.remove('id');
      cleanSugar['member_id'] = newMemberId;
      cleanSugar['synced'] = 0;
      kIsWeb
          ? await db.insert('sugar_readings', cleanSugar)
          : await (db).insert('sugar_readings', cleanSugar);
    }

    // 5. Insert Weight entries
    for (final weight in weightData) {
      final cleanWeight = Map<String, dynamic>.from(weight);
      cleanWeight.remove('id');
      cleanWeight['member_id'] = newMemberId;
      cleanWeight['synced'] = 0;
      kIsWeb
          ? await db.insert('weight_entries', cleanWeight)
          : await (db).insert('weight_entries', cleanWeight);
    }

    // 6. Insert Medicines
    for (final med in medicinesData) {
      final cleanMed = Map<String, dynamic>.from(med);
      final oldId = cleanMed['id'];
      cleanMed.remove('id');
      cleanMed['member_id'] = newMemberId;
      cleanMed['synced'] = 0;

      final newMedId = kIsWeb
          ? await db.insert('medicines', cleanMed)
          : await (db).insert('medicines', cleanMed);

      if (oldId != null) {
        medicineIdMap[oldId.toString()] = newMedId;
      }
    }

    // 7. Insert Medicine logs
    for (final log in logsData) {
      final cleanLog = Map<String, dynamic>.from(log);
      final oldMedId = cleanLog['medicine_id'];
      final newMedId = medicineIdMap[oldMedId.toString()];

      if (newMedId != null) {
        cleanLog.remove('id');
        cleanLog['medicine_id'] = newMedId;
        cleanLog['synced'] = 0;
        kIsWeb
            ? await db.insert('medicine_log', cleanLog)
            : await (db).insert('medicine_log', cleanLog);
      }
    }

    // 8. Insert Medical reports
    for (final report in reportsData) {
      final cleanReport = Map<String, dynamic>.from(report);
      final driveFileId = cleanReport['drive_file_id'] as String?;
      final localPath = cleanReport['local_path'] as String?;
      cleanReport.remove('id');
      cleanReport.remove('drive_file_id');
      cleanReport['member_id'] = newMemberId;
      cleanReport['synced'] = 0;

      if (driveFileId != null && localPath != null && !kIsWeb) {
        try {
          final filename = path.basename(localPath);
          final downloadedFile =
              await _downloadBinaryFile(driveApi, driveFileId, filename);
          cleanReport['local_path'] = downloadedFile.path;
        } catch (e) {
          debugPrint("Failed to download report file: $e");
        }
      }

      kIsWeb
          ? await db.insert('medical_reports', cleanReport)
          : await (db).insert('medical_reports', cleanReport);
    }
  }

  Future<String?> _findFolder(
      drive.DriveApi api, String name, String parentId) async {
    try {
      final query =
          "name = '$name' and mimeType = 'application/vnd.google-apps.folder' and '$parentId' in parents and trashed = false";
      final fileList = await api.files.list(q: query, spaces: 'drive');
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      debugPrint("Error finding folder: $e");
    }
    return null;
  }

  Future<String> _createFolder(
      drive.DriveApi api, String name, String parentId) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = "application/vnd.google-apps.folder"
      ..parents = [parentId];
    final result = await api.files.create(folder);
    return result.id!;
  }

  Future<String> _uploadJsonFile(
      drive.DriveApi api, String name, dynamic data, String parentId) async {
    final content = jsonEncode(data);
    final bytes = utf8.encode(content);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    // Delete existing file if any
    final query =
        "name = '$name' and '$parentId' in parents and trashed = false";
    final fileList = await api.files.list(q: query);
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      for (final f in fileList.files!) {
        await api.files.delete(f.id!);
      }
    }

    final file = drive.File()
      ..name = name
      ..parents = [parentId];

    final result = await api.files.create(file, uploadMedia: media);
    return result.id!;
  }

  Future<String> _uploadBinaryFile(
      drive.DriveApi api, String name, File file, String parentId) async {
    final media = drive.Media(file.openRead(), await file.length());

    // Delete existing file if any
    final query =
        "name = '$name' and '$parentId' in parents and trashed = false";
    final fileList = await api.files.list(q: query);
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      for (final f in fileList.files!) {
        await api.files.delete(f.id!);
      }
    }

    final driveFile = drive.File()
      ..name = name
      ..parents = [parentId];

    final result = await api.files.create(driveFile, uploadMedia: media);
    return result.id!;
  }

  Future<dynamic> _downloadJsonFile(
      drive.DriveApi api, String name, String parentId) async {
    final query =
        "name = '$name' and '$parentId' in parents and trashed = false";
    final fileList = await api.files.list(q: query);
    if (fileList.files == null || fileList.files!.isEmpty) return null;

    final fileId = fileList.files!.first.id!;
    final drive.Media mediaContent = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    final List<int> bytes = [];
    await for (final chunk in mediaContent.stream) {
      bytes.addAll(chunk);
    }
    final content = utf8.decode(bytes);
    return jsonDecode(content);
  }

  Future<File> _downloadBinaryFile(
      drive.DriveApi api, String fileId, String filename) async {
    final drive.Media mediaContent = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final directory = await getApplicationDocumentsDirectory();
    final localPath = path.join(directory.path, "reports",
        "${DateTime.now().millisecondsSinceEpoch}_$filename");

    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);

    final ios = localFile.openWrite();
    await for (final chunk in mediaContent.stream) {
      ios.add(chunk);
    }
    await ios.close();
    return localFile;
  }
}
