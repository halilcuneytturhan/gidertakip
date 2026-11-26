import 'package:emugider/features/splash/emugider_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('animasyon bitince içerik gelir, açılış kaybolur', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EmuGiderIntro(child: Text('Ana ekran'))),
    );

    // İçerik animasyon bitene kadar kurulmaz.
    expect(find.text('Ana ekran'), findsNothing);
    expect(find.byKey(const ValueKey('emugider-intro')), findsOneWidget);

    // Görseller (en fazla 700 ms) + animasyon + bekleme + geçiş.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Ana ekran'), findsOneWidget);
    expect(find.byKey(const ValueKey('emugider-intro')), findsNothing);
  });

  testWidgets('hareket azaltma açıksa logo durağan ve kısa gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: EmuGiderIntro(child: Text('Ana ekran')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Ana ekran'), findsOneWidget);
    await tester.pump(EmuGiderIntro.fadeDuration);
  });
}
