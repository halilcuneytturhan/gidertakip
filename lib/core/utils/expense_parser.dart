/// Tek satırlık girişi ("taksi 250", "kahve 85,50", "1.250 tl market")
/// ada ve tutara ayırır. Yapay zekâ yok; çevrimdışı, kural tabanlı.
///
/// Kurallar:
/// - Satırdaki **son** sayı tutardır ("2 simit 30" → "2 simit", 30 TL).
/// - Sayının hemen yanındaki ya da ardındaki `tl`, `₺`, `lira` atılır.
/// - `85,50` ve `85.50` ondalıktır; `1.250` ve `1,250` binlik ayraçtır;
///   `1.250,50` ikisi birden.
/// - Ad boş kalırsa "Harcama" yazılır; ilk harf Türkçe kurala göre büyütülür.
abstract final class ExpenseParser {
  static const String fallbackName = 'Harcama';
  static const int maxNameLength = 60;

  /// 10 milyon TL üstü yazım hatası sayılır.
  static const int maxKurus = 10000000 * 100;

  static final RegExp _plain = RegExp(r'^\d+$');
  static final RegExp _decimal = RegExp(r'^(\d+)[.,](\d{1,2})$');
  static final RegExp _dotThousands = RegExp(
    r'^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$',
  );
  static final RegExp _commaThousands = RegExp(
    r'^\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?$',
  );
  static final RegExp _unitSuffix = RegExp(
    r'(tl|₺|lira)$',
    caseSensitive: false,
  );
  static final RegExp _unitWord = RegExp(
    r'^(tl|₺|lira)$',
    caseSensitive: false,
  );

  static ParsedExpense? parse(String input) {
    final tokens = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    int? amountIndex;
    int? amount;
    for (var i = tokens.length - 1; i >= 0; i--) {
      final value = parseAmount(tokens[i]);
      if (value != null) {
        amountIndex = i;
        amount = value;
        break;
      }
    }
    if (amountIndex == null || amount == null) return null;
    if (amount <= 0 || amount > maxKurus) return null;

    final nameTokens = <String>[
      for (var i = 0; i < tokens.length; i++)
        if (i != amountIndex &&
            !(_unitWord.hasMatch(tokens[i]) &&
                (i == amountIndex + 1 || i == amountIndex - 1)))
          tokens[i],
    ];
    var name = nameTokens.join(' ').trim();
    if (name.isEmpty) name = fallbackName;
    if (name.length > maxNameLength) {
      name = name.substring(0, maxNameLength).trimRight();
    }
    return ParsedExpense(name: capitalize(name), amountKurus: amount);
  }

  /// Tek bir parçayı kuruşa çevirir; sayı değilse `null`.
  static int? parseAmount(String token) {
    var t = token.trim();
    if (t.startsWith('₺')) t = t.substring(1);
    t = t.replaceFirst(_unitSuffix, '');
    if (t.isEmpty) return null;

    if (_plain.hasMatch(t)) return _toKurus(t, '');
    final decimal = _decimal.firstMatch(t);
    if (decimal != null) return _toKurus(decimal.group(1)!, decimal.group(2)!);
    if (_dotThousands.hasMatch(t)) {
      final parts = t.split(',');
      return _toKurus(
        parts[0].replaceAll('.', ''),
        parts.length > 1 ? parts[1] : '',
      );
    }
    if (_commaThousands.hasMatch(t)) {
      final parts = t.split('.');
      return _toKurus(
        parts[0].replaceAll(',', ''),
        parts.length > 1 ? parts[1] : '',
      );
    }
    return null;
  }

  static int? _toKurus(String lira, String fraction) {
    if (lira.length > 12) return null;
    final whole = int.tryParse(lira);
    if (whole == null) return null;
    final cents = fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0'));
    return whole * 100 + cents;
  }

  /// İlk harfi Türkçe kurala göre büyütür (i → İ, ı → I).
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    final first = text[0];
    final upper = switch (first) {
      'i' => 'İ',
      'ı' => 'I',
      _ => first.toUpperCase(),
    };
    return upper + text.substring(1);
  }
}

class ParsedExpense {
  const ParsedExpense({required this.name, required this.amountKurus});

  final String name;
  final int amountKurus;

  @override
  bool operator ==(Object other) =>
      other is ParsedExpense &&
      other.name == name &&
      other.amountKurus == amountKurus;

  @override
  int get hashCode => Object.hash(name, amountKurus);

  @override
  String toString() => 'ParsedExpense($name, $amountKurus)';
}
