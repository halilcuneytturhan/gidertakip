import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/expense.dart';
import '../utils/day.dart';
import '../utils/money.dart';

/// Ayarlar → Harcamaları dışa aktar seçenekleri.
enum ExportFormat {
  pdf('PDF', 'Okumaya ve yazdırmaya uygun', 'pdf', 'application/pdf'),
  word(
    'Word',
    'Word veya Google Dokümanlar ile açılır',
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  csv(
    'CSV (Excel)',
    'Excel veya Google E-Tablolar ile açılır',
    'csv',
    'text/csv',
  );

  const ExportFormat(this.label, this.description, this.extension, this.mime);

  final String label;
  final String description;
  final String extension;
  final String mime;

  String get fileName => 'emugider-harcamalar.$extension';
}

/// Harcamalardan PDF ve Word belgesi üretir: aylara ayrılmış tablolar ve
/// toplamlar. Her şey cihazda yapılır. [rows] eskiden yeniye sıralı olmalıdır.
abstract final class ExpenseExport {
  static const String title = 'EmuGider harcamaları';
  static const int _green = 0xFF0F6B5C;
  static const int _grey = 0xFF5E5C57;
  static const int _line = 0xFFD9D6CE;

  /// Türkçe harfler için yazı tipleri gömülür (Nunito).
  static Future<Uint8List> pdf(
    List<Expense> rows, {
    required ByteData regular,
    required ByteData bold,
  }) {
    final green = PdfColor.fromInt(_green);
    final grey = PdfColor.fromInt(_grey);
    final line = PdfColor.fromInt(_line);
    const size = 10.5;

    pw.Widget cell(String text, {bool right = false, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: size, color: color),
          ),
        );

    final doc = pw.Document(title: title, creator: 'EmuGider');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        // Varsayılan 20 sayfa sınırı uzun geçmişte hata verirdi.
        maxPages: 5000,
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regular),
          bold: pw.Font.ttf(bold),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: green,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_summary(rows), style: pw.TextStyle(color: grey)),
          for (final month in _months(rows)) ...[
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  month.title,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  Money.format(month.total),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(80),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(100),
              },
              border: pw.TableBorder(
                top: pw.BorderSide(color: line, width: 0.6),
                bottom: pw.BorderSide(color: line, width: 0.6),
                horizontalInside: pw.BorderSide(color: line, width: 0.6),
              ),
              children: [
                for (final e in month.rows)
                  pw.TableRow(
                    children: [
                      cell(_date(e.spentAt), color: grey),
                      cell(e.name),
                      cell(Money.format(e.amountKurus), right: true),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// En sade geçerli .docx: bir zip içinde üç XML dosyası.
  static Uint8List docx(List<Expense> rows) {
    final body = StringBuffer()
      ..write(_para(title, bold: true, size: 36, color: _green, after: 60))
      ..write(_para(_summary(rows), color: _grey, after: 120));
    for (final month in _months(rows)) {
      body
        ..write(
          _para(
            '${month.title} · ${Money.format(month.total)}',
            bold: true,
            size: 26,
            before: 280,
            after: 80,
            keepNext: true,
          ),
        )
        ..write(_table(month.rows));
    }
    body.write(_para(''));

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/'
        'wordprocessingml/2006/main"><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
        'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>';

    final archive = Archive();
    void add(String name, String content) {
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));
    }

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('word/document.xml', document);
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
      'package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  static String _table(List<Expense> rows) {
    const widths = [1600, 5838, 2200];
    const border = 'w:val="single" w:sz="4" w:space="0" w:color="D9D6CE"';
    final xml = StringBuffer(
      '<w:tbl><w:tblPr><w:tblW w:w="9638" w:type="dxa"/><w:tblBorders>'
      '<w:top $border/><w:bottom $border/><w:insideH $border/>'
      '</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>'
      '${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>',
    );
    String cell(int width, String content) =>
        '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>'
        '$content</w:tc>';
    for (final e in rows) {
      xml.write(
        '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
        '${cell(widths[0], _para(_date(e.spentAt), color: _grey, cell: true))}'
        '${cell(widths[1], _para(e.name, cell: true))}'
        '${cell(widths[2], _para(Money.format(e.amountKurus), right: true, cell: true))}'
        '</w:tr>',
      );
    }
    xml.write('</w:tbl>');
    return xml.toString();
  }

  static String _para(
    String text, {
    bool bold = false,
    int size = 21,
    int? color,
    int before = 0,
    int after = 0,
    bool right = false,
    bool keepNext = false,
    bool cell = false,
  }) {
    final top = cell ? 50 : before;
    final bottom = cell ? 50 : after;
    final hex = color == null
        ? ''
        : '<w:color w:val="${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}"/>';
    return '<w:p><w:pPr>${keepNext ? '<w:keepNext/>' : ''}'
        '<w:spacing w:before="$top" w:after="$bottom"/>'
        '${right ? '<w:jc w:val="right"/>' : ''}</w:pPr>'
        '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" '
        'w:cs="Calibri"/>${bold ? '<w:b/>' : ''}$hex<w:sz w:val="$size"/></w:rPr>'
        '<w:t xml:space="preserve">${_escape(text)}</w:t></w:r></w:p>';
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _summary(List<Expense> rows) {
    final total = rows.fold(0, (sum, e) => sum + e.amountKurus);
    return 'Toplam ${Money.format(total)} · ${rows.length} harcama';
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  static List<_Month> _months(List<Expense> rows) {
    final months = <_Month>[];
    for (final e in rows) {
      final title = Day.monthYear(e.spentAt);
      if (months.isEmpty || months.last.title != title) {
        months.add(_Month(title));
      }
      months.last.rows.add(e);
    }
    return months;
  }
}

class _Month {
  _Month(this.title);

  final String title;
  final List<Expense> rows = [];

  int get total => rows.fold(0, (sum, e) => sum + e.amountKurus);
}
