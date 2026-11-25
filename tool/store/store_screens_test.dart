// Mağaza görselleri için gerçek uygulama ekranlarını üretir (CI testi değildir):
//   flutter test tool/store/store_screens_test.dart
// Çıktı: store_assets/source/screens/{phone,tablet}/*.png
//   phone : 390x844 mantıksal nokta, 3x  → 1170x2532 px
//   tablet: 1032x1376 mantıksal nokta, 2x → 2064x2752 px (iPad 13")
// Ekranlardaki bütün harcamalar ÖRNEK veridir; gerçek kullanıcı verisi yoktur.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emugider/app/app.dart';
import 'package:emugider/app/app_state.dart';
import 'package:emugider/core/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers.dart';

/// Hatırlatıcıyı ekranda "açık" gösterebilmek için izni veren sahte planlayıcı.
class _GrantedReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<DateTime> times) async {}
}

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

Future<void> _shot(
  WidgetTester tester,
  String dir,
  String name,
  double ratio,
) async {
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('store_assets/source/screens/$dir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

/// Örnek veri: 18 Kasım 2026 Çarşamba sabahı, ayın ilk günlerinden harcamalar.
Future<AppState> _sampleState() async {
  final clock = FakeClock(DateTime(2026, 11, 18, 9));
  final state = AppState(
    database: await openTestDatabase(),
    clock: clock.call,
    reminders: _GrantedReminders(),
  );
  await state.load();
  final samples = <int, List<(String, int)>>{
    2: [('Simit', 30), ('Otobüs', 60), ('Öğle yemeği', 220)],
    3: [('Kahve', 85), ('Market', 640)],
    4: [('Otobüs', 60), ('Eczane', 180)],
    5: [('Simit', 30), ('Kahve', 85), ('Taksi', 250)],
    6: [('Market', 1150), ('Otobüs', 60)],
    9: [('Kahve', 85), ('Öğle yemeği', 240), ('Otobüs', 60)],
    10: [('Fatura', 900)],
    11: [('Simit', 30), ('Kitap', 320)],
    12: [('Market', 780), ('Taksi', 250)],
    13: [('Sinema', 300), ('Kahve', 85)],
    16: [('Otobüs', 60), ('Öğle yemeği', 210)],
    17: [('Market', 520), ('Kahve', 85), ('Simit', 30)],
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
  await state.addFromText('simit 30');
  await state.addFromText('otobüs 60');
  await state.addFromText('kahve 85');
  await state.addFavoriteFromText('su 20');
  await state.setReminderOn(true);
  return state;
}

Future<void> _capture(
  WidgetTester tester, {
  required String dir,
  required Size logical,
  required double ratio,
  required EdgeInsets padding,
}) async {
  tester.view.physicalSize = logical * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.view.padding = FakeViewPadding(
    top: padding.top * ratio,
    bottom: padding.bottom * ratio,
  );

  final state = (await tester.runAsync(_sampleState))!;
  await tester.pumpWidget(RepaintBoundary(child: EmuGiderApp(state: state)));
  await _settle(tester);

  // 1) Özet: yazma anı ("taksi 250" yazılmış, henüz eklenmemiş).
  await tester.enterText(find.byKey(const Key('quickEntryField')), 'taksi 250');
  await _shot(tester, dir, 'ozet_yaziyor', ratio);
  await tester.enterText(find.byKey(const Key('quickEntryField')), '');
  FocusManager.instance.primaryFocus?.unfocus();

  // 2) Özet: sık kullanılanlar ve bugün eklenenler.
  await _shot(tester, dir, 'ozet', ratio);

  // 3) Geçmiş güne ekle.
  await tester.tap(find.byKey(const Key('addPastDay')));
  await _shot(tester, dir, 'gecmis_gune_ekle', ratio);
  await tester.tap(find.byTooltip('Geri'));
  await _settle(tester);

  // 4) Geçmiş: ay takvimi.
  await tester.tap(find.text('Geçmiş'));
  await _shot(tester, dir, 'gecmis_takvim', ratio);

  // 5) Geçmiş: seçili gün + ayda en çok.
  await tester.tap(find.text('12').first);
  await _settle(tester);
  await tester.drag(find.text('Kasım toplam'), const Offset(0, -900));
  await _shot(tester, dir, 'gecmis_en_cok', ratio);

  // 6) Ayarlar (hatırlatıcı açık).
  await tester.tap(find.text('Ayarlar').last);
  await _shot(tester, dir, 'ayarlar', ratio);

  // 7) Dışa aktarma biçimleri.
  await tester.tap(find.text('Harcamaları dışa aktar'));
  await _shot(tester, dir, 'disa_aktar', ratio);
  Navigator.of(tester.element(find.text('PDF'))).pop();
  await _settle(tester);

  // 8) Gizlilik politikası.
  await tester.tap(find.text('Gizlilik Politikası'));
  await _shot(tester, dir, 'gizlilik', ratio);

  await tester.pumpWidget(const SizedBox());
  await _settle(tester);
}

void main() {
  testWidgets('mağaza ekranları — telefon', (tester) async {
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);
    await _capture(
      tester,
      dir: 'phone',
      logical: const Size(390, 844),
      ratio: 3,
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    );
  });

  testWidgets('mağaza ekranları — tablet', (tester) async {
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);
    await _capture(
      tester,
      dir: 'tablet',
      logical: const Size(1032, 1376),
      ratio: 2,
      padding: const EdgeInsets.only(top: 24, bottom: 20),
    );
  });
}
