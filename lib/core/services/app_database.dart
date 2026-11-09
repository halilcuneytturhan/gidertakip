import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

/// Cihazdaki yerel SQLite veritabanı. Hesap veya sunucu gerektirmez.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// 1: ilk sürüm.
  static const int schemaVersion = 1;
  static const String fileName = 'emugider.db';

  /// [factory] ve [path] testlerde bellek içi veritabanı için verilir.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          final batch = db.batch()
            ..execute('''
              CREATE TABLE expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                amount_kurus INTEGER NOT NULL,
                day TEXT NOT NULL,
                spent_at TEXT NOT NULL
              )''')
            ..execute('CREATE INDEX idx_expenses_day ON expenses(day)');
          await batch.commit(noResult: true);
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<Expense> insert(Expense expense) async {
    final id = await db.insert('expenses', expense.toRow());
    return Expense(
      id: id,
      name: expense.name,
      amountKurus: expense.amountKurus,
      spentAt: expense.spentAt,
    );
  }

  Future<void> update(Expense expense) async {
    await db.update(
      'expenses',
      expense.toRow(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> delete(int id) async {
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Bir günün harcamaları, en yeni önce.
  Future<List<Expense>> expensesOn(String dayKey) async {
    final rows = await db.query(
      'expenses',
      where: 'day = ?',
      whereArgs: [dayKey],
      orderBy: 'spent_at DESC, id DESC',
    );
    return rows.map(Expense.fromRow).toList();
  }

  /// [fromKey] ile [toKey] (ikisi dahil) arasındaki günlerin toplamları.
  Future<Map<String, int>> dailyTotals(String fromKey, String toKey) async {
    final rows = await db.rawQuery(
      'SELECT day, SUM(amount_kurus) AS total FROM expenses '
      'WHERE day BETWEEN ? AND ? GROUP BY day',
      [fromKey, toKey],
    );
    return {
      for (final r in rows) r['day'] as String: (r['total'] as int?) ?? 0,
    };
  }

  /// [sinceKey] gününden bu yana en az [minCount] kez yazılmış ad + tutar
  /// çiftleri; en sık ve en yeni önce.
  Future<List<Map<String, Object?>>> frequent({
    required String sinceKey,
    int minCount = 2,
    int limit = 4,
  }) {
    return db.rawQuery(
      'SELECT name, amount_kurus, COUNT(*) AS uses, MAX(spent_at) AS last '
      'FROM expenses WHERE day >= ? '
      'GROUP BY name, amount_kurus HAVING COUNT(*) >= ? '
      'ORDER BY uses DESC, last DESC LIMIT ?',
      [sinceKey, minCount, limit],
    );
  }

  /// Dışa aktarım için tüm kayıtlar, eskiden yeniye.
  Future<List<Expense>> all() async {
    final rows = await db.query('expenses', orderBy: 'spent_at ASC, id ASC');
    return rows.map(Expense.fromRow).toList();
  }

  /// Ayarlar → Tüm verileri sil.
  Future<void> wipe() => db.delete('expenses');

  Future<void> close() => db.close();
}
