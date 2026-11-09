import '../utils/day.dart';

/// Tek bir harcama kaydı. Tutar kuruş cinsinden tam sayıdır (ondalık hata
/// birikmesin diye `double` kullanılmaz).
class Expense {
  const Expense({
    this.id,
    required this.name,
    required this.amountKurus,
    required this.spentAt,
  });

  final int? id;
  final String name;
  final int amountKurus;

  /// Yerel saat.
  final DateTime spentAt;

  /// Gruplama anahtarı: yerel takvim günü (`yyyy-MM-dd`).
  String get dayKey => Day.key(spentAt);

  Expense copyWith({String? name, int? amountKurus, DateTime? spentAt}) {
    return Expense(
      id: id,
      name: name ?? this.name,
      amountKurus: amountKurus ?? this.amountKurus,
      spentAt: spentAt ?? this.spentAt,
    );
  }

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'name': name,
    'amount_kurus': amountKurus,
    'day': dayKey,
    'spent_at': spentAt.toIso8601String(),
  };

  factory Expense.fromRow(Map<String, Object?> row) => Expense(
    id: row['id'] as int?,
    name: row['name'] as String,
    amountKurus: row['amount_kurus'] as int,
    spentAt: DateTime.parse(row['spent_at'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.name == name &&
      other.amountKurus == amountKurus &&
      other.spentAt == spentAt;

  @override
  int get hashCode => Object.hash(id, name, amountKurus, spentAt);
}
