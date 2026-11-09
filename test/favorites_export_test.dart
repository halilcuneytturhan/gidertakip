import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:emugider/app/app.dart';
import 'package:emugider/core/models/expense.dart';
import 'package:emugider/core/services/app_database.dart';
import 'package:emugider/core/services/expense_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

ByteData _font(String weight) => ByteData.sublistView(
  File('assets/fonts/Nunito-$weight.ttf').readAsBytesSync(),
);

void main() {
  group('sık kullanılanlar', () {
    test('eklenir, tekrar etmez, harcama yazmaz, çıkarılır', () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));

      expect(await state.addFavoriteFromText('sigara'), isNull);
      final saved = await state.addFavoriteFromText('sigara 125');
      await state.addFavoriteFromText('Sigara 125');

      expect(state.favorites, [saved]);
      expect(state.todayExpenses, isEmpty);

      await state.removeFavorite(saved!);
      expect(state.favorites, isEmpty);
    });

    test('çipler: önce eklenenler, kalan yer otomatikle dolar', () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));
      for (final line in ['çay 20', 'çay 20', 'su 15', 'su 15']) {
        await state.addFromText(line);
      }
      await state.addFavoriteFromText('su 15');
      await state.addFavoriteFromText('sigara 125');
      await state.addFavoriteFromText('simit 30');

      expect(state.quickItems.map((e) => e.name), [
        'Su',
        'Sigara',
        'Simit',
        'Çay',
      ]);
    });

    test('tüm verileri sil sık kullanılanları da siler', () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));
      await state.addFavoriteFromText('sigara 125');
      await state.deleteAllData();
      expect(state.favorites, isEmpty);
    });

    test('eski veritabanı yükseltilir, harcamalar korunur', () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('emugider');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'v1.db');

      final old = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              amount_kurus INTEGER NOT NULL,
              day TEXT NOT NULL,
              spent_at TEXT NOT NULL
            )'''),
        ),
      );
      await old.insert('expenses', {
        'name': 'Kahve',
        'amount_kurus': 8500,
        'day': '2026-11-09',
        'spent_at': '2026-11-09T09:00:00.000',
      });
      await old.close();

      final upgraded = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );
      expect((await upgraded.all()).single.name, 'Kahve');
      await upgraded.insertFavorite('Sigara', 12500);
      expect((await upgraded.favorites()).single['name'], 'Sigara');
      await upgraded.close();
    });
  });

  test(
    'ayda en çok: ada göre toplar, sıralar, en fazla 5, ay dışı yok',
    () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));
      Future<void> add(String name, int lira, int month) => state.add(
        name: name,
        amountKurus: lira * 100,
        at: DateTime(2026, month, 3, 12),
      );
      await add('Taksi', 100, 11);
      await add('Taksi', 250, 11);
      await add('Market', 300, 11);
      await add('Kira', 9000, 10);
      for (final name in ['A', 'B', 'C', 'D']) {
        await add(name, 10, 11);
      }

      final top = await state.monthTop(2026, 11);
      expect(top.length, 5);
      expect(top.first, (name: 'Taksi', totalKurus: 35000, count: 2));
      expect(top[1].name, 'Market');
      expect(top.map((e) => e.name), isNot(contains('Kira')));
    },
  );

  group('dışa aktarma', () {
    final rows = [
      Expense(
        name: 'Şeker & <çay>',
        amountKurus: 8550,
        spentAt: DateTime(2026, 10, 31, 12),
      ),
      Expense(
        name: 'İlaç',
        amountKurus: 125000,
        spentAt: DateTime(2026, 11, 2, 9),
      ),
      Expense(
        name: 'Kahve ☕',
        amountKurus: 33000,
        spentAt: DateTime(2026, 11, 3, 9),
      ),
    ];

    test('rapor dönemi ilk kayıttan değil ayın 1\'inden başlar', () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));
      Future<void> add(String name, DateTime at) =>
          state.add(name: name, amountKurus: 9000, at: at);
      await add('Ekim sonu', DateTime(2026, 10, 31, 23));
      await add('Kasım 5', DateTime(2026, 11, 5, 12));
      await add('Bugün', DateTime(2026, 11, 9, 8));

      final monthStart = DateTime(2026, 11);
      final now = DateTime(2026, 11, 9, 9);
      final month = await state.expensesBetween(monthStart, now);
      expect(month.map((e) => e.name), ['Kasım 5', 'Bugün']);

      final archive = ZipDecoder().decodeBytes(
        ExpenseExport.docx(
          month,
          periodStart: monthStart,
          periodEnd: now,
          generatedAt: now,
        ),
      );
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('1 Kasım 2026 – 9 Kasım 2026'));
      // 180 TL / 9 gün.
      expect(xml, contains('>20 TL<'));
      expect(xml, isNot(contains('Ekim sonu')));
    });

    test('geçmiş ay raporu ayın tamamını kapsar, aylar listelenir', () async {
      final state = await createTestState(FakeClock(DateTime(2026, 11, 9, 9)));
      await state.add(
        name: 'Ekim',
        amountKurus: 31000,
        at: DateTime(2026, 10, 20, 12),
      );
      await state.add(
        name: 'Kasım',
        amountKurus: 5000,
        at: DateTime(2026, 11, 2, 12),
      );

      final months = await state.reportMonths();
      expect(months, [
        (month: DateTime(2026, 11), totalKurus: 5000),
        (month: DateTime(2026, 10), totalKurus: 31000),
      ]);

      final start = DateTime(2026, 10);
      final end = DateTime(2026, 10, 31);
      final rows = await state.expensesBetween(start, end);
      final archive = ZipDecoder().decodeBytes(
        ExpenseExport.docx(
          rows,
          periodStart: start,
          periodEnd: end,
          generatedAt: DateTime(2026, 11, 9),
        ),
      );
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('1 Ekim 2026 – 31 Ekim 2026'));
      // 310 TL / 31 gün.
      expect(xml, contains('>10 TL<'));
      expect(xml, isNot(contains('>Kasım<')));
    });

    test('PDF: 20 sayfadan uzun geçmiş de üretilir', () async {
      final many = [
        for (var i = 0; i < 2000; i++)
          Expense(
            name: 'Harcama $i',
            amountKurus: 1000,
            spentAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
      ];
      final bytes = await ExpenseExport.pdf(
        many,
        regular: _font('Regular'),
        bold: _font('Bold'),
        logo: File('assets/images/brand/splash_mark.png').readAsBytesSync(),
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 3, 25),
        generatedAt: DateTime(2026, 11, 9),
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Word: geçerli zip, XML kaçışları ve aylar doğru', () {
      final archive = ZipDecoder().decodeBytes(
        ExpenseExport.docx(
          rows,
          periodStart: DateTime(2026, 10, 31),
          periodEnd: DateTime(2026, 11, 3),
          generatedAt: DateTime(2026, 11, 3),
        ),
      );
      expect(
        archive.files.map((f) => f.name),
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/footer1.xml',
          'word/_rels/document.xml.rels',
        ]),
      );
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('Şeker &amp; &lt;çay&gt;'));
      expect(xml, contains('31 Ekim 2026 – 3 Kasım 2026'));
      expect(xml, contains('>Ekim 2026<'));
      expect(xml, contains('>85,50 TL<'));
      expect(xml, contains('>Kasım 2026<'));
      expect(xml, contains('>1.580 TL<'));
      // Toplam 1.665,50 TL, 4 takvim günü → günlük 416,38 TL.
      expect(xml, contains('>1.665,50 TL<'));
      expect(xml, contains('>416,38 TL<'));
      // En çok harcananlarda pay: İlaç 1.250 / 1.665,50 ≈ %75.
      expect(xml, contains('>%75<'));
    });
  });

  testWidgets('dışa aktarma: PDF seçince aylar listelenir', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = (await tester.runAsync(
      () => createTestState(FakeClock(DateTime(2026, 11, 9, 10))),
    ))!;
    await tester.runAsync(() async {
      await state.addFromText('kahve 85');
      await state.addFromText('taksi 250', day: DateTime(2026, 10, 20));
    });
    await tester.pumpWidget(EmuGiderApp(state: state));
    await tester.pumpAndSettle();

    Future<void> tapAndWait(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
    }

    await tapAndWait(find.text('Ayarlar').last);
    await tapAndWait(find.text('Harcamaları dışa aktar'));
    await tapAndWait(find.text('PDF'));

    expect(find.text('Hangi dönemin raporu?'), findsOneWidget);
    expect(find.text('Kasım 2026'), findsOneWidget);
    expect(find.text('Bugüne kadar'), findsOneWidget);
    expect(find.text('Tüm harcamalar'), findsOneWidget);
    expect(find.text('335 TL'), findsOneWidget);
    expect(find.text('Bu ay'), findsOneWidget);
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('250 TL'), findsOneWidget);

    // "Bugüne kadar" tüm dönemi kapsayan gerçek bir PDF paylaşır.
    final tmp = Directory.systemTemp.createTempSync('emugider');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Map<Object?, Object?>? shared;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared = call.arguments as Map<Object?, Object?>;
      return 'ok';
    });
    messenger.setMockMethodCallHandler(pathChannel, (_) async => tmp.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
    });

    await tester.runAsync(() async {
      await tester.tap(find.text('Bugüne kadar'));
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 100 && shared == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(shared, isNotNull);
    final path = (shared!['paths']! as List<Object?>).single! as String;
    expect(p.basename(path), 'emugider-rapor-tumu.pdf');
    expect(ascii.decode(File(path).readAsBytesSync().sublist(0, 4)), '%PDF');
  });

  testWidgets('Özet: aç/kapa, kalem ve sık kullanılan kutusu', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final clock = FakeClock(DateTime(2026, 11, 9, 10));
    final state = (await tester.runAsync(() => createTestState(clock)))!;
    await tester.runAsync(() => state.addFromText('yemek 300'));
    await tester.pumpWidget(EmuGiderApp(state: state));
    await tester.pumpAndSettle();

    Future<void> tapAndWait(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
    }

    // Kalem düzenleme sayfasını açar.
    await tapAndWait(find.byTooltip('Düzenle'));
    expect(find.text('Harcamayı düzenle'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    // Liste kapanır, toplam yerinde kalır; tekrar açılır.
    await tapAndWait(find.byKey(const Key('toggleAdded')));
    expect(find.text('Yemek'), findsNothing);
    expect(find.text('300 TL'), findsOneWidget);
    await tapAndWait(find.byKey(const Key('toggleAdded')));
    expect(find.text('Yemek'), findsOneWidget);

    // + sayfası çip ekler, harcama yazmaz.
    await tapAndWait(find.byKey(const Key('favoriteOpen')));
    await tester.enterText(
      find.byKey(const Key('favoriteField')),
      'sigara 125',
    );
    await tapAndWait(find.byKey(const Key('favoriteAdd')));
    expect(find.text('Sigara · 125 TL'), findsOneWidget);
    expect(state.todayExpenses, hasLength(1));

    // Çipe basılı tutunca çıkar.
    await tester.longPress(find.text('Sigara · 125 TL'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sigara · 125 TL'), findsNothing);
  });
}
