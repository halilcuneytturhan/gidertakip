/// Yerel takvim günüyle ilgili yardımcılar ve Türkçe tarih adları.
///
/// `intl` tarih verisini başlatmaya gerek kalmasın diye ay ve gün adları
/// burada tutulur.
abstract final class Day {
  static const List<String> months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// Pazartesi ile başlar (`DateTime.monday == 1`).
  static const List<String> weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const List<String> weekdaysShort = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static DateTime startOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `yyyy-MM-dd`
  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// "9 Kasım Pazartesi"
  static String long(DateTime d) =>
      '${d.day} ${months[d.month - 1]} ${weekdays[d.weekday - 1]}';

  /// "Kasım 2026"
  static String monthYear(DateTime d) => '${months[d.month - 1]} ${d.year}';
}
