import 'package:emugider/app/app_state.dart';
import 'package:emugider/core/services/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _FakeReminders implements ReminderScheduler {
  _FakeReminders({this.granted = true});

  final bool granted;
  List<DateTime> planned = const [];
  int replaceCount = 0;
  bool failing = false;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> replaceAll(List<DateTime> times) async {
    if (failing) throw StateError('plugin hatası');
    replaceCount++;
    planned = times;
  }
}

Future<AppState> _state(FakeClock clock, ReminderScheduler reminders) async {
  final state = AppState(
    database: await openTestDatabase(),
    clock: clock.call,
    reminders: reminders,
  );
  await state.load();
  return state;
}

void main() {
  test('açılınca bugünden başlayarak 14 gün planlanır', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    expect(reminders.planned, isEmpty);

    expect(await state.setReminderOn(true), isTrue);
    expect(reminders.planned.length, 14);
    expect(reminders.planned.first, DateTime(2026, 11, 9, 21));
    expect(reminders.planned.last, DateTime(2026, 11, 22, 21));
  });

  test('harcama yazılınca bugünkü düşer, silinince geri gelir', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    await state.setReminderOn(true);

    final saved = await state.addFromText('kahve 85');
    expect(reminders.planned.first, DateTime(2026, 11, 10, 21));
    expect(reminders.planned.length, 13);

    await state.delete(saved!);
    expect(reminders.planned.first, DateTime(2026, 11, 9, 21));
  });

  test('geçmiş güne yazmak bugünün hatırlatmasını düşürmez', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    await state.setReminderOn(true);

    await state.addFromText('taksi 250', day: DateTime(2026, 11, 8));
    expect(reminders.planned.first, DateTime(2026, 11, 9, 21));
  });

  test('saat geçtiyse bugün planlanmaz, yeni saat uygulanır', () async {
    final reminders = _FakeReminders();
    final state = await _state(
      FakeClock(DateTime(2026, 11, 9, 21, 30)),
      reminders,
    );
    await state.setReminderOn(true);
    expect(reminders.planned.first, DateTime(2026, 11, 10, 21));

    await state.setReminderMinutes(22 * 60 + 15);
    expect(reminders.planned.first, DateTime(2026, 11, 9, 22, 15));
  });

  test('kapatınca planlar silinir', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    await state.setReminderOn(true);
    await state.setReminderOn(false);
    expect(reminders.planned, isEmpty);
    expect(state.reminderOn, isFalse);
  });

  test('izin verilmezse kapalı kalır', () async {
    final reminders = _FakeReminders(granted: false);
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    expect(await state.setReminderOn(true), isFalse);
    expect(state.reminderOn, isFalse);
    expect(reminders.planned, isEmpty);
  });

  test('değişiklik yoksa bildirimler yeniden kurulmaz', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    await state.setReminderOn(true);
    await state.addFromText('kahve 85');
    final count = reminders.replaceCount;

    await state.addFromText('çay 20');
    await state.addFromText('su 15');
    expect(reminders.replaceCount, count);
  });

  test('ayar uygulama yeniden açılınca korunur ve yeniden planlanır', () async {
    final clock = FakeClock(DateTime(2026, 11, 9, 9));
    final first = await _state(clock, _FakeReminders());
    await first.setReminderOn(true);
    await first.setReminderMinutes(20 * 60 + 30);

    final reminders = _FakeReminders();
    final second = AppState(
      database: first.database,
      clock: clock.call,
      reminders: reminders,
    );
    await second.load();
    expect(second.reminderOn, isTrue);
    expect(second.reminderMinutes, 20 * 60 + 30);
    expect(reminders.planned.first, DateTime(2026, 11, 9, 20, 30));
  });

  test('bildirim hatası harcama yazmayı engellemez', () async {
    final reminders = _FakeReminders();
    final state = await _state(FakeClock(DateTime(2026, 11, 9, 9)), reminders);
    await state.setReminderOn(true);

    reminders.failing = true;
    expect(await state.addFromText('kahve 85'), isNotNull);
    expect(state.todayExpenses, hasLength(1));

    // Hata geçince bir sonraki değişiklikte yeniden denenir.
    reminders.failing = false;
    await state.addFromText('çay 20');
    expect(reminders.planned.first, DateTime(2026, 11, 10, 21));
  });
}
