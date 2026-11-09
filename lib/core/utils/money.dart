/// Kuruş ↔ metin dönüşümleri (Türkçe biçim: 1.250,50 TL).
abstract final class Money {
  /// "1.250 TL", "85,50 TL"
  static String format(int kurus, {bool withUnit = true}) {
    final text = number(kurus);
    return withUnit ? '$text TL' : text;
  }

  /// Birimsiz: "1.250", "85,50". Kuruş sıfırsa ondalık yazılmaz.
  static String number(int kurus) {
    final negative = kurus < 0;
    final abs = kurus.abs();
    final lira = abs ~/ 100;
    final rest = abs % 100;
    final grouped = _group(lira);
    final body = rest == 0
        ? grouped
        : '$grouped,${rest.toString().padLeft(2, '0')}';
    return negative ? '−$body' : body;
  }

  /// Takvim hücresi için kısa yazım: 950, 12.500, 125B (100 bin TL ve üstü).
  static String compact(int kurus) {
    final lira = (kurus / 100).round();
    if (lira < 100000) return _group(lira);
    final thousands = lira / 1000;
    final text = thousands < 100
        ? thousands.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')
        : thousands.round().toString();
    return '${text}B';
  }

  static String _group(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
