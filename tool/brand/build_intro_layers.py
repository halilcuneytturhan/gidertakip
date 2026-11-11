"""EMU ailesi açılış logosunun ve uygulama ikonlarının EmuGider sürümünü üretir.

    python tool/brand/build_intro_layers.py [EmuBoykot klasörü]

Beyaz EMU harfleri ve yay, ailenin ortak logosudur. Koyu zemin için hazırlanmış
saydam katmanlar EmuBoykot'tan alınır (varsayılan: ../emuboykot-main). Yay
EmuGider yeşiline boyanır, altına aynı kabartma tarzında "Gider" yazısı çizilir.
Zemin ve ikon düzeni EmuFit / EmuEzan gibidir: koyu zemin, ikonda yalnızca EMU
ve yay.

Üretilenler:
  * assets/images/brand/splash/{emu,arc,gider}.webp
  * lib/features/splash/logo_arc_path.g.dart (zemin rengi + yayın çizim sırası)
  * Android: mipmap-*/ic_launcher.png, drawable-*/ic_launcher_foreground.png,
    drawable-*/ic_launcher_monochrome.png, mipmap-anydpi-v26/ic_launcher.xml,
    values/colors.xml
  * iOS: AppIcon.appiconset, LaunchImage.imageset
  * tool/brand/icon_preview.png
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito-ExtraBold.ttf")
OUT = os.path.join(ROOT, "assets", "images", "brand", "splash")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Koyu yeşil zemin (EmuFit'in petrol yeşilinin EmuGider yeşiline yakın hâli).
BACKGROUND = (0x07, 0x2A, 0x24)

# Yay ve yazının gölgeden parlağa renkleri.
GREEN_DARK = np.array([0x0A, 0x4A, 0x3F], np.float32)
GREEN_MID = np.array([0x14, 0x8C, 0x75], np.float32)
GREEN_LIGHT = np.array([0x8C, 0xE6, 0xCF], np.float32)


def green_ramp(t: np.ndarray) -> np.ndarray:
    """t: 0 (gölge) .. 1 (parlak)."""
    t = np.clip(t, 0, 1)[..., None]
    low = GREEN_DARK + (GREEN_MID - GREEN_DARK) * np.clip(t / 0.55, 0, 1)
    return low + (GREEN_LIGHT - GREEN_MID) * np.clip((t - 0.55) / 0.45, 0, 1)


def load(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)


def save_webp(rgba: np.ndarray, path: str) -> None:
    Image.fromarray(rgba.round().clip(0, 255).astype(np.uint8), "RGBA").save(
        path, "WEBP", quality=92, method=6)


def recolor_arc(path_in: str, path_out: str) -> None:
    """Kırmızı yayı yeşile çevirir; parlaklık (ışık, gölge, ışıma) korunur."""
    img = load(path_in)
    rgb, alpha = img[..., :3], img[..., 3]
    # Kırmızı kanalda parlaklık: koyu kırmızı gölge → koyu yeşil, açık → mint.
    lum = rgb[..., 0] * 0.6 + rgb.mean(2) * 0.4
    body = alpha > 200
    low, high = np.percentile(lum[body], [4, 99])
    save_webp(np.dstack([green_ramp((lum - low) / (high - low)), alpha]), path_out)


def neutralize_red(path_in: str, path_out: str) -> None:
    """EMU harflerindeki kırmızı yansımaları (kaynağın yayından) griye çevirir."""
    img = load(path_in)
    rgb, alpha = img[..., :3], img[..., 3]
    lum = rgb.mean(2, keepdims=True)
    red = np.clip((rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2) / 25, 0, 1)
    out = rgb + (lum - rgb) * red[..., None]
    save_webp(np.dstack([out, alpha]), path_out)


def word_box(path: str) -> tuple[int, int, int, int]:
    img = load(path)
    ys, xs = np.nonzero(img[..., 3] > 128)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def render_word(text: str, canvas: tuple[int, int], box, path_out: str) -> None:
    """Kelimeyi kabartma olarak çizer: yumuşak kenar, üstten ışık, gölge."""
    scale = 4
    w, h = canvas[0] * scale, canvas[1] * scale
    _, top, _, bottom = box
    target = int((bottom - top) * scale * 0.8)
    font = ImageFont.truetype(FONT, target)
    l, t, r, b = font.getbbox(text)
    size = int(target * target / (b - t))
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = font.getbbox(text)

    mask = Image.new("L", (w, h), 0)
    x = (w - (r - l)) / 2 - l
    y = (bottom * scale - (b - t)) - t
    ImageDraw.Draw(mask).text((x, y), text, fill=255, font=font,
                              stroke_width=int(size * 0.012), stroke_fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(scale * 0.8)).point(
        lambda v: 255 if v > 127 else 0).resize(canvas, Image.LANCZOS)
    m = np.asarray(mask).astype(np.float32) / 255

    surface = np.asarray(mask.filter(ImageFilter.GaussianBlur(5))).astype(
        np.float32) / 255
    surface += np.asarray(mask.filter(ImageFilter.GaussianBlur(2))).astype(
        np.float32) / 255 * 0.6
    dy, dx = np.gradient(surface)
    nz = 0.11
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    light = np.array([-0.35, -0.62, 0.70])
    light /= np.linalg.norm(light)
    diffuse = np.clip((-dx * light[0] - dy * light[1] + nz * light[2]) / length,
                      0, 1)
    color = green_ramp(diffuse ** 1.3 * 1.1 - 0.05)

    shadow = Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(8))
    shadow = np.roll(np.asarray(shadow).astype(np.float32) / 255, 7, 0) * 0.55
    alpha = np.maximum(m, shadow)
    weight = (m / np.maximum(alpha, 1e-3))[..., None]
    rgb = color * weight + np.zeros(3, np.float32) * (1 - weight)
    save_webp(np.dstack([rgb, alpha * 255]), path_out)


def write_arc_path(source: str) -> None:
    with open(source, encoding="utf-8") as f:
        body = f.read()
    body = body[body.index("const double logoCanvasAspectRatio"):]
    color = "0xFF%02X%02X%02X" % BACKGROUND
    target = os.path.join(ROOT, "lib", "features", "splash", "logo_arc_path.g.dart")
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            "// Üretildi: tool/brand/build_intro_layers.py. Elle düzenlemeyin.\n"
            "//\n"
            "// Açılış logosundaki yayın orta çizgisi (soldan sağa çizim sırası).\n"
            "// Koordinatlar katman tuvaline oranlıdır (0..1).\n\n"
            "import 'dart:ui';\n\n"
            "/// Açılış zemini (Flutter açılış ekranı ve yerel açılış).\n"
            f"const Color logoSplashBackground = Color({color});\n\n" + body)


def composite(names) -> Image.Image:
    layers = [Image.open(os.path.join(OUT, f"{n}.webp")).convert("RGBA")
              for n in names]
    full = Image.new("RGBA", layers[0].size, (*BACKGROUND, 255))
    for layer in layers:
        full.alpha_composite(layer)
    return full


def content_box(names) -> tuple[int, int, int, int]:
    """Görünür logonun kutusu (gölge ve ışıma hariç)."""
    alpha = np.zeros(Image.open(os.path.join(OUT, f"{names[0]}.webp")).size[::-1])
    for n in names:
        img = load(os.path.join(OUT, f"{n}.webp"))
        visible = (img[..., 3] > 160) & (img[..., :3].max(2) > 70)
        alpha = np.maximum(alpha, visible)
    ys, xs = np.nonzero(alpha)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def icon_square(logo: Image.Image, box, fill: float, mode="RGB") -> Image.Image:
    """Logo kutusu karenin genişliğinin [fill] kadarını kaplar, ortalanır."""
    x0, y0, x1, y1 = box
    side = round((x1 - x0) / fill)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bg = (*BACKGROUND, 255) if mode == "RGB" else (0, 0, 0, 0)
    canvas = Image.new("RGBA", (side, side), bg)
    canvas.alpha_composite(logo, (round(side / 2 - cx), round(side / 2 - cy)))
    return canvas.convert(mode)


def write_icons() -> None:
    names = ("emu", "arc")
    logo = composite(names)
    box = content_box(names)
    # EmuFit ile aynı oranlar: eski ikonda logo genişliğin ~%62'si, uyarlanabilir
    # ön yüzde 108 dp tuvalin ~%42'si (güvenli alanın içinde).
    legacy = icon_square(logo, box, 0.62)
    adaptive = icon_square(logo, box, 0.42)

    # Temalı ikon (Android 13+): logonun tek renkli silüeti.
    layers = [load(os.path.join(OUT, f"{n}.webp")) for n in names]
    sil = np.zeros(layers[0].shape[:2], np.float32)
    for img in layers:
        bright = np.clip((img[..., :3].max(2) - 60) / 90, 0, 1)
        sil = np.maximum(sil, img[..., 3] / 255 * bright)
    mono_logo = Image.fromarray(
        np.dstack([np.full(sil.shape + (3,), 255, np.float32), sil * 255])
        .astype(np.uint8), "RGBA")
    mono = icon_square(mono_logo, box, 0.42, mode="RGBA")

    for name, scale in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                        ("xxhdpi", 3), ("xxxhdpi", 4)):
        px = int(48 * scale)
        legacy.resize((px, px), Image.LANCZOS).save(
            os.path.join(RES, f"mipmap-{name}", "ic_launcher.png"), optimize=True)
        px = int(108 * scale)
        adaptive.resize((px, px), Image.LANCZOS).save(
            os.path.join(RES, f"drawable-{name}", "ic_launcher_foreground.png"),
            optimize=True)
        mono.resize((px, px), Image.LANCZOS).save(
            os.path.join(RES, f"drawable-{name}", "ic_launcher_monochrome.png"),
            optimize=True)

    with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w",
              encoding="utf-8", newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<!-- tool/brand/build_intro_layers.py ile üretilir. -->\n"
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
            "</adaptive-icon>\n")

    color = "#FF%02X%02X%02X" % BACKGROUND
    with open(os.path.join(RES, "values", "colors.xml"), "w", encoding="utf-8",
              newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<!-- tool/brand/build_intro_layers.py ile üretilir. -->\n"
            "<resources>\n"
            f'    <color name="ic_launcher_background">{color}</color>\n'
            f'    <color name="splash_background">{color}</color>\n'
            "</resources>\n")

    iconset = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets",
                           "AppIcon.appiconset")
    with open(os.path.join(iconset, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    for image in contents["images"]:
        px = round(float(image["size"].split("x")[0])
                   * int(image["scale"].rstrip("x")))
        legacy.resize((px, px), Image.LANCZOS).save(
            os.path.join(iconset, image["filename"]), optimize=True)

    legacy.resize((512, 512), Image.LANCZOS).save(
        os.path.join(ROOT, "tool", "brand", "icon_preview.png"), optimize=True)


def write_launch_image() -> None:
    """iOS yerel açılışı: logonun son hâli (kelimeyle birlikte)."""
    full = composite(("emu", "arc", "gider")).convert("RGB")
    folder = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets",
                          "LaunchImage.imageset")
    width = 200
    height = round(width * full.height / full.width)
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        full.resize((width * scale, height * scale), Image.LANCZOS).save(
            os.path.join(folder, f"LaunchImage{suffix}.png"), optimize=True)


def main() -> None:
    sibling = (sys.argv[1] if len(sys.argv) > 1
               else os.path.join(ROOT, "..", "emuboykot-main"))
    source = os.path.join(sibling, "assets", "images", "brand", "splash")
    os.makedirs(OUT, exist_ok=True)
    neutralize_red(os.path.join(source, "emu.webp"), os.path.join(OUT, "emu.webp"))
    recolor_arc(os.path.join(source, "arc.webp"), os.path.join(OUT, "arc.webp"))
    canvas = Image.open(os.path.join(source, "emu.webp")).size
    render_word("Gider", canvas, word_box(os.path.join(source, "boykot.webp")),
                os.path.join(OUT, "gider.webp"))
    write_arc_path(os.path.join(sibling, "lib", "features", "splash",
                                "logo_arc_path.g.dart"))
    write_launch_image()
    write_icons()


if __name__ == "__main__":
    main()
