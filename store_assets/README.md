# EmuGider mağaza görselleri

Üretim: `flutter test tool/store/store_screens_test.dart --plain-name telefon`,
`... --plain-name tablet` (ikisini ayrı çalıştırın), ardından
`python tool/store/build_store_assets.py`. Dosya listesi: `manifest.csv`. Metinler (TR + EN): `metinler.csv`.

## Klasörler
- `appstore/iphone_6.9/` 1290x2796, 8 görsel (`emugider_appstore_tr_01..08.png`)
- `appstore/iphone_6.5/` 1284x2778, 8 görsel
- `appstore/ipad_13/` 2064x2752, 8 görsel (`emugider_appstore_ipad13_tr_01..08.png`). Uygulama iPad'de
  en fazla 600 noktalık ortalanmış bir sütunda çalışır (`lib/core/widgets/max_width_frame.dart`), görseller de bunu gösterir.
- `googleplay/phone/` 1440x2560 (9:16), 8 görsel, cihaz çerçevesi yok
- `googleplay/feature_graphic/` 1024x500
- `googleplay/icon/` 512x512, 32 bit PNG
- `source/screens/` gerçek uygulama ekranları (Flutter ile render edildi, örnek veriyle)

Hepsi alfa kanalı olmayan 24 bit RGB PNG'dir (Play simgesi hariç).

## Sıra
1 Yaz, Ekle, bitti · 2 Her gün takvimde · 3 Paran nereye gidiyor? · 4 Sık harcamalar tek dokunuşla ·
5 Unuttuğun günü sonra ekle · 6 PDF, Word veya CSV · 7 Akşam hatırlatıcısı · 8 Hesap yok, veriler cihazında

## Tasarım
Zemin #072A24 → #0B4036 (ikon zemini), ışık #148C75, vurgu #8CE6CF, alt başlık #C6EBE1.
Yazı tipi Nunito (ExtraBold başlık, SemiBold alt başlık), uygulamaya gömülü olan font.
Tutar gösteren ekranlarda "Ekrandaki harcamalar örnektir" etiketi var.
Gösterilmeyenler (uygulamada yok): kategori, bütçe, grafik, tekrarlayan gider, fiş, banka bağlantısı, bulut.

## Resmî kaynaklar
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- https://developer.apple.com/app-store/product-page/
- https://support.google.com/googleplay/android-developer/answer/9866151

Not: Apple'da hangi iPhone boyutunun zorunlu olduğu bilgisi sayfadan tam olarak okunamadı.
Yüklemeden önce App Store Connect'te kontrol edin. 6.9" ve 6.5" setlerinin ikisi de hazır.
