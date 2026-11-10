import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/services/app_database.dart';
import 'core/services/reminder_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerAssetLicenses();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final database = await AppDatabase.open();
  final reminders = LocalReminderScheduler();
  await reminders.initialize();
  final state = AppState(database: database, reminders: reminders);

  runApp(EmuGiderApp(state: state));
  await state.load();
}

/// Paketlerin lisansları Flutter tarafından otomatik eklenir; uygulamaya
/// gömülü yazı tipinin lisansı "Açık kaynak lisansları" sayfası için burada
/// kaydedilir.
void _registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}
