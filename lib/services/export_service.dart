import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/budget.dart';
import '../models/campaign.dart';
import '../models/customer.dart';
import '../models/lead.dart';
import '../models/opportunity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExportService
//
// Generates CSV and PDF exports for all major modules.
// Uses the `csv` package for CSV and `pdf` package for PDF.
// Files are saved/downloaded via `file_saver`.
//
// Usage:
//   await ExportService.exportCsv(context, 'Campaigns');
//   await ExportService.exportPdf(context, 'Leads');
// ─────────────────────────────────────────────────────────────────────────────

class ExportService {
  ExportService._();

  // ── Public entry points ────────────────────────────────────────────────────

  static Future<void> export(
    BuildContext context, {
    required String module,
    required ExportFormat format,
  }) async {
    try {
      switch (format) {
        case ExportFormat.csv:
          await _exportCsv(module);
          break;
        case ExportFormat.pdf:
          await _exportPdf(module);
          break;
        case ExportFormat.excel:
          // Excel export falls back to CSV with .xlsx extension note.
          await _exportCsv(module, asExcel: true);
          break;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$module export downloaded as ${format.name.toUpperCase()}.'),
          backgroundColor: const Color(0xFF22A06B),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: const Color(0xFFE5484D),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── CSV ────────────────────────────────────────────────────────────────────

  static Future<void> _exportCsv(String module, {bool asExcel = false}) async {
    final rows = _getRows(module);
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csv.codeUnits);
    final ext = asExcel ? 'csv' : 'csv';
    final name = '${module.toLowerCase().replaceAll(' ', '_')}_export';

    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: ext,
      mimeType: MimeType.csv,
    );
  }

  // ── PDF ────────────────────────────────────────────────────────────────────

  static Future<void> _exportPdf(String module) async {
    final doc = pw.Document();
    final rows = _getRows(module);
    if (rows.isEmpty) return;

    final headers = rows.first.map((h) => h.toString()).toList();
    final dataRows = rows.skip(1).toList();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('MarketFlow — $module Report',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Generated: ${_formatDate(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400),
        ],
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: dataRows.map((r) => r.map((c) => c.toString()).toList()).toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          rowDecoration: const pw.BoxDecoration(),
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey100),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          columnWidths: {
            for (var i = 0; i < headers.length; i++)
              i: const pw.FlexColumnWidth(),
          },
        ),
      ],
    ));

    final bytes = await doc.save();
    final name = '${module.toLowerCase().replaceAll(' ', '_')}_export';
    await FileSaver.instance.saveFile(
      name: name,
      bytes: Uint8List.fromList(bytes),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  // ── Row builders ───────────────────────────────────────────────────────────

  static List<List<dynamic>> _getRows(String module) {
    switch (module) {
      case 'Campaigns':
        return _campaignRows();
      case 'Customers':
        return _customerRows();
      case 'Leads':
        return _leadRows();
      case 'Opportunities':
        return _opportunityRows();
      case 'Budget':
        return _budgetRows();
      default:
        return [];
    }
  }

  static List<List<dynamic>> _campaignRows() {
    final campaigns = CampaignRepository.getAll();
    return [
      ['ID', 'Name', 'Status', 'Objective', 'Channels', 'Budget (ETB)',
       'Spent (ETB)', 'Leads', 'Conversions', 'ROI', 'Start Date', 'End Date'],
      ...campaigns.map((c) => [
            c.id,
            c.name,
            c.status,
            c.objective.label,
            c.channels.map((ch) => ch.label).join(', '),
            c.budget.toStringAsFixed(2),
            c.spent.toStringAsFixed(2),
            c.leads,
            c.conversions,
            '${c.roi.toStringAsFixed(1)}x',
            c.startDate != null ? _formatDate(c.startDate!) : '',
            c.endDate != null ? _formatDate(c.endDate!) : '',
          ]),
    ];
  }

  static List<List<dynamic>> _customerRows() {
    final customers = CustomerRepository.getAll();
    return [
      ['ID', 'Name', 'Email', 'Phone', 'Segment', 'Status',
       'Last Activity', 'Joined At'],
      ...customers.map((c) => [
            c.id,
            c.name,
            c.email,
            c.phone,
            c.segment,
            c.status,
            _formatDate(c.lastActivity),
            _formatDate(c.joinedAt),
          ]),
    ];
  }

  static List<List<dynamic>> _leadRows() {
    final leads = LeadRepository.getAll();
    return [
      ['ID', 'Name', 'Company', 'Email', 'Phone', 'Source',
       'Score', 'Assigned To', 'Status', 'Priority', 'Created At'],
      ...leads.map((l) => [
            l.id,
            l.name,
            l.company,
            l.email,
            l.phone,
            l.source,
            l.score,
            l.assignedTo,
            l.status,
            l.priority,
            _formatDate(l.createdAt),
          ]),
    ];
  }

  static List<List<dynamic>> _opportunityRows() {
    final opps = OpportunityRepository.getAll();
    return [
      ['ID', 'Name', 'Company', 'Value (ETB)', 'Owner',
       'Probability (%)', 'Stage', 'Created At'],
      ...opps.map((o) => [
            o.id,
            o.name,
            o.company,
            o.value.toStringAsFixed(2),
            o.owner,
            o.probability,
            o.stage,
            _formatDate(o.createdAt),
          ]),
    ];
  }

  static List<List<dynamic>> _budgetRows() {
    final budgets = BudgetRepository.getAll();
    return [
      ['ID', 'Name', 'Category', 'Allocated (ETB)', 'Spent (ETB)',
       'Remaining (ETB)', 'Utilization (%)', 'Status', 'Start Date', 'End Date'],
      ...budgets.map((b) => [
            b.id,
            b.name,
            b.category,
            b.allocated.toStringAsFixed(2),
            b.spent.toStringAsFixed(2),
            b.remaining.toStringAsFixed(2),
            '${(b.utilization * 100).toStringAsFixed(1)}%',
            b.status,
            _formatDate(b.startDate),
            _formatDate(b.endDate),
          ]),
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum ExportFormat { csv, pdf, excel }

// ─────────────────────────────────────────────────────────────────────────────
// ExportMenuButton — reusable popup menu for any screen
// ─────────────────────────────────────────────────────────────────────────────

class ExportMenuButton extends StatelessWidget {
  final String module;
  final Color? foregroundColor;

  const ExportMenuButton({
    super.key,
    required this.module,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = foregroundColor ??
        (brightness == Brightness.dark
            ? const Color(0xFFE2E8F0)
            : const Color(0xFF374151));

    return PopupMenuButton<ExportFormat>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: brightness == Brightness.dark
              ? const Color(0xFF374151)
              : const Color(0xFFE5E7EB),
        ),
      ),
      color: brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      elevation: 4,
      offset: const Offset(0, 40),
      onSelected: (format) =>
          ExportService.export(context, module: module, format: format),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: ExportFormat.csv,
          child: Row(children: [
            Icon(Icons.table_rows_outlined, size: 15, color: textColor),
            const SizedBox(width: 8),
            Text('Export CSV',
                style: TextStyle(fontSize: 13, color: textColor)),
          ]),
        ),
        PopupMenuItem(
          value: ExportFormat.pdf,
          child: Row(children: [
            Icon(Icons.picture_as_pdf_outlined, size: 15, color: textColor),
            const SizedBox(width: 8),
            Text('Export PDF',
                style: TextStyle(fontSize: 13, color: textColor)),
          ]),
        ),
        PopupMenuItem(
          value: ExportFormat.excel,
          child: Row(children: [
            Icon(Icons.grid_on_outlined, size: 15, color: textColor),
            const SizedBox(width: 8),
            Text('Export Excel (CSV)',
                style: TextStyle(fontSize: 13, color: textColor)),
          ]),
        ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export'),
        ),
      ),
    );
  }
}
