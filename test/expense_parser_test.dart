import 'package:emugider/core/utils/expense_parser.dart';
import 'package:emugider/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ParsedExpense? p(String s) => ExpenseParser.parse(s);
  ParsedExpense e(String name, int kurus) =>
      ParsedExpense(name: name, amountKurus: kurus);

  group('ExpenseParser', () {
    test('ad + tutar', () {
      expect(p('taksi 250'), e('Taksi', 25000));
      expect(p('cips 80'), e('Cips', 8000));
      expect(p('kahve 330'), e('Kahve', 33000));
    });

    test('tutar başta', () {
      expect(p('250 taksi'), e('Taksi', 25000));
    });

    test('ondalık: virgül ve nokta', () {
      expect(p('kahve 85,50'), e('Kahve', 8550));
      expect(p('kahve 85,5'), e('Kahve', 8550));
      expect(p('kahve 85.50'), e('Kahve', 8550));
    });

    test('binlik ayraç', () {
      expect(p('kira 12.500'), e('Kira', 1250000));
      expect(p('market 1.250,75'), e('Market', 125075));
      expect(p('market 1,250'), e('Market', 125000));
    });

    test('TL, ₺ ve lira atılır', () {
      expect(p('taksi 250 tl'), e('Taksi', 25000));
      expect(p('taksi 250TL'), e('Taksi', 25000));
      expect(p('taksi ₺250'), e('Taksi', 25000));
      expect(p('taksi 250 lira'), e('Taksi', 25000));
    });

    test('son sayı tutardır', () {
      expect(p('2 simit 30'), e('2 simit', 3000));
    });

    test('sadece tutar → "Harcama"', () {
      expect(p('45'), e('Harcama', 4500));
    });

    test('Türkçe büyük harf', () {
      expect(p('ilaç 120'), e('İlaç', 12000));
      expect(p('ışık faturası 900'), e('Işık faturası', 90000));
    });

    test('fazla boşluk', () {
      expect(p('   su    15  '), e('Su', 1500));
    });

    test('geçersiz girişler', () {
      expect(p(''), isNull);
      expect(p('   '), isNull);
      expect(p('kahve'), isNull);
      expect(p('kahve 0'), isNull);
      expect(p('kahve 85,5050'), isNull);
      expect(p('ev 99999999999'), isNull);
    });
  });

  group('Money', () {
    test('biçim', () {
      expect(Money.format(25000), '250 TL');
      expect(Money.format(125075), '1.250,75 TL');
      expect(Money.format(8550), '85,50 TL');
      expect(Money.format(0), '0 TL');
      expect(Money.format(123456700), '1.234.567 TL');
    });

    test('takvim için kısa yazım', () {
      expect(Money.compact(95000), '950');
      expect(Money.compact(125000), '1.250');
      expect(Money.compact(1250000), '12.500');
      expect(Money.compact(12500000), '125B');
      expect(Money.compact(25000000), '250B');
    });
  });
}
