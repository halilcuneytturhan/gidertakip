import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('yazılan satırlar bugüne eklenir ve toplanır', () async {
    final clock = FakeClock(DateTime(2026, 11, 9, 10));
    final state = await createTestState(clock);

    expect(await state.addFromText('taksi 250'), isNotNull);
    expect(await state.addFromText('cips 80'), isNotNull);
    expect(await state.addFromText('kahve 330'), isNotNull);
    expect(await state.addFromText('kahve'), isNull);

    expect(state.todayTotal, 66000);
    expect(state.todayExpenses.map((e) => e.name), ['Kahve', 'Cips', 'Taksi']);
  });

  test('gün değişince bugün sıfırlanır, geçmiş korunur', () async {
    final clock = FakeClock(DateTime(2026, 11, 9, 23, 50));
    final state = await createTestState(clock);
    await state.addFromText('taksi 250');

    clock.now = DateTime(2026, 11, 10, 0, 5);
    await state.refreshIfDayChanged();
    expect(state.todayExpenses, isEmpty);
    await state.addFromText('simit 20');

    final totals = await state.monthTotals(2026, 11);
    expect(totals, {9: 25000, 10: 2000});
    expect(
      (await state.expensesOn(DateTime(2026, 11, 9))).single.name,
      'Taksi',
    );
  });

  test('silme, geri alma ve düzenleme', () async {
    final clock = FakeClock(DateTime(2026, 11, 9, 12));
    final state = await createTestState(clock);
    final saved = (await state.addFromText('market 450'))!;

    await state.delete(saved);
    expect(state.todayTotal, 0);

    await state.restore(saved);
    expect(state.todayTotal, 45000);

    final restored = state.todayExpenses.single;
    await state.update(restored.copyWith(name: 'Migros', amountKurus: 47550));
    expect(state.todayExpenses.single.name, 'Migros');
    expect(state.todayTotal, 47550);
  });

  test('CSV dışa aktarım ve tüm verileri silme', () async {
    final clock = FakeClock(DateTime(2026, 11, 9, 8, 5));
    final state = await createTestState(clock);
    await state.addFromText('kahve 85,50');

    final csv = await state.exportCsv();
    expect(
      csv,
      'Tarih;Saat;Harcama;Tutar (TL)\n2026-11-09;08:05;"Kahve";85,50\n',
    );

    await state.deleteAllData();
    expect(state.todayExpenses, isEmpty);
    expect(await state.monthTotals(2026, 11), isEmpty);
  });
}
