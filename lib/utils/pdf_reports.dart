import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReports {
  static Future<Uint8List> tariffario({required String orgName, required List<({String examName, String category, String price})> rows}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)),
        build: (context) => [
          pw.Text('Tariffario - $orgName', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Esame', 'Categoria', 'Prezzo'],
            data: rows.map((r) => [r.examName, r.category, r.price]).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> kpi({
    required String title,
    required Map<String, String> metrics,
  }) async {
    final doc = pw.Document();
    final entries = metrics.entries.toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          ...entries.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text(e.key)),
                  pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
              )),
        ]),
      ),
    );
    return doc.save();
  }
}
