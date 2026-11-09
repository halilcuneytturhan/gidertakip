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
| **Özet** | Bugünün toplamı, "Ne harcadın?" satırı + Ekle, sık yazılanlar (son 60 günde en az iki kez yazılan ad + tutar, tek dokunuşla eklenir), "Geçmiş günlere harcama ekle", bugün eklenenler (dokun → düzenle, sola kaydır → sil, Geri al) |
| **Geçmiş güne ekle** | Üstte takvim (varsayılan dün, gelecek günler kapalı), altta aynı giriş satırı; yazılan her satır seçili güne 12:00 saatiyle eklenir |
| **Geçmiş** | Ayın toplamı, Pazartesi ile başlayan takvim (her günün altında o günün tutarı), seçili günün harcamaları |
| **Ayarlar** | Harcamaları CSV olarak dışa aktar, Gizlilik Politikası, Kullanım Koşulları, Hakkında, Tüm verileri sil |

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
  features/add_past/        Geçmiş güne ekleme ekranı
  features/legal/           Gizlilik / koşullar ekranı
  features/history/         Geçmiş sekmesi ve ay takvimi
  features/settings/        Ayarlar sekmesi
  features/shared/          giriş kartı, harcama listesi, düzenleme sayfası
test/                       ayrıştırıcı, veri katmanı ve akış testleri
tool/screenshots_test.dart  ekran görüntüsü üretici
tool/brand/                 ikon ve açılış görselleri üretici
tool/legal/                 barındırılan yasal sayfalar üretici
assets/legal/               gizlilik ve koşul metinleri (tek kaynak)
docs/legal/                 GitHub Pages için yasal sayfalar
```

## İkon ve açılış ekranı

Yeşil zemin üzerinde beyaz fiş işareti koddan çizilir:

```bash
python3 tool/brand/build_brand_assets.py   # Pillow gerekir
```

Android eski ikon + uyarlanabilir ikon (temalı ikon dahil), Android 12+
sistem açılış ekranı, iOS AppIcon ve LaunchScreen ile uygulama içi açılış
görseli (`assets/images/brand/splash_mark.png`) üretilir.

## Gizlilik politikası ve koşullar

Metinlerin tek kaynağı `assets/legal/*.md`. Uygulama içinde Ayarlar'dan
açılır; mağaza için barındırılan sayfalar aynı dosyalardan üretilir:

```bash
python3 tool/legal/build_legal_pages.py \
    --developer "Ad Soyad" --contact destek@ornek.com
```

`docs/legal/` klasörü GitHub Pages ile yayınlanabilir (Settings → Pages →
Branch: main, /docs). Gizlilik adresi:
`https://<kullanıcı>.github.io/gidertakip/legal/gizlilik.html`.

Mağaza derlemesinde uygulama içi metinlerdeki ad ve e-posta için:

```bash
flutter build appbundle \
    --dart-define=LEGAL_DEVELOPER_NAME="Ad Soyad" \
    --dart-define=LEGAL_CONTACT_EMAIL=destek@ornek.com
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

- Bildirim / akşam hatırlatıcısı, ana ekran widget'ı
- Yedekten geri yükleme (şimdilik yalnızca CSV dışa aktarma)
