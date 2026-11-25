"""EmuGider mağaza görsellerini üretir (App Store + Google Play).

Önce gerçek ekranlar üretilir, sonra bu betik onları başlıklı mağaza
görsellerine dönüştürür:

    flutter test tool/store/store_screens_test.dart --plain-name telefon
    flutter test tool/store/store_screens_test.dart --plain-name tablet
    python tool/store/build_store_assets.py          # Pillow gerekir

Çıktılar store_assets/ altındadır; manifest.csv her dosyanın adını,
boyutunu, oranını ve biçimini listeler. Bütün görseller alfa kanalı
olmayan 24 bit RGB PNG'dir (Google Play simgesi hariç: 32 bit RGBA PNG).
Ekrandaki harcamalar örnek veridir ve görselde "örnek" diye yazılır.
"""

from __future__ import annotations

import csv
import math
import os
from dataclasses import dataclass

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "store_assets")
SCREENS = os.path.join(OUT, "source", "screens")
FONTS = os.path.join(ROOT, "assets", "fonts")
BRAND = os.path.join(ROOT, "assets", "images", "brand")
ICON_1024 = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset",
    "Icon-App-1024x1024@1x.png",
)

# Renkler: ikon/açılış zemini ve uygulama yeşilleri (lib/app/theme/app_colors.dart).
BG_TOP = (0x07, 0x2A, 0x24)      # ikon zemini
BG_BOTTOM = (0x0B, 0x40, 0x36)
GLOW = (0x14, 0x8C, 0x75)        # açılış yayının orta yeşili
MINT = (0x8C, 0xE6, 0xCF)        # açılış yayının parlak ucu
WHITE = (0xFF, 0xFF, 0xFF)
SUB = (0xC6, 0xEB, 0xE1)
NOTE = (0x8F, 0xC2, 0xB5)
BEZEL = (0x10, 0x18, 0x16)
BEZEL_EDGE = (0x2E, 0x52, 0x4A)


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(os.path.join(FONTS, f"Nunito-{weight}.ttf"), size)


@dataclass(frozen=True)
class Slide:
    no: int
    screen: str
    title: str
    subtitle: str
    sample: bool  # ekranda örnek tutarlar var mı
    title_en: str
    subtitle_en: str
    benefit: str


SLIDES = [
    Slide(1, "ozet_yaziyor", "Yaz, Ekle, bitti",
          "“taksi 250” yazman yeter; ad ve tutar kendiliğinden ayrılır.",
          True, "Type it, add it, done",
          "Just type “taxi 250” – the name and amount are split for you.",
          "Harcamayı tek satırla, saniyeler içinde kaydetmek"),
    Slide(2, "gecmis_takvim", "Her gün takvimde",
          "Her günün altında o gün ne kadar harcadığın yazar.",
          True, "Every day on the calendar",
          "Each day shows how much you spent that day.",
          "Günlük harcamayı takvimde bir bakışta görmek"),
    Slide(3, "gecmis_en_cok", "Paran nereye gidiyor?",
          "Ayın toplamı ve en çok harcadığın 5 kalem bir arada.",
          True, "Where does your money go?",
          "Monthly total and your top 5 expenses in one place.",
          "Ay içinde en çok neye harcandığını anlamak"),
    Slide(4, "ozet", "Sık harcamalar tek dokunuşla",
          "Kahve, otobüs, simit… Çipe dokun, hemen eklensin.",
          True, "Frequent expenses in one tap",
          "Coffee, bus fare, snacks… Tap a chip to add it.",
          "Tekrarlanan harcamaları yazmadan eklemek"),
    Slide(5, "gecmis_gune_ekle", "Unuttuğun günü sonra ekle",
          "Takvimden günü seç, harcamayı o güne yaz.",
          True, "Add a missed day later",
          "Pick the day on the calendar and log it there.",
          "Geçmiş günlerin kayıtlarını tamamlamak"),
    Slide(6, "disa_aktar", "PDF, Word veya CSV",
          "Ay ay raporunu al, tüm harcamalarını CSV ile yedekle.",
          False, "PDF, Word or CSV",
          "Get monthly reports and back up everything as CSV.",
          "Raporu paylaşmak ve verileri yedeklemek"),
    Slide(7, "ayarlar", "Akşam hatırlatıcısı",
          "O gün hiç yazmadıysan seçtiğin saatte bir kez hatırlatır.",
          False, "Evening reminder",
          "If you logged nothing today, one nudge at your chosen time.",
          "Kayıt yazmayı unutmamak"),
    Slide(8, "gizlilik", "Hesap yok, veriler cihazında",
          "İnternete bağlanmaz; yazdıkların hiçbir sunucuya gönderilmez.",
          False, "No account, data stays on device",
          "Works offline; nothing you type is sent to any server.",
          "Mali verilerin gizli kalması"),
]

SAMPLE_NOTE = "Ekrandaki harcamalar örnektir"


# ---------------------------------------------------------------- yardımcılar

def gradient(w: int, h: int) -> Image.Image:
    """Dikey koyu yeşil geçiş + üstte yumuşak yeşil ışık."""
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(
            round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))
    base = col.resize((w, h), Image.NEAREST)
    glow = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(glow)
    r = int(w * 0.75)
    d.ellipse((w // 2 - r, -int(r * 1.1), w // 2 + r, int(r * 0.55)), fill=70)
    glow = soft_blur(glow, w * 0.12)
    return Image.composite(Image.new("RGB", (w, h), GLOW), base, glow)


def soft_blur(mask: Image.Image, radius: float) -> Image.Image:
    """Büyük yarıçaplı bulanıklığı küçültülmüş kopyada yapar (hızlı, aynı görünüm)."""
    k = 8
    small = mask.resize((max(1, mask.width // k), max(1, mask.height // k)), Image.BILINEAR)
    small = small.filter(ImageFilter.GaussianBlur(radius / k))
    return small.resize(mask.size, Image.BICUBIC)


def rounded_mask(size: tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def wrap(text: str, f: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    """Satır sayısını artırmadan en dar genişliği seçer; böylece son satırda
    tek kelime kalmaz, satırlar dengeli olur."""
    n = len(_greedy(text, f, max_w))
    lo, hi = 1, max_w
    while lo < hi:
        mid = (lo + hi) // 2
        if len(_greedy(text, f, mid)) <= n:
            hi = mid
        else:
            lo = mid + 1
    return _greedy(text, f, lo)


def _greedy(text: str, f: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for word in words:
        trial = f"{cur} {word}".strip()
        if f.getlength(trial) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_centered(draw: ImageDraw.ImageDraw, lines: list[str], f, y: int, w: int,
                  color, line_h: int) -> int:
    for line in lines:
        draw.text((w / 2, y), line, font=f, fill=color, anchor="mt")
        y += line_h
    return y


def place_screen(canvas: Image.Image, screen: Image.Image, box: tuple[int, int, int],
                 bezel: bool) -> None:
    """Ekranı (x, y, genişlik) kutusuna koyar; App Store'da ince çerçeveli,
    Google Play'de çerçevesiz (yalnızca köşeleri yuvarlatılmış kart)."""
    x, y, sw = box
    sh = round(sw * screen.height / screen.width)
    scr = screen.convert("RGB").resize((sw, sh), Image.LANCZOS)
    radius = round(sw * (0.105 if screen.height > screen.width * 1.6 else 0.035))

    # gölge
    pad = round(sw * 0.06) if bezel else round(sw * 0.02)
    shadow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - pad, y - pad + round(sw * 0.03), x + sw + pad, y + sh + pad + round(sw * 0.03)),
        radius + pad, fill=150)
    shadow = soft_blur(shadow, sw * 0.045)
    canvas.paste(Image.new("RGB", canvas.size, (2, 14, 12)), (0, 0), shadow)

    if bezel:
        b = round(sw * 0.032)
        outer = (sw + 2 * b, sh + 2 * b)
        edge = Image.new("RGB", outer, BEZEL_EDGE)
        canvas.paste(edge, (x - b, y - b), rounded_mask(outer, radius + b))
        e = max(2, round(sw * 0.004))
        inner = (outer[0] - 2 * e, outer[1] - 2 * e)
        canvas.paste(Image.new("RGB", inner, BEZEL), (x - b + e, y - b + e),
                     rounded_mask(inner, radius + b - e))
    else:
        e = max(2, round(sw * 0.004))
        outer = (sw + 2 * e, sh + 2 * e)
        canvas.paste(Image.new("RGB", outer, BEZEL_EDGE), (x - e, y - e),
                     rounded_mask(outer, radius + e))
    canvas.paste(scr, (x, y), rounded_mask((sw, sh), radius))


def compose(slide: Slide, w: int, h: int, kind: str, bezel: bool) -> Image.Image:
    screen = Image.open(os.path.join(SCREENS, kind, f"{slide.screen}.png"))
    canvas = gradient(w, h)
    d = ImageDraw.Draw(canvas)

    tablet = kind == "tablet"
    unit = min(w, h * 0.5625) if not tablet else w * 0.72
    title_f = font("ExtraBold", round(unit * 0.082))
    sub_f = font("SemiBold", round(unit * 0.040))
    note_f = font("Bold", round(unit * 0.026))
    text_w = round(w * (0.86 if not tablet else 0.70))

    y = round(h * 0.045)
    t_lines = wrap(slide.title, title_f, text_w)
    y = draw_centered(d, t_lines, title_f, y, w, WHITE, round(title_f.size * 1.14))
    y += round(sub_f.size * 0.45)
    s_lines = wrap(slide.subtitle, sub_f, text_w)
    y = draw_centered(d, s_lines, sub_f, y, w, SUB, round(sub_f.size * 1.32))

    if slide.sample:
        y += round(note_f.size * 0.7)
        tw = note_f.getlength(SAMPLE_NOTE)
        ph, pw = round(note_f.size * 1.75), round(tw + note_f.size * 1.8)
        px0 = (w - pw) // 2
        d.rounded_rectangle((px0, y, px0 + pw, y + ph), ph // 2,
                            outline=NOTE, width=max(2, round(note_f.size * 0.09)))
        d.text((w / 2, y + ph / 2), SAMPLE_NOTE, font=note_f, fill=NOTE, anchor="mm")
        y += ph

    top = y + round(h * 0.035)
    bottom_margin = round(h * 0.035)
    frame = 0.032 if bezel else 0.004
    avail_h = h - top - bottom_margin
    aspect = screen.width / screen.height
    sw = min(round(w * (0.80 if not tablet else 0.82)),
             round(avail_h * aspect / (1 + 2 * frame * aspect)))
    sh = round(sw / aspect)
    x = (w - sw) // 2
    yy = top + round(sw * frame) + max(0, (avail_h - sh - 2 * round(sw * frame)) // 2)
    place_screen(canvas, screen, (x, yy, sw), bezel)
    return canvas


def brand_logo(height: int) -> Image.Image:
    """Açılış katmanlarını (EMU + yay + Gider) üst üste koyup tek logo yapar."""
    layers = [Image.open(os.path.join(BRAND, "splash", f"{n}.webp")).convert("RGBA")
              for n in ("arc", "emu", "gider")]
    logo = Image.new("RGBA", layers[0].size, (0, 0, 0, 0))
    for layer in layers:
        logo = Image.alpha_composite(logo, layer)
    logo = logo.crop(logo.getbbox())
    return logo.resize((round(logo.width * height / logo.height), height), Image.LANCZOS)


def feature_graphic() -> Image.Image:
    w, h = 1024, 500
    canvas = gradient(w, h)
    logo = brand_logo(300)
    lx = 96
    canvas.paste(logo, (lx, (h - logo.height) // 2), logo)
    d = ImageDraw.Draw(canvas)
    tx = lx + logo.width + 64
    max_w = w - tx - 72
    f1 = font("ExtraBold", 50)
    f2 = font("SemiBold", 26)
    lines = wrap("Harcamalarını yaz, gün gün topla", f1, max_w)
    sub = wrap("Hesap yok · İnternet gerekmez · Veriler cihazında", f2, max_w)
    total = len(lines) * 60 + 20 + len(sub) * 36
    y = (h - total) // 2
    for line in lines:
        d.text((tx, y), line, font=f1, fill=WHITE)
        y += 60
    y += 20
    for line in sub:
        d.text((tx, y), line, font=f2, fill=MINT)
        y += 36
    return canvas


# ---------------------------------------------------------------- dışa aktarma

TARGETS = [
    # (klasör, mağaza, önek, genişlik, yükseklik, ekran türü, çerçeve, not)
    ("appstore/iphone_6.9", "App Store", "emugider_appstore_tr", 1290, 2796, "phone", True,
     "iPhone 6.9\" (1290x2796)"),
    ("appstore/iphone_6.5", "App Store", "emugider_appstore_iphone65_tr", 1284, 2778, "phone",
     True, "iPhone 6.5\" (1284x2778)"),
    ("appstore/ipad_13", "App Store", "emugider_appstore_ipad13_tr", 2064, 2752, "tablet", True,
     "iPad 13\" (2064x2752)"),
    ("googleplay/phone", "Google Play", "emugider_googleplay_tr", 1440, 2560, "phone", False,
     "Telefon 9:16 (1440x2560)"),
]

IPAD_SLIDES = {1, 2, 3, 4, 5, 6, 7, 8}  # iPad: arayüz 600 noktalık sütunda, 8 ekranın hepsi ayrışıyor


def ratio_str(w: int, h: int) -> str:
    g = math.gcd(w, h)
    return f"{w // g}:{h // g} (~{w / h:.4f})"


def save_rgb(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path, "PNG", optimize=True)


def main() -> None:
    rows = []

    def record(path: str, store: str, use: str, alpha: bool = False) -> None:
        im = Image.open(path)
        rows.append({
            "dosya": os.path.relpath(path, OUT).replace("\\", "/"),
            "magaza": store,
            "kullanim": use,
            "genislik_px": im.width,
            "yukseklik_px": im.height,
            "oran": ratio_str(im.width, im.height),
            "bicim": f"PNG {'32 bit RGBA' if alpha else '24 bit RGB, alfa yok'}",
            "boyut_kb": round(os.path.getsize(path) / 1024),
        })

    for folder, store, prefix, w, h, kind, bezel, note in TARGETS:
        for s in SLIDES:
            if kind == "tablet" and s.no not in IPAD_SLIDES:
                continue
            path = os.path.join(OUT, folder, f"{prefix}_{s.no:02d}.png")
            save_rgb(compose(s, w, h, kind, bezel), path)
            record(path, store, f"{note} · {s.no}. {s.title}")
            print("OK", os.path.relpath(path, ROOT))

    fg = os.path.join(OUT, "googleplay", "feature_graphic", "emugider_googleplay_tr_feature.png")
    save_rgb(feature_graphic(), fg)
    record(fg, "Google Play", "Öne çıkan görsel (feature graphic) 1024x500")
    print("OK", os.path.relpath(fg, ROOT))

    icon = os.path.join(OUT, "googleplay", "icon", "emugider_googleplay_icon_512.png")
    os.makedirs(os.path.dirname(icon), exist_ok=True)
    Image.open(ICON_1024).convert("RGBA").resize((512, 512), Image.LANCZOS).save(
        icon, "PNG", optimize=True)
    record(icon, "Google Play", "Uygulama simgesi 512x512", alpha=True)
    print("OK", os.path.relpath(icon, ROOT))

    with open(os.path.join(OUT, "manifest.csv"), "w", newline="", encoding="utf-8-sig") as fp:
        wr = csv.DictWriter(fp, fieldnames=list(rows[0].keys()))
        wr.writeheader()
        wr.writerows(rows)

    with open(os.path.join(OUT, "metinler.csv"), "w", newline="", encoding="utf-8-sig") as fp:
        wr = csv.writer(fp)
        wr.writerow(["sira", "ekran", "fayda", "baslik_tr", "alt_baslik_tr",
                     "baslik_en", "alt_baslik_en", "ornek_veri_notu"])
        for s in SLIDES:
            wr.writerow([s.no, s.screen, s.benefit, s.title, s.subtitle,
                         s.title_en, s.subtitle_en, "evet" if s.sample else "hayır"])
    print("OK manifest.csv, metinler.csv")


if __name__ == "__main__":
    main()
