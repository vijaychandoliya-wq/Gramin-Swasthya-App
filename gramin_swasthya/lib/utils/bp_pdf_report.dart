import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../providers/health_data_provider.dart';
import 'bp_calculator.dart';
import 'bp_summary.dart';

class BPPdfReport {
  /// Generates a PDF document summarising BP readings.
  static pw.Document generate({
    required String patientName,
    required List<BpRecord> readings,
    required int periodDays,
  }) {
    final summary = BPSummary(readings);
    final pdf = pw.Document(
      title: 'BP Report – $patientName',
      author: 'Gramin Swasthya App',
    );

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());

    // Colours
    const headerBg = PdfColor.fromInt(0xFF1565C0);
    const lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(patientName, now, periodDays),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // --- Summary Stats Table ---
          pw.SizedBox(height: 8),
          _sectionTitle('Summary / सारांश'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  _tableHeaderCell(''),
                  _tableHeaderCell('Avg / औसत'),
                  _tableHeaderCell('Min / न्यूनतम'),
                  _tableHeaderCell('Max / अधिकतम'),
                ],
              ),
              // Systolic row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightGrey),
                children: [
                  _tableCell('Systolic (ऊपरी)', bold: true),
                  _tableCell(summary.avgSystolic.toStringAsFixed(0)),
                  _tableCell('${summary.minSystolic}'),
                  _tableCell('${summary.maxSystolic}'),
                ],
              ),
              // Diastolic row
              pw.TableRow(
                children: [
                  _tableCell('Diastolic (नीचे)', bold: true),
                  _tableCell(summary.avgDiastolic.toStringAsFixed(0)),
                  _tableCell('${summary.minDiastolic}'),
                  _tableCell('${summary.maxDiastolic}'),
                ],
              ),
              // Pulse Pressure row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightGrey),
                children: [
                  _tableCell('Pulse Pressure', bold: true),
                  _tableCell(summary.avgPulsePressure.toStringAsFixed(0)),
                  _tableCell('–'),
                  _tableCell('–'),
                ],
              ),
              // MAP row
              pw.TableRow(
                children: [
                  _tableCell('MAP (Mean Arterial)', bold: true),
                  _tableCell(summary.avgMAP.toStringAsFixed(0)),
                  _tableCell('–'),
                  _tableCell('–'),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // --- Category Distribution ---
          _sectionTitle('Category Distribution / श्रेणी वितरण'),
          pw.SizedBox(height: 8),
          _buildCategoryTable(summary, headerBg),

          pw.SizedBox(height: 20),

          // --- All Readings Table ---
          _sectionTitle('All Readings / सभी रीडिंग (${readings.length})'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  _tableHeaderCell('#'),
                  _tableHeaderCell('Date / दिनांक'),
                  _tableHeaderCell('SYS'),
                  _tableHeaderCell('DIA'),
                  _tableHeaderCell('Category / श्रेणी'),
                ],
              ),
              ...readings.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final result = BPCalculator.calculate(r.systolic, r.diastolic);
                final bg = i.isEven
                    ? lightGrey
                    : const PdfColor.fromInt(0xFFFFFFFF);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _tableCell('${i + 1}'),
                    _tableCell(dateFormat.format(r.date)),
                    _tableCell('${r.systolic}'),
                    _tableCell('${r.diastolic}'),
                    _tableCell(result?.category ?? '–'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  // --- Private Helpers ---

  static pw.Widget _buildHeader(String name, String date, int periodDays) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Blood Pressure Report',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1565C0),
              ),
            ),
            pw.Text(
              'Gramin Swasthya',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Patient: $name', style: const pw.TextStyle(fontSize: 12)),
        pw.Text(
          'Period: Last $periodDays days  |  Generated: $date',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'This report is for informational purposes only. Consult your doctor.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF212121),
      ),
    );
  }

  static pw.Widget _buildCategoryTable(BPSummary summary, PdfColor headerBg) {
    final dist = summary.categoryDistribution;
    final total = summary.readings.length;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _tableHeaderCell('Category / श्रेणी'),
            _tableHeaderCell('Count'),
            _tableHeaderCell('%'),
          ],
        ),
        ...dist.entries.map((e) {
          final pct =
              total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
          return pw.TableRow(
            children: [
              _tableCell(e.key),
              _tableCell('${e.value}'),
              _tableCell('$pct%'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
