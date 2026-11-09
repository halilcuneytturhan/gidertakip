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
}
