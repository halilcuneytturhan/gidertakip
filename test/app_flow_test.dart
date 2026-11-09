import 'package:emugider/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('"taksi 250" yaz, Ekle → listede ve toplamda görünür', (
    tester,
  ) async {
    // Telefon ekranı (390×844).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final clock = FakeClock(DateTime(2026, 11, 9, 10));
    final state = await tester.runAsync(() => createTestState(clock));
    await tester.pumpWidget(EmuGiderApp(state: state!));
    await tester.pumpAndSettle();

    expect(find.text('Bugün toplam'), findsOneWidget);
    expect(find.text('İlk harcamanı yaz, örneğin: kahve 85'), findsOneWidget);

    Future<void> addLine(String text) async {
      await tester.enterText(find.byKey(const Key('quickEntryField')), text);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('quickEntryAdd')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }

    await addLine('taksi 250');
    await addLine('cips 80');

    expect(find.text('Taksi'), findsOneWidget);
    expect(find.text('Cips'), findsOneWidget);
    expect(find.text('330 TL'), findsOneWidget);
    expect(find.text('Bugün 2 harcama yazdın.'), findsOneWidget);

    // Tutarsız satır uyarı gösterir, kaydetmez.
    await addLine('kahve');
    expect(find.text('Tutarı da yaz, örneğin: kahve 85'), findsOneWidget);
    expect(find.text('330 TL'), findsOneWidget);

    // Geçmiş sekmesi: takvim ve bugünün toplamı.
    await tester.runAsync(() async {
      await tester.tap(find.text('Geçmiş'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Kasım 2026'), findsOneWidget);
    expect(find.text('Kasım toplam'), findsOneWidget);
    expect(find.text('9 Kasım Pazartesi'), findsOneWidget);
  });

  testWidgets('geçmiş güne ekle: takvimden gün seç, "taksi 260" yaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final clock = FakeClock(DateTime(2026, 11, 9, 10));
    final state = await tester.runAsync(() => createTestState(clock));
    await tester.pumpWidget(EmuGiderApp(state: state!));
    await tester.pumpAndSettle();

    Future<void> tapAndWait(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
    }

    await tapAndWait(find.byKey(const Key('addPastDay')));
    expect(find.text('Geçmiş güne ekle'), findsOneWidget);
    // Varsayılan gün dün.
    expect(
      find.text('8 Kasım Pazar gününe ekle', findRichText: true),
      findsOneWidget,
    );

    // 5 Kasım'ı seç ve ekle.
    await tapAndWait(find.text('5'));
    expect(
      find.text('5 Kasım Perşembe gününe ekle', findRichText: true),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('quickEntryField')),
      'taksi 260',
    );
    await tapAndWait(find.byKey(const Key('quickEntryAdd')));

    expect(find.text('Taksi'), findsOneWidget);
    expect(find.text('260 TL'), findsWidgets);
    expect(state.todayExpenses, isEmpty);
    final saved = await tester.runAsync(
      () => state.expensesOn(DateTime(2026, 11, 5)),
    );
    expect(saved!.single.amountKurus, 26000);

    // Gelecek günler seçilemez.
    await tapAndWait(find.text('20'));
    expect(
      find.text('5 Kasım Perşembe gününe ekle', findRichText: true),
      findsOneWidget,
    );
  });
}
