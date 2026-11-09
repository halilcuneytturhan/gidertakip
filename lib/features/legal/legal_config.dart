/// Yasal metinler (gizlilik politikası, kullanım koşulları) ve iletişim.
///
/// Metinlerin tek kaynağı `assets/legal/*.md` dosyalarıdır; uygulama içinde
/// [LegalDocumentScreen] ile gösterilir, mağazalar için barındırılan sayfalar
/// `tool/legal/build_legal_pages.py` ile aynı dosyalardan üretilir.
///
/// Mağaza derlemesinde verilmesi gerekenler:
/// `--dart-define=LEGAL_DEVELOPER_NAME="Ad Soyad / Şirket unvanı"`
/// `--dart-define=LEGAL_CONTACT_EMAIL=destek@...`
abstract final class LegalConfig {
  /// Veri sorumlusu / geliştirici (gerçek kişi adı veya şirket unvanı).
  static const String developerName = String.fromEnvironment(
    'LEGAL_DEVELOPER_NAME',
    defaultValue: 'EmuGider geliştiricisi',
  );

  /// Gizlilik ve destek başvuruları için e-posta adresi.
  static const String contactEmail = String.fromEnvironment(
    'LEGAL_CONTACT_EMAIL',
  );

  static bool get hasContactEmail => contactEmail.contains('@');

  /// Metinlerdeki iletişim ifadesi (e-posta verilmediyse mağaza sayfası).
  static String get contactText => hasContactEmail
      ? contactEmail
      : 'uygulamanın App Store / Google Play sayfasındaki geliştirici '
            'e-posta adresi';
}

/// Uygulamadaki yasal belgeler.
enum LegalDocument {
  privacy('Gizlilik Politikası', 'assets/legal/gizlilik_politikasi.md'),
  terms('Kullanım Koşulları', 'assets/legal/kullanim_kosullari.md');

  const LegalDocument(this.title, this.asset);

  final String title;
  final String asset;
}

/// Yer tutucuları ({{DEVELOPER}}, {{CONTACT}}) yapılandırmayla doldurur.
String fillLegalPlaceholders(
  String text, {
  String? developer,
  String? contact,
}) => text
    .replaceAll('{{DEVELOPER}}', developer ?? LegalConfig.developerName)
    .replaceAll('{{CONTACT}}', contact ?? LegalConfig.contactText);
