import 'dart:convert';
import 'dart:typed_data';

import '../models/expense.dart';
import '../utils/expense_parser.dart';

/// Geri yükleme sonucu.
class RestoreResult {
  const RestoreResult({
    required this.added,
    required this.duplicates,
    required this.skipped,
  });

  /// Yeni eklenen kayıt sayısı.
  final int added;

  /// Cihazda zaten bulunduğu için eklenmeyen kayıt sayısı.
  final int duplicates;

  /// Okunamayan satır sayısı.
  final int skipped;
}

/// Dışa aktarılan CSV'yi (Tarih;Saat;Harcama;Tutar) geri okur. Dosya Excel'de
/// açılıp kaydedilmiş olsa da ("09.11.2026", "1.250,50") okunabilir.
abstract final class ExpenseBackup {
  /// Dosya EmuGider yedeği değilse `null`.
  static ({List<Expense> rows, int skipped})? parse(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes).replaceFirst('﻿', '');
    } on FormatException {
      return null;
    }
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty || !_isHeader(_fields(lines.first))) return null;

    final rows = <Expense>[];
    var skipped = 0;
    for (final line in lines.skip(1)) {
      if (line.replaceAll(';', '').trim().isEmpty) continue;
      final expense = _expense(_fields(line));
      if (expense == null) {
        skipped++;
      } else {
        rows.add(expense);
      }
    }
    return (rows: rows, skipped: skipped);
  }

  /// Aynı kaydı tanıma anahtarı. CSV'de saniye olmadığı için dakika kullanılır.
  static String key(Expense e) =>
      '${e.dayKey}|${e.spentAt.hour}:${e.spentAt.minute}|'
      '${e.name}|${e.amountKurus}';

  static bool _isHeader(List<String> fields) =>
      fields.length >= 4 &&
      fields[0].trim() == 'Tarih' &&
      fields[1].trim() == 'Saat' &&
      fields[2].trim() == 'Harcama' &&
      fields[3].trim().startsWith('Tutar');

  static Expense? _expense(List<String> fields) {
    if (fields.length < 4) return null;
    final day = _day(fields[0].trim());
    final time = _time.firstMatch(fields[1].trim());
    final amount = ExpenseParser.parseAmount(fields[3].replaceAll(' ', ''));
    if (day == null || time == null || amount == null) return null;
    if (amount <= 0 || amount > ExpenseParser.maxKurus) return null;
    final hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    if (hour > 23 || minute > 59) return null;

    var name = fields[2].trim();
    if (name.isEmpty) name = ExpenseParser.fallbackName;
    if (name.length > ExpenseParser.maxNameLength) {
      name = name.substring(0, ExpenseParser.maxNameLength).trimRight();
    }
    return Expense(
      name: name,
      amountKurus: amount,
      spentAt: DateTime(day.year, day.month, day.day, hour, minute),
    );
  }

  static final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final RegExp _dotDate = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');
  static final RegExp _time = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$');

  static DateTime? _day(String text) {
    final int year, month, day;
    final iso = _isoDate.firstMatch(text);
    final dot = _dotDate.firstMatch(text);
    if (iso != null) {
      year = int.parse(iso.group(1)!);
      month = int.parse(iso.group(2)!);
      day = int.parse(iso.group(3)!);
    } else if (dot != null) {
      day = int.parse(dot.group(1)!);
      month = int.parse(dot.group(2)!);
      year = int.parse(dot.group(3)!);
    } else {
      return null;
    }
    final date = DateTime(year, month, day);
    // 31.02.2026 gibi tarihler kaymasın, geçersiz sayılsın.
    return date.month == month && date.day == day ? date : null;
  }

  /// Noktalı virgülle ayrılmış satır; `"` içindeki ayraçlar ve `""` korunur.
  static List<String> _fields(String line) {
    final fields = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quoted) {
        if (c != '"') {
          field.write(c);
        } else if (i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ';') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(c);
      }
    }
    fields.add(field.toString());
    return fields;
  }
}
