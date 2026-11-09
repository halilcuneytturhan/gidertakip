# EmuGider

Yazdığın harcamaları gün gün toplayan sade bir gider takibi. "taksi 250",
"cips 80", "kahve 330" gibi tek satır yazıp **Ekle**'ye basarsın; uygulama
adı ve tutarı ayırır, bugünün toplamını gösterir. Geçmiş sekmesindeki
takvimde her günün altında o gün harcanan tutar yazar. Flutter ile iOS ve
Android için geliştirilmiştir; arayüz tamamen Türkçedir.

Hesap, sunucu ya da internet gerekmez: veriler yalnızca cihazdaki SQLite
veritabanında saklanır.

## Çalıştırma

```bash
flutter pub get
flutter run                      # bağlı cihaz / emülatör
flutter build apk --release      # Android APK
flutter build appbundle          # Google Play paketi
flutter build ios --release      # iOS (macOS + Xcode, imzalama gerekir)
```

Android Studio: proje klasörünü açın (Flutter ve Dart eklentileri kurulu
olmalı), `pubspec.yaml` üstündeki **Pub get**'e basın, cihaz seçip çalıştırın.

Geliştirme sürümü: Flutter 3.47.8 / Dart 3.13. `pubspec.yaml` Dart ≥ 3.9'a
izin verir.

Kalite kontrolleri:

```bash
flutter analyze
flutter test                                  # birim + widget testleri
flutter test tool/screenshots_test.dart       # ekran görüntüleri → build/screenshots/
```

## Özellikler

| Sekme | İçerik |
| --- | --- |
| **Özet** | Bugünün toplamı, "Ne harcadın?" satırı + Ekle, bugün eklenenler (dokun → düzenle, sola kaydır → sil, Geri al) |
| **Geçmiş** | Ayın toplamı, Pazartesi ile başlayan takvim (her günün altında o günün tutarı), seçili günün harcamaları |
| **Ayarlar** | Harcamaları CSV olarak dışa aktar, Hakkında, Tüm verileri sil |

### Tek satır giriş kuralları (`lib/core/utils/expense_parser.dart`)

- Satırdaki **son** sayı tutardır: `2 simit 30` → "2 simit", 30 TL.
- `85,50` / `85.50` ondalık; `1.250` / `1,250` binlik; `1.250,50` ikisi birden.
- `tl`, `₺`, `lira` atılır: `taksi 250tl`, `₺250 taksi`.
- Ad yoksa "Harcama" yazılır; ilk harf Türkçe kurala göre büyütülür (`ilaç` → `İlaç`).
- Tutar bulunamazsa kayıt yapılmaz, "Tutarı da yaz" uyarısı çıkar.

Tutarlar veritabanında kuruş cinsinden tam sayı olarak tutulur.

## Klasör yapısı

```
lib/
  main.dart                 açılış: veritabanı + AppState
  app/                      app, AppScope, AppState, tema, cam alt menü
  core/                     model, SQLite, ayrıştırıcı, para/tarih yardımcıları, ortak widget'lar
  features/today/           Özet sekmesi
  features/history/         Geçmiş sekmesi ve ay takvimi
  features/settings/        Ayarlar sekmesi
  features/shared/          harcama listesi ve düzenleme sayfası
test/                       ayrıştırıcı, veri katmanı ve akış testleri
tool/screenshots_test.dart  ekran görüntüsü üretici
```

## Yayın imzası (Android)

`android/key.properties` dosyası (depoya eklenmez) varsa yayın paketi o
anahtarla imzalanır; yoksa yerel deneme için hata ayıklama anahtarı
kullanılır ve o paket Google Play'e yüklenemez:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/yol/upload-keystore.jks
```

## Henüz yapılmayanlar

- Uygulama ikonu ve açılış ekranı (şimdilik Flutter'ın varsayılanı)
- Gizlilik politikası sayfası (mağaza başvurusu için gerekli)
- Bildirim / hatırlatıcı, ana ekran widget'ı
