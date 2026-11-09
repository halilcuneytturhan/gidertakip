// Ekran görüntüsü üretici (CI testi değildir):
//   flutter test tool/screenshots_test.dart
// Gerçek Nunito ve Material ikon fontlarıyla her ekranı build/screenshots/
// altına PNG olarak kaydeder.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emugider/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

Future<void> _loadFonts() async {
  final nunito = FontLoader('Nunito');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Nunito-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await nunito.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void main() {
  testWidgets('ekran görüntüleri', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);

    final clock = FakeClock(DateTime(2026, 11, 9, 9));
    final state = (await tester.runAsync(() => createTestState(clock)))!;
    await tester.runAsync(() async {
      final samples = <int, List<(String, int)>>{
        2: [('Ekmek', 40), ('Otobüs', 60), ('Öğle yemeği', 180)],
        3: [('Kahve', 90), ('Taksi', 220)],
        4: [('Market', 350), ('Cips', 60), ('Su', 30), ('Kahve', 120)],
        5: [('Öğle yemeği', 150), ('Çay', 35)],
        6: [('Taksi', 200), ('Kahve', 85), ('Dolmuş', 40), ('Market', 1250)],
        7: [('Kira', 12500)],
      };
      for (final entry in samples.entries) {
        for (final (name, lira) in entry.value) {
          await state.add(
            name: name,
            amountKurus: lira * 100,
            at: DateTime(2026, 11, entry.key, 12),
          );
        }
      }
      await state.addFromText('taksi 250');
      await state.addFromText('cips 80');
      await state.addFromText('kahve 330');
    });

    await tester.pumpWidget(
      RepaintBoundary(child: EmuGiderApp(state: state)),
    );
    await _shot(tester, '01_ozet');

    await tester.tap(find.text('Geçmiş'));
    await _shot(tester, '02_gecmis');

    await tester.tap(find.text('6'));
    await _shot(tester, '03_gecmis_gun');

    await tester.tap(find.text('Ayarlar').last);
    await _shot(tester, '04_ayarlar');
  });
}
