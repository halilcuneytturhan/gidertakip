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
  pdf('PDF', 'Rapor, yazdırmaya uygun', 'pdf', 'application/pdf'),
  word(
    'Word',
    'Rapor, Word ile açılır',
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  csv('CSV (Excel)', 'Tüm harcamalar, Excel ile açılır', 'csv', 'text/csv');

  const ExportFormat(this.label, this.description, this.extension, this.mime);

  final String label;
  final String description;
  final String extension;
  final String mime;

  String get fileName => 'emugider-harcamalar.$extension';
}

/// Harcamalardan PDF ve Word raporu üretir: başlık, özet, en çok harcananlar
/// ve aylara ayrılmış tablolar. Her şey cihazda yapılır. [rows] eskiden yeniye
/// sıralı olmalıdır.
abstract final class ExpenseExport {
  static const String brand = 'EmuGider';
  static const String reportName = 'Harcama Raporu';

  static const int _green = 0xFF0F6B5C;
  static const int _greenSoft = 0xFFE3F0EC;
  static const int _zebra = 0xFFF6F5F2;
  static const int _text = 0xFF1B1B1A;
  static const int _grey = 0xFF5E5C57;
  static const int _line = 0xFFD9D6CE;

  // -------------------------------------------------------------------- PDF

  /// Türkçe harfler için yazı tipleri gömülür (Nunito). [logo] yeşil başlıkta
  /// gösterilen beyaz fiş işaretidir.
  static Future<Uint8List> pdf(
    List<Expense> rows, {
    required ByteData regular,
    required ByteData bold,
    required Uint8List logo,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime generatedAt,
  }) {
    final report = _Report(rows, periodStart, periodEnd);
    final green = PdfColor.fromInt(_green);
    final greenSoft = PdfColor.fromInt(_greenSoft);
    final zebra = PdfColor.fromInt(_zebra);
    final text = PdfColor.fromInt(_text);
    final grey = PdfColor.fromInt(_grey);
    final line = PdfColor.fromInt(_line);
    final logoImage = pw.MemoryImage(logo);

    pw.Widget cell(
      String value, {
      bool right = false,
      bool bold = false,
      double size = 10,
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Text(
        value,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: size,
          color: color ?? text,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    pw.TableRow headerRow(List<String> labels, Set<int> rightColumns) =>
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: greenSoft),
          children: [
            for (var i = 0; i < labels.length; i++)
              cell(
                labels[i],
                bold: true,
                size: 9,
                right: rightColumns.contains(i),
                color: PdfColor.fromInt(_green),
              ),
          ],
        );

    pw.TableBorder tableBorder() => pw.TableBorder(
      bottom: pw.BorderSide(color: line, width: 0.6),
      horizontalInside: pw.BorderSide(color: line, width: 0.4),
    );

    pw.Widget stat(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: greenSoft,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 15,
                color: green,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    final doc = pw.Document(
      title: '$brand $reportName',
      author: brand,
      creator: brand,
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 32),
        // Varsayılan 20 sayfa sınırı uzun geçmişte hata verirdi.
        maxPages: 5000,
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regular),
          bold: pw.Font.ttf(bold),
        ),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: line, width: 0.6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '$brand · $reportName',
                      style: pw.TextStyle(fontSize: 9, color: grey),
                    ),
                    pw.Text(
                      report.period,
                      style: pw.TextStyle(fontSize: 9, color: grey),
                    ),
                  ],
                ),
              ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Oluşturulma: ${_longDate(generatedAt)}',
                style: pw.TextStyle(fontSize: 8.5, color: grey),
              ),
              pw.Text(
                'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8.5, color: grey),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Image(logoImage, width: 38, height: 38),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      brand,
                      style: pw.TextStyle(
                        fontSize: 19,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      reportName,
                      style: pw.TextStyle(fontSize: 11, color: greenSoft),
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dönem',
                      style: pw.TextStyle(fontSize: 9, color: greenSoft),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      report.period,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              stat('Toplam harcama', Money.format(report.total)),
              pw.SizedBox(width: 10),
              stat('Kayıt sayısı', '${report.count}'),
              pw.SizedBox(width: 10),
              stat('Günlük ortalama', Money.format(report.dailyAverage)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'En çok harcananlar',
            style: pw.TextStyle(
              fontSize: 12,
              color: text,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(60),
              2: pw.FixedColumnWidth(60),
              3: pw.FixedColumnWidth(100),
            },
            border: tableBorder(),
            children: [
              headerRow(
                const ['Harcama', 'Adet', 'Pay', 'Tutar'],
                const {1, 2, 3},
              ),
              for (final item in report.top)
                pw.TableRow(
                  children: [
                    cell(_pdfSafe(item.name)),
                    cell('${item.count}', right: true, color: grey),
                    cell(report.share(item), right: true, color: grey),
                    cell(Money.format(item.total), right: true, bold: true),
                  ],
                ),
            ],
          ),
          for (final month in report.months) ...[
            pw.SizedBox(height: 20),
            pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(92),
                1: pw.FixedColumnWidth(78),
                2: pw.FlexColumnWidth(),
                3: pw.FixedColumnWidth(100),
              },
              border: tableBorder(),
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: pw.BoxDecoration(color: green),
                  children: [
                    cell(
                      month.title,
                      bold: true,
                      size: 11,
                      color: PdfColors.white,
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    cell(
                      Money.format(month.total),
                      bold: true,
                      size: 11,
                      right: true,
                      color: PdfColors.white,
                    ),
                  ],
                ),
                headerRow(
                  const ['Tarih', 'Gün', 'Harcama', 'Tutar'],
                  const {3},
                ),
                for (var i = 0; i < month.rows.length; i++)
                  pw.TableRow(
                    decoration: i.isOdd ? pw.BoxDecoration(color: zebra) : null,
                    children: [
                      cell(_date(month.rows[i].spentAt), color: grey),
                      cell(_weekday(month.rows[i].spentAt), color: grey),
                      cell(_pdfSafe(month.rows[i].name)),
                      cell(
                        Money.format(month.rows[i].amountKurus),
                        right: true,
                      ),
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

  /// Gömülü yazı tipinde olmayan emoji vb. PDF'te kutu olarak çıkmasın.
  static String _pdfSafe(String name) {
    final clean = name
        .replaceAll(_symbols, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return clean.isEmpty ? 'Harcama' : clean;
  }

  static final RegExp _symbols = RegExp(
    r'[‍←-⯿︀-️\u{1F000}-\u{1FAFF}]',
    unicode: true,
  );

  // ------------------------------------------------------------------- Word

  static const int _pageWidth = 9638;

  /// .docx: bir zip içinde XML dosyaları (belge, altbilgi, ilişkiler).
  static Uint8List docx(
    List<Expense> rows, {
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime generatedAt,
  }) {
    final report = _Report(rows, periodStart, periodEnd);
    final body = StringBuffer()
      ..write(_banner(report))
      ..write(_spacer(120))
      ..write(_stats(report))
      ..write(
        _para(
          'En çok harcananlar',
          bold: true,
          size: 24,
          before: 280,
          after: 100,
          keepNext: true,
        ),
      )
      ..write(_topTable(report));
    for (final month in report.months) {
      body
        ..write(_spacer(280))
        ..write(_monthTable(month));
    }
    body.write(_spacer(0));

    const wordNs =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
    const relNs =
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
    final document =
        '$_xmlHead<w:document $wordNs $relNs><w:body>$body'
        '<w:sectPr><w:footerReference w:type="default" r:id="rId1"/>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
        'w:header="708" w:footer="567" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>';
    final footer =
        '$_xmlHead<w:ftr $wordNs><w:p><w:pPr><w:tabs><w:tab w:val="right" '
        'w:pos="$_pageWidth"/></w:tabs></w:pPr>'
        '${_run('Oluşturulma: ${_longDate(generatedAt)}', size: 17, color: _grey)}'
        '<w:r><w:tab/></w:r>'
        '${_run('Sayfa ', size: 17, color: _grey)}${_field('PAGE')}'
        '${_run(' / ', size: 17, color: _grey)}${_field('NUMPAGES')}'
        '</w:p></w:ftr>';

    final archive = Archive();
    void add(String name, String content) {
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));
    }

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('word/document.xml', document);
    add('word/footer1.xml', footer);
    add('word/_rels/document.xml.rels', _documentRels);
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static const String _xmlHead =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

  static const String _contentTypes =
      '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
      'package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/footer1.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
      '</Types>';

  static const String _rootRels =
      '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/'
      'package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/></Relationships>';

  static const String _documentRels =
      '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/'
      'package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
      '</Relationships>';

  static String _banner(_Report report) {
    const widths = [5238, 4400];
    return '${_tableStart(widths, borders: false)}<w:tr>'
        '${_cell(widths[0], _para(brand, bold: true, size: 38, color: 0xFFFFFFFF, before: 120) + _para(reportName, size: 22, color: _greenSoft, after: 120), fill: _green)}'
        '${_cell(widths[1], _para('Dönem', size: 18, color: _greenSoft, right: true, before: 160) + _para(report.period, bold: true, size: 21, color: 0xFFFFFFFF, right: true, after: 120), fill: _green)}'
        '</w:tr></w:tbl>';
  }

  static String _stats(_Report report) {
    const widths = [3212, 3213, 3213];
    String stat(int width, String label, String value) => _cell(
      width,
      _para(label, size: 18, color: _grey, before: 100) +
          _para(value, bold: true, size: 30, color: _green, after: 100),
      fill: _greenSoft,
    );
    return '${_tableStart(widths, borders: false)}<w:tr>'
        '${stat(widths[0], 'Toplam harcama', Money.format(report.total))}'
        '${stat(widths[1], 'Kayıt sayısı', '${report.count}')}'
        '${stat(widths[2], 'Günlük ortalama', Money.format(report.dailyAverage))}'
        '</w:tr></w:tbl>';
  }

  static String _topTable(_Report report) {
    const widths = [5438, 1000, 1000, 2200];
    final xml = StringBuffer(_tableStart(widths))
      ..write(
        _headerRow(
          widths,
          const ['Harcama', 'Adet', 'Pay', 'Tutar'],
          const {1, 2, 3},
        ),
      );
    for (final item in report.top) {
      xml.write(
        '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
        '${_cell(widths[0], _para(item.name, cell: true))}'
        '${_cell(widths[1], _para('${item.count}', cell: true, right: true, color: _grey))}'
        '${_cell(widths[2], _para(report.share(item), cell: true, right: true, color: _grey))}'
        '${_cell(widths[3], _para(Money.format(item.total), cell: true, right: true, bold: true))}'
        '</w:tr>',
      );
    }
    xml.write('</w:tbl>');
    return xml.toString();
  }

  static String _monthTable(_Month month) {
    const widths = [1500, 1500, 4438, 2200];
    const white = 0xFFFFFFFF;
    final titleWidth = widths[0] + widths[1] + widths[2];
    final xml = StringBuffer(_tableStart(widths))
      ..write(
        '<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>'
        '${_cell(titleWidth, _para(month.title, cell: true, bold: true, size: 23, color: white, keepNext: true), fill: _green, span: 3)}'
        '${_cell(widths[3], _para(Money.format(month.total), cell: true, bold: true, size: 23, color: white, right: true, keepNext: true), fill: _green)}'
        '</w:tr>',
      )
      ..write(
        _headerRow(
          widths,
          const ['Tarih', 'Gün', 'Harcama', 'Tutar'],
          const {3},
        ),
      );
    for (var i = 0; i < month.rows.length; i++) {
      final e = month.rows[i];
      final fill = i.isOdd ? _zebra : null;
      xml.write(
        '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
        '${_cell(widths[0], _para(_date(e.spentAt), cell: true, color: _grey), fill: fill)}'
        '${_cell(widths[1], _para(_weekday(e.spentAt), cell: true, color: _grey), fill: fill)}'
        '${_cell(widths[2], _para(e.name, cell: true), fill: fill)}'
        '${_cell(widths[3], _para(Money.format(e.amountKurus), cell: true, right: true), fill: fill)}'
        '</w:tr>',
      );
    }
    xml.write('</w:tbl>');
    return xml.toString();
  }

  static String _headerRow(
    List<int> widths,
    List<String> labels,
    Set<int> rightColumns,
  ) {
    final cells = StringBuffer();
    for (var i = 0; i < labels.length; i++) {
      cells.write(
        _cell(
          widths[i],
          _para(
            labels[i],
            cell: true,
            bold: true,
            size: 18,
            color: _green,
            right: rightColumns.contains(i),
            keepNext: true,
          ),
          fill: _greenSoft,
        ),
      );
    }
    return '<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>$cells</w:tr>';
  }

  static String _tableStart(List<int> widths, {bool borders = true}) {
    final color = _hex(_line);
    final border = 'w:val="single" w:sz="4" w:space="0" w:color="$color"';
    final borderXml = borders
        ? '<w:tblBorders><w:bottom $border/><w:insideH $border/></w:tblBorders>'
        : '';
    final total = widths.fold(0, (a, b) => a + b);
    return '<w:tbl><w:tblPr><w:tblW w:w="$total" w:type="dxa"/>$borderXml'
        '<w:tblLayout w:type="fixed"/><w:tblCellMar>'
        '<w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr><w:tblGrid>'
        '${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>';
  }

  static String _cell(int width, String content, {int? fill, int span = 1}) {
    final spanXml = span > 1 ? '<w:gridSpan w:val="$span"/>' : '';
    final shade = fill == null
        ? ''
        : '<w:shd w:val="clear" w:color="auto" w:fill="${_hex(fill)}"/>';
    return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>$spanXml$shade'
        '</w:tcPr>$content</w:tc>';
  }

  /// Tablolar arası boşluk; Word yan yana tabloları birleştirmesin diye şart.
  static String _spacer(int after) =>
      '<w:p><w:pPr><w:spacing w:before="0" w:after="$after" w:line="20" '
      'w:lineRule="exact"/></w:pPr></w:p>';

  static String _para(
    String text, {
    bool bold = false,
    int size = 20,
    int? color,
    int before = 0,
    int after = 0,
    bool right = false,
    bool keepNext = false,
    bool cell = false,
  }) {
    final top = cell ? 60 : before;
    final bottom = cell ? 60 : after;
    return '<w:p><w:pPr>${keepNext ? '<w:keepNext/>' : ''}'
        '<w:spacing w:before="$top" w:after="$bottom"/>'
        '${right ? '<w:jc w:val="right"/>' : ''}</w:pPr>'
        '${_run(text, bold: bold, size: size, color: color)}</w:p>';
  }

  static String _runProps({bool bold = false, int size = 20, int? color}) =>
      '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
      '${bold ? '<w:b/>' : ''}'
      '<w:color w:val="${_hex(color ?? _text)}"/><w:sz w:val="$size"/></w:rPr>';

  static String _run(
    String text, {
    bool bold = false,
    int size = 20,
    int? color,
  }) =>
      '<w:r>${_runProps(bold: bold, size: size, color: color)}'
      '<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';

  /// Sayfa numarası alanı. Word sonucu yeniden çizerken biçimi korusun diye
  /// her parça aynı yazı özellikleriyle yazılır.
  static String _field(String name) {
    final props = _runProps(size: 17, color: _grey);
    String part(String inner) => '<w:r>$props$inner</w:r>';
    return '${part('<w:fldChar w:fldCharType="begin"/>')}'
        '${part('<w:instrText xml:space="preserve"> $name </w:instrText>')}'
        '${part('<w:fldChar w:fldCharType="separate"/>')}'
        '${_run('1', size: 17, color: _grey)}'
        '${part('<w:fldChar w:fldCharType="end"/>')}';
  }

  static String _hex(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ------------------------------------------------------------ ortak biçim

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _longDate(DateTime d) =>
      '${d.day} ${Day.months[d.month - 1]} ${d.year}';

  static String _weekday(DateTime d) => Day.weekdays[d.weekday - 1];
}

/// Raporun hesaplanmış içeriği; PDF ve Word aynı sayıları gösterir.
class _Report {
  _Report(List<Expense> rows, DateTime from, DateTime to)
    : count = rows.length,
      total = rows.fold(0, (sum, e) => sum + e.amountKurus),
      period = _periodOf(from, to),
      months = _monthsOf(rows),
      top = _topOf(rows),
      dailyAverage = _dailyAverageOf(rows, from, to);

  final int count;
  final int total;
  final String period;
  final int dailyAverage;
  final List<_Month> months;
  final List<_NameTotal> top;

  String share(_NameTotal item) =>
      '%${total == 0 ? 0 : (item.total * 100 / total).round()}';

  static String _periodOf(DateTime from, DateTime to) {
    final first = ExpenseExport._longDate(from);
    final last = ExpenseExport._longDate(to);
    return first == last ? first : '$first – $last';
  }

  /// Dönemin ilk gününden son gününe takvim günü başına ortalama (kuruş).
  static int _dailyAverageOf(List<Expense> rows, DateTime from, DateTime to) {
    DateTime utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    final days = utc(to).difference(utc(from)).inDays + 1;
    return (rows.fold(0, (sum, e) => sum + e.amountKurus) / days).round();
  }

  static List<_Month> _monthsOf(List<Expense> rows) {
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

  static List<_NameTotal> _topOf(List<Expense> rows) {
    final byName = <String, _NameTotal>{};
    for (final e in rows) {
      (byName[e.name] ??= _NameTotal(e.name)).add(e.amountKurus);
    }
    final sorted = byName.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return sorted.take(5).toList();
  }
}

class _Month {
  _Month(this.title);

  final String title;
  final List<Expense> rows = [];

  int get total => rows.fold(0, (sum, e) => sum + e.amountKurus);
}

class _NameTotal {
  _NameTotal(this.name);

  final String name;
  int total = 0;
  int count = 0;

  void add(int kurus) {
    total += kurus;
    count++;
  }
}
