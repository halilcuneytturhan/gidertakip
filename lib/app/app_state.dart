import 'package:flutter/foundation.dart';

import '../core/models/expense.dart';
import '../core/services/app_database.dart';
import '../core/services/expense_backup.dart';
import '../core/utils/day.dart';
import '../core/utils/expense_parser.dart';

/// Uygulama genelindeki veri: bugünün harcamaları ve geçmiş sorguları.
/// Tüm yazmalar önce yerel veritabanına yapılır, ardından dinleyiciler
/// bilgilendirilir. Her değişiklikte [revision] artar; geçmiş ekranı buna
/// bakarak kendi sorgusunu yeniler.
class AppState extends ChangeNotifier {
  AppState({required this.database, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() _clock;

  bool _loaded = false;
  DateTime _today = DateTime(2000);
  List<Expense> _todayExpenses = const [];
  List<ParsedExpense> _frequent = const [];
  List<ParsedExpense> _favorites = const [];
  int _revision = 0;

  bool get isLoaded => _loaded;
  DateTime get now => _clock();
  DateTime get today => _today;
  int get revision => _revision;

  /// En yeni önce.
  List<Expense> get todayExpenses => List.unmodifiable(_todayExpenses);
  int get todayTotal => _todayExpenses.fold(0, (sum, e) => sum + e.amountKurus);

  /// Son 60 günde en az iki kez yazılmış harcamalar (en fazla 4); giriş
  /// kutusunun altında tek dokunuşla eklenecek çipler olarak gösterilir.
  List<ParsedExpense> get frequent => List.unmodifiable(_frequent);

  /// Kullanıcının kendi eklediği sık kullanılanlar.
  List<ParsedExpense> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(ParsedExpense item) => _favorites.contains(item);

  /// Çip olarak gösterilecekler: önce kullanıcının ekledikleri, kalan yer
  /// (toplam [maxQuickItems] olana kadar) otomatik sık yazılanlarla dolar.
  List<ParsedExpense> get quickItems {
    final room = maxQuickItems - _favorites.length;
    return [
      ..._favorites,
      if (room > 0)
        ..._frequent.where((e) => !_favorites.contains(e)).take(room),
    ];
  }

  static const int frequentWindowDays = 60;
  static const int maxQuickItems = 4;

  Future<void> load() async {
    await _reloadToday(notify: false);
    _loaded = true;
    _changed();
  }

  /// Uygulama gece yarısından sonra öne gelirse "bugün" yenilenir.
  Future<void> refreshIfDayChanged() async {
    if (!_loaded || Day.same(_today, _clock())) return;
    await load();
  }

  /// "taksi 250" gibi bir satırı kaydeder. Tutar bulunamazsa `null`.
  /// [day] verilirse (geçmiş güne ekleme) kayıt o güne yazılır.
  Future<Expense?> addFromText(String text, {DateTime? day}) async {
    final parsed = ExpenseParser.parse(text);
    if (parsed == null) return null;
    return add(
      name: parsed.name,
      amountKurus: parsed.amountKurus,
      at: day == null ? null : timeFor(day),
    );
  }

  /// Bir güne eklenecek kaydın zamanı: bugünse şimdi, geçmiş günse 12:00.
  DateTime timeFor(DateTime day) {
    final now = _clock();
    return Day.same(day, now)
        ? now
        : DateTime(day.year, day.month, day.day, 12);
  }

  Future<Expense> add({
    required String name,
    required int amountKurus,
    DateTime? at,
  }) async {
    final saved = await database.insert(
      Expense(name: name, amountKurus: amountKurus, spentAt: at ?? _clock()),
    );
    await _reloadToday();
    return saved;
  }

  Future<void> update(Expense expense) async {
    await database.update(expense);
    await _reloadToday();
  }

  Future<void> delete(Expense expense) async {
    if (expense.id == null) return;
    await database.delete(expense.id!);
    await _reloadToday();
  }

  /// Silmeyi geri al: aynı ad, tutar ve zamanla yeniden ekler.
  Future<void> restore(Expense expense) async {
    await database.insert(
      Expense(
        name: expense.name,
        amountKurus: expense.amountKurus,
        spentAt: expense.spentAt,
      ),
    );
    await _reloadToday();
  }

  /// "Sigara 125" gibi bir satırı sık kullanılanlara ekler (harcama yazmaz).
  /// Tutar bulunamazsa `null`.
  Future<ParsedExpense?> addFavoriteFromText(String text) async {
    final parsed = ExpenseParser.parse(text);
    if (parsed == null) return null;
    await addFavorite(parsed);
    return parsed;
  }

  Future<void> addFavorite(ParsedExpense item) async {
    await database.insertFavorite(item.name, item.amountKurus);
    await _reloadToday();
  }

  Future<void> removeFavorite(ParsedExpense item) async {
    await database.deleteFavorite(item.name, item.amountKurus);
    await _reloadToday();
  }

  Future<List<Expense>> expensesOn(DateTime day) =>
      database.expensesOn(Day.key(day));

  /// Rapor alınabilecek aylar (ayın 1'i) ve toplamları, en yeni önce.
  Future<List<({DateTime month, int totalKurus})>> reportMonths() async {
    final rows = await database.monthsWithExpenses();
    return [
      for (final r in rows)
        (
          month: DateTime.parse('${r['month']}-01'),
          totalKurus: r['total'] as int,
        ),
    ];
  }

  /// [from] ile [to] günleri (ikisi dahil) arasındaki kayıtlar, eskiden yeniye.
  Future<List<Expense>> expensesBetween(DateTime from, DateTime to) =>
      database.between(Day.key(from), Day.key(to));

  /// Dışa aktarım için tüm kayıtlar, eskiden yeniye.
  Future<List<Expense>> allExpenses() => database.all();

  /// Ayın gün → toplam (kuruş) haritası; harcama olmayan günler yoktur.
  Future<Map<int, int>> monthTotals(int year, int month) async {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month, Day.daysInMonth(year, month));
    final totals = await database.dailyTotals(Day.key(first), Day.key(last));
    return {
      for (final entry in totals.entries)
        int.parse(entry.key.substring(8, 10)): entry.value,
    };
  }

  /// Ayda en çok harcanan adlar (en fazla 5); en yüksek toplam önce.
  Future<List<({String name, int totalKurus, int count})>> monthTop(
    int year,
    int month,
  ) async {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month, Day.daysInMonth(year, month));
    final rows = await database.topByName(Day.key(first), Day.key(last));
    return [
      for (final r in rows)
        (
          name: r['name'] as String,
          totalKurus: r['total'] as int,
          count: r['uses'] as int,
        ),
    ];
  }

  /// Tüm kayıtlar CSV olarak (tarih;saat;ad;tutar). Excel'in Türkçe
  /// ayarlarıyla açılsın diye ayraç noktalı virgül, ondalık virgüldür.
  Future<String> exportCsv() async {
    final rows = await database.all();
    final buffer = StringBuffer('Tarih;Saat;Harcama;Tutar (TL)\n');
    for (final e in rows) {
      final time =
          '${e.spentAt.hour.toString().padLeft(2, '0')}:'
          '${e.spentAt.minute.toString().padLeft(2, '0')}';
      final lira = e.amountKurus ~/ 100;
      final kurus = (e.amountKurus % 100).toString().padLeft(2, '0');
      final name = e.name.replaceAll('"', '""');
      buffer.writeln('${e.dayKey};$time;"$name";$lira,$kurus');
    }
    return buffer.toString();
  }

  /// Dışa aktarılmış CSV'deki harcamaları ekler; cihazda zaten olan kayıtlar
  /// atlanır. Aynı dakikada iki kez yazılmış aynı harcama iki kayıt sayılır.
  /// Dosya EmuGider yedeği değilse `null`.
  Future<RestoreResult?> restoreFromCsv(Uint8List bytes) async {
    final parsed = ExpenseBackup.parse(bytes);
    if (parsed == null) return null;

    final existing = <String, int>{};
    for (final e in await database.all()) {
      existing.update(
        ExpenseBackup.key(e),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final fresh = <Expense>[];
    var duplicates = 0;
    for (final e in parsed.rows) {
      final key = ExpenseBackup.key(e);
      final count = existing[key] ?? 0;
      if (count > 0) {
        existing[key] = count - 1;
        duplicates++;
      } else {
        fresh.add(e);
      }
    }
    if (fresh.isNotEmpty) {
      await database.insertAll(fresh);
      await _reloadToday();
    }
    return RestoreResult(
      added: fresh.length,
      duplicates: duplicates,
      skipped: parsed.skipped,
    );
  }

  /// Tüm harcamaları bu cihazdan siler.
  Future<void> deleteAllData() async {
    await database.wipe();
    await _reloadToday();
  }

  Future<void> _reloadToday({bool notify = true}) async {
    _today = Day.startOf(_clock());
    _todayExpenses = await database.expensesOn(Day.key(_today));
    final since = _today.subtract(const Duration(days: frequentWindowDays));
    final rows = await database.frequent(sinceKey: Day.key(since));
    _frequent = [
      for (final r in rows)
        ParsedExpense(
          name: r['name'] as String,
          amountKurus: r['amount_kurus'] as int,
        ),
    ];
    _favorites = [
      for (final r in await database.favorites())
        ParsedExpense(
          name: r['name'] as String,
          amountKurus: r['amount_kurus'] as int,
        ),
    ];
    if (notify) _changed();
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }
}
