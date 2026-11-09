import 'package:emugider/app/app_state.dart';
import 'package:emugider/core/services/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Her testte boş, bellek içi bir veritabanı.
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  // Bellek içi veritabanı süreç boyunca paylaşılır; her test temiz başlar.
  await databaseFactoryFfiNoIsolate.deleteDatabase(inMemoryDatabasePath);
  return AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
}

/// Elle ilerletilebilen saat.
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

Future<AppState> createTestState(FakeClock clock) async {
  final state = AppState(database: await openTestDatabase(), clock: clock.call);
  await state.load();
  return state;
}
