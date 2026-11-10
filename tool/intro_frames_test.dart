// Açılış animasyonunun karelerini üretir (CI testi değildir):
//   flutter test tool/intro_frames_test.dart
// build/intro_frames/*.png dosyalarını yazar.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emugider/features/splash/emugider_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('intro frames', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const RepaintBoundary(
        child: MaterialApp(
          home: EmuGiderIntro(child: ColoredBox(color: Colors.white)),
        ),
      ),
    );
    // Görseller gerçek zamanlı çözülür.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    Future<void> precacheAll() => tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });

    var elapsed = 0;
    for (final ms in [400, 900, 1400, 1900, 2600]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await precacheAll();
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('build/intro_frames/${ms.toString().padLeft(4, '0')}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
    }
    await tester.pump(const Duration(seconds: 2));
  });
}
