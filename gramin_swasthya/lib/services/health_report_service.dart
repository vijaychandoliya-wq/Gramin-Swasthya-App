import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../providers/family_provider.dart';
import '../providers/health_data_provider.dart';

/// Creates a profile-scoped BP and sugar tracking report.
///
/// Chart images are captured from real fl_chart widgets through a
/// RepaintBoundary. The capture host is placed in the root overlay at nearly
/// transparent opacity and removed before the share sheet is opened, so the
/// report screen never needs to be visible to the user.
class HealthReportService {
  HealthReportService._();

  // Keep Latin text and numbers in the primary font. Indic scripts are
  // supplied through the fallback list below; using a Devanagari font as the
  // primary font caused English labels and timestamps to become tofu boxes.
  static const _regularFontAsset = 'fonts/NotoSans-Regular.ttf';
  static const _boldFontAsset = 'fonts/NotoSans-Bold.ttf';
  static const _fallbackFontAssets = [
    'fonts/NotoSansDevanagari-Regular.ttf',
    'fonts/NotoSansBengali-Regular.ttf',
    'fonts/NotoSansGujarati-Regular.ttf',
    'fonts/NotoSansGurmukhi-Regular.ttf',
    'fonts/NotoSansKannada-Regular.ttf',
    'fonts/NotoSansMalayalam-Regular.ttf',
    'fonts/NotoSansOriya-Regular.ttf',
    'fonts/NotoSansTamil-Regular.ttf',
    'fonts/NotoSansTelugu-Regular.ttf',
  ];

  static Future<Uint8List> captureChart({
    required BuildContext context,
    required Widget chart,
    Size size = const Size(720, 360),
    double pixelRatio = 3,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: Opacity(
            // Keep the render tree alive for toImage while remaining
            // imperceptible. It is removed immediately after the frame.
            opacity: 0.001,
            child: Material(
              color: Colors.white,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                    width: size.width, height: size.height, child: chart),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('The trend chart did not finish rendering.');
      }
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('The trend chart image was empty.');
      return bytes.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  static Widget buildBpChart(List<BpRecord> records) {
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return _emptyChart('No BP readings');

    return _chartFrame(
      title: 'BP trend',
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, sorted.length - 1).toDouble(),
          minY: 40,
          maxY: 220,
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(
                sorted.map((r) => r.systolic.toDouble()).toList(), Colors.red),
            _line(sorted.map((r) => r.diastolic.toDouble()).toList(),
                Colors.blue),
          ],
        ),
      ),
    );
  }

  static Widget buildSugarChart(List<SugarRecord> records) {
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return _emptyChart('No sugar readings');

    final values = sorted.map((r) => r.glucose.toDouble()).toList();
    final maxValue =
        values.reduce(math.max).clamp(160, double.infinity).toDouble();
    final minValue =
        values.reduce(math.min).clamp(40, double.infinity).toDouble();
    return _chartFrame(
      title: 'Sugar trend',
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, values.length - 1).toDouble(),
          minY: math.max(0, minValue - 20),
          maxY: maxValue + 20,
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [_line(values, Colors.blue)],
        ),
      ),
    );
  }

  static Future<File> generateAndShare({
    required BuildContext context,
    required FamilyMember member,
    List<BpRecord>? bpReadings,
    List<SugarRecord>? sugarReadings,
  }) async {
    final file = await generate(
      context: context,
      member: member,
      bpReadings: bpReadings,
      sugarReadings: sugarReadings,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Health report - ${member.name}',
      text: 'BP and sugar tracking report for ${member.name}.',
    );
    return file;
  }

  static Future<File> generate({
    required BuildContext context,
    required FamilyMember member,
    List<BpRecord>? bpReadings,
    List<SugarRecord>? sugarReadings,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final bp = bpReadings ?? await _loadBp(db, member.id);
    final sugar = sugarReadings ?? await _loadSugar(db, member.id);

    Uint8List? bpImage;
    Uint8List? sugarImage;
    try {
      bpImage = await captureChart(
        context: context,
        chart: buildBpChart(bp),
      );
      sugarImage = await captureChart(
        context: context,
        chart: buildSugarChart(sugar),
      );
    } catch (error) {
      // A report without a chart is still useful when an OEM prevents an
      // off-screen frame from painting.
      debugPrint('Trend chart capture skipped: $error');
    }

    final regular = pw.Font.ttf(await rootBundle.load(_regularFontAsset));
    final bold = pw.Font.ttf(await rootBundle.load(_boldFontAsset));
    final fallbackFonts = <pw.Font>[];
    for (final asset in _fallbackFontAssets) {
      fallbackFonts.add(pw.Font.ttf(await rootBundle.load(asset)));
    }
    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: fallbackFonts,
    );
    final now = DateTime.now();
    final document = pw.Document(theme: theme);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(now)} | Tracking only - consult a doctor for diagnosis.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.teal, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GRAMIN SWASTHYA',
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal)),
                      pw.Text('Doctor / Clinic Health Tracking Report',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ]),
                pw.Text(DateFormat('dd MMM yyyy').format(now),
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Patient details',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2)
            },
            children: [
              _detailRow('Name', member.name, 'Age',
                  member.age > 0 ? '${member.age}' : '-'),
              _detailRow('Gender', _value(member.gender), 'Emergency',
                  _emergency(member)),
              _detailRow('Phone', _value(member.phone), 'Blood group',
                  _value(member.bloodGroup)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Trend graphs',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal)),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                  child: bpImage == null
                      ? _missingChart('BP graph unavailable')
                      : pw.Image(pw.MemoryImage(bpImage),
                          fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 10),
              pw.Expanded(
                  child: sugarImage == null
                      ? _missingChart('Sugar graph unavailable')
                      : pw.Image(pw.MemoryImage(sugarImage),
                          fit: pw.BoxFit.contain)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Blood pressure readings',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal)),
          pw.SizedBox(height: 6),
          _bpTable(bp),
          pw.SizedBox(height: 18),
          pw.Text('Sugar readings',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal)),
          pw.SizedBox(height: 6),
          _sugarTable(sugar),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            color: PdfColors.amber50,
            child: pw.Text(
                'Medical disclaimer: This report is a record of measurements and trends, not a diagnosis. Consult a qualified doctor for interpretation and treatment.',
                style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final reportDirectory =
        Directory(path.join(directory.path, 'medical_reports'));
    await reportDirectory.create(recursive: true);
    final safeName =
        member.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final file = File(path.join(reportDirectory.path,
        'health_report_${safeName}_${now.millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await document.save(), flush: true);

    await db.insert('medical_reports', {
      'member_id': int.tryParse(member.id),
      'type': 'BP and Sugar Health Report',
      'local_path': file.path,
      'firebase_url': '',
      'doctor_name': 'Gramin Swasthya',
      'report_date': now.toIso8601String(),
      'notes': 'Generated tracking report',
      'synced': 0,
    });
    return file;
  }

  static Future<List<BpRecord>> _loadBp(dynamic db, String memberId) async {
    final rows = await db.query('bp_readings',
        where: 'member_id = ?',
        whereArgs: [int.tryParse(memberId) ?? memberId],
        orderBy: 'recorded_at DESC');
    return rows
        .map<BpRecord>((row) => BpRecord(
              id: '${row['id']}',
              systolic: (row['systolic'] as num?)?.toInt() ?? 0,
              diastolic: (row['diastolic'] as num?)?.toInt() ?? 0,
              pulse: (row['pulse'] as num?)?.toInt(),
              date:
                  DateTime.tryParse('${row['recorded_at']}') ?? DateTime.now(),
            ))
        .where((r) => r.systolic > 0 && r.diastolic > 0)
        .toList();
  }

  static Future<List<SugarRecord>> _loadSugar(
      dynamic db, String memberId) async {
    final rows = await db.query('sugar_readings',
        where: 'member_id = ?',
        whereArgs: [int.tryParse(memberId) ?? memberId],
        orderBy: 'recorded_at DESC');
    return rows
        .map<SugarRecord>((row) => SugarRecord(
              id: '${row['id']}',
              glucose: (row['value'] as num?)?.toInt() ?? 0,
              type: '${row['type'] ?? '-'}',
              date:
                  DateTime.tryParse('${row['recorded_at']}') ?? DateTime.now(),
            ))
        .where((r) => r.glucose > 0)
        .toList();
  }

  static pw.TableRow _detailRow(
          String key1, String value1, String key2, String value2) =>
      pw.TableRow(children: [
        _cell(key1, bold: true),
        _cell(value1),
        _cell(key2, bold: true),
        _cell(value2),
      ]);

  static pw.Widget _cell(String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _bpTable(List<BpRecord> readings) {
    final data = readings.isEmpty
        ? [
            ['-', '-', '-', '-', 'No readings']
          ]
        : readings
            .map((r) => [
                  '${r.systolic}',
                  '${r.diastolic}',
                  r.pulse?.toString() ?? '-',
                  DateFormat('yyyy-MM-dd HH:mm').format(r.date),
                  r.systolic >= 140 || r.diastolic >= 90 ? 'High' : 'Recorded',
                ])
            .toList();
    return pw.TableHelper.fromTextArray(
      headers: const ['Systolic', 'Diastolic', 'Pulse', 'Timestamp', 'Status'],
      data: data,
      headerStyle: pw.TextStyle(
          fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.all(5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
    );
  }

  static pw.Widget _sugarTable(List<SugarRecord> readings) {
    final data = readings.isEmpty
        ? [
            ['-', '-', '-', 'No readings']
          ]
        : readings
            .map((r) => [
                  r.type,
                  '${r.glucose} mg/dL',
                  DateFormat('yyyy-MM-dd HH:mm').format(r.date),
                  r.glucose >= 140 ? 'High' : 'Recorded',
                ])
            .toList();
    return pw.TableHelper.fromTextArray(
      headers: const ['Measurement type', 'Value', 'Timestamp', 'Status'],
      data: data,
      headerStyle: pw.TextStyle(
          fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.all(5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
    );
  }

  static String _value(String? value) =>
      value?.trim().isNotEmpty == true ? value!.trim() : '-';
  static String _emergency(FamilyMember member) {
    final name = _value(member.emergencyContactName);
    final phone = _value(member.emergencyPhone);
    return name == '-' && phone == '-' ? '-' : '$name $phone';
  }

  static pw.Widget _missingChart(String text) => pw.Container(
      height: 100,
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
  static Widget _emptyChart(String text) =>
      _chartFrame(title: text, chart: Center(child: Text(text)));
  static Widget _chartFrame({required String title, required Widget chart}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: chart)
        ]),
      );
  static LineChartBarData _line(List<double> values, Color color) =>
      LineChartBarData(
        spots: values
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList(),
        color: color,
        barWidth: 3,
        isCurved: true,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
      );
}
