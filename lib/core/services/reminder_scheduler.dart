import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Akşam hatırlatıcısı bildirimlerini planlar.
///
/// Yerel bildirim tetiklendiği anda veritabanına bakamaz. Bu yüzden önümüzdeki
/// günler için tek tek bildirim planlanır; o gün harcama yazılınca o günün
/// bildirimi listeden çıkar.
abstract class ReminderScheduler {
  /// Kullanıcıdan bildirim izni ister; verilirse `true`.
  Future<bool> requestPermission();

  /// Planlı bildirimleri silip [times] anları için yenilerini kurar.
  Future<void> replaceAll(List<DateTime> times);
}

/// Hatırlatıcı olmayan ortamlar (testler) için boş uygulama.
class NoReminders implements ReminderScheduler {
  const NoReminders();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<DateTime> times) async {}
}

/// Cihazın kendi bildirim sistemiyle planlar; internet gerektirmez.
class LocalReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'evening_reminder',
      'Akşam hatırlatıcısı',
      channelDescription: 'O gün harcama yazılmadıysa akşam hatırlatır.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFF0F6B5C),
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          // İzin yalnızca kullanıcı hatırlatıcıyı açınca istenir.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Bildirimler başlatılamadı: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> replaceAll(List<DateTime> times) async {
    await _plugin.cancelAll();
    for (var i = 0; i < times.length; i++) {
      await _plugin.zonedSchedule(
        id: i + 1,
        title: 'Bugün ne harcadın?',
        body: 'Henüz harcama yazmadın. Tek satır yeter, örneğin: kahve 85',
        // Tek seferlik anlar olduğu için cihazın saat dilimini bilmek
        // gerekmez; yerel saat UTC ana çevrilir.
        scheduledDate: tz.TZDateTime.from(times[i], tz.UTC),
        notificationDetails: _details,
        // Tam saat izni istememek için; Android bir saate kadar geciktirebilir.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
