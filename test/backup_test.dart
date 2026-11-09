import 'dart:convert';
import 'dart:typed_data';

import 'package:emugider/app/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Uint8List _bom(String text) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);

const _header = 'Tarih;Saat;Harcama;Tutar (TL)\n';

Future<AppState> _state() =>
    createTestState(FakeClock(DateTime(2026, 11, 9, 9, 30)));

void main() {
  test('dışa aktar, sil, geri yükle: kayıtlar aynen döner', () async {
    final state = await _state();
    await state.add(
      name: 'Çay; "özel"',
      amountKurus: 8550,
      at: DateTime(2026, 10, 20, 12, 5),
    );
    await state.addFromText('taksi 1.250,50');
    final csv = await state.exportCsv();

    await state.deleteAllData();
    final result = await state.restoreFromCsv(_bom(csv));

    expect(result!.added, 2);
    expect(result.duplicates, 0);
    expect(result.skipped, 0);
    expect(state.todayExpenses.single.name, 'Taksi');
    expect(state.todayTotal, 125050);
    final october = await state.expensesOn(DateTime(2026, 10, 20));
    expect(october.single.name, 'Çay; "özel"');
    expect(october.single.amountKurus, 8550);
    expect(october.single.spentAt, DateTime(2026, 10, 20, 12, 5));
  });

  test('aynı yedek iki kez yüklenince kayıt çoğalmaz', () async {
    final state = await _state();
    await state.addFromText('kahve 85');
    final csv = _bom(await state.exportCsv());

    final first = await state.restoreFromCsv(csv);
    expect(first!.added, 0);
    expect(first.duplicates, 1);
    expect(state.todayExpenses, hasLength(1));
  });

  test('aynı dakikada iki kez yazılan harcama iki kayıt kalır', () async {
    final state = await _state();
    await state.addFromText('taksi 250');
    final line = '2026-11-09;09:30;"Taksi";250,00\n';

    // Cihazda 1 tane, yedekte 2 tane: eksik olan 1 tane eklenir.
    final result = await state.restoreFromCsv(_bom('$_header$line$line'));
    expect(result!.added, 1);
    expect(result.duplicates, 1);
    expect(state.todayExpenses, hasLength(2));
  });

  test('Excel\'de kaydedilmiş biçim okunur', () async {
    final state = await _state();
    final result = await state.restoreFromCsv(
      _bom(
        'Tarih;Saat;Harcama;Tutar (TL)\r\n'
        '09.11.2026;08:15:00;Market;1.250,50\r\n'
        ';;;\r\n',
      ),
    );
    expect(result!.added, 1);
    expect(result.skipped, 0);
    expect(state.todayExpenses.single.name, 'Market');
    expect(state.todayTotal, 125050);
  });

  test('bozuk satırlar sayılır, sağlamlar eklenir', () async {
    final state = await _state();
    final result = await state.restoreFromCsv(
      _bom(
        '$_header'
        '31.02.2026;12:00;Geçersiz gün;10,00\n'
        '2026-11-09;25:00;Geçersiz saat;10,00\n'
        '2026-11-09;12:00;Tutarsız;abc\n'
        'eksik satır\n'
        '2026-11-09;08:00;Su;15,00\n',
      ),
    );
    expect(result!.added, 1);
    expect(result.skipped, 4);
    expect(state.todayExpenses.single.name, 'Su');
  });

  test('EmuGider yedeği olmayan dosya reddedilir, veri değişmez', () async {
    final state = await _state();
    await state.addFromText('kahve 85');

    expect(await state.restoreFromCsv(_bom('Ad,Soyad\nA,B\n')), isNull);
    expect(await state.restoreFromCsv(Uint8List(0)), isNull);
    // Geçersiz UTF-8.
    expect(
      await state.restoreFromCsv(Uint8List.fromList([0xFF, 0xFE, 0x00])),
      isNull,
    );
    expect(state.todayExpenses, hasLength(1));
  });
}
