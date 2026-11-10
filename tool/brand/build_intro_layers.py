"""EMU ailesi açılış logosunun EmuGider katmanlarını üretir.

    python tool/brand/build_intro_layers.py [EmuMini klasörü]

Beyaz EMU harfleri ve yay, ailenin ortak logosudur: EmuMini'nin açılış
katmanlarından alınır (varsayılan: ../emumini). Yay EmuGider yeşiline boyanır,
altına aynı kabartma tarzında "Gider" yazısı çizilir.

Üretilenler:
  * assets/images/brand/splash/{emu,arc,gider}.webp
  * lib/features/splash/logo_arc_path.g.dart (yayın çizim sırası)
  * iOS LaunchImage (açılış logosunun durağan hâli)
  * Android ve iOS uygulama ikonları, values/colors.xml
"""

from __future__ import annotations

import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito-ExtraBold.ttf")
OUT = os.path.join(ROOT, "assets", "images", "brand", "splash")

BACKGROUND = (0xF9, 0xF1, 0xE9)  # EmuMini ile aynı krem zemin

# Yay ve yazının gölgeden parlağa renkleri (ana yeşil #0F6B5C çevresinde).
GREEN_DARK = np.array([0x0A, 0x52, 0x46], np.float32)
GREEN_MID = np.array([0x0F, 0x6B, 0x5C], np.float32)
GREEN_LIGHT = np.array([0x3B, 0xA5, 0x90], np.float32)


def green_ramp(t: np.ndarray) -> np.ndarray:
    """t: 0 (gölge) .. 1 (parlak)."""
    t = np.clip(t, 0, 1)[..., None]
    low = GREEN_DARK + (GREEN_MID - GREEN_DARK) * np.clip(t / 0.5, 0, 1)
    return low + (GREEN_LIGHT - GREEN_MID) * np.clip((t - 0.5) / 0.5, 0, 1)


def recolor_arc(path_in: str, path_out: str) -> None:
    """Mercan pikselleri yeşile çevirir; aydınlık/gölge bilgisi korunur."""
    img = np.asarray(Image.open(path_in).convert("RGBA")).astype(np.float32)
    rgb, alpha = img[..., :3], img[..., 3]
    bg_chroma = BACKGROUND[0] - BACKGROUND[2]
    chroma = (rgb[..., 0] - rgb[..., 2]) - bg_chroma
    # Yumuşak geçiş: tam mercan gövde yeşile döner, kenarlar kademeli karışır.
    t = np.clip((chroma - 22) / 50, 0, 1)
    coral = (t * t * (3 - 2 * t))[..., None]
    lum = rgb.mean(2)
    body = (chroma > 60) & (alpha > 128)
    low, high = np.percentile(lum[body], [3, 97])
    mapped = green_ramp((lum - low) / (high - low))
    # Yayın pembe gölgesi, EMU harflerindeki gibi sıcak griye çevrilir.
    background = np.array(BACKGROUND, np.float32)
    neutral = background * (lum / background.mean())[..., None]
    pink = np.clip(chroma / 22, 0, 1)[..., None]
    base = rgb * (1 - pink) + neutral * pink
    out = base * (1 - coral) + mapped * coral
    rgba = np.dstack([out, alpha]).round().clip(0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(path_out, "WEBP", quality=92, method=6)


def word_box(mini_path: str) -> tuple[int, int, int, int]:
    """Kaynak logodaki kelimenin (Mini) kutusu: yeni kelime aynı yere oturur."""
    img = np.asarray(Image.open(mini_path).convert("RGBA")).astype(np.float32)
    chroma = (img[..., 0] - img[..., 2]) - (BACKGROUND[0] - BACKGROUND[2])
    ys, xs = np.nonzero((chroma > 60) & (img[..., 3] > 128))
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def render_word(text: str, canvas: tuple[int, int], box, path_out: str) -> None:
    """Kelimeyi kabartma olarak çizer: yumuşak kenar, üstten ışık, gölge."""
    scale = 4
    w, h = canvas[0] * scale, canvas[1] * scale
    _, top, _, bottom = box
    # Taban çizgisi kaynak kelimeyle aynı; "Gider" geniş olduğu için biraz küçük.
    target = int((bottom - top) * scale * 0.9)
    top = bottom - target / scale
    size = target
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = font.getbbox(text)
    size = int(size * target / (b - t))
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = font.getbbox(text)

    mask = Image.new("L", (w, h), 0)
    x = (w - (r - l)) / 2 - l
    y = top * scale - t
    draw = ImageDraw.Draw(mask)
    # Köşeleri yuvarlamak için hafifçe kalınlaştırılır.
    draw.text((x, y), text, fill=255, font=font, stroke_width=int(size * 0.012),
              stroke_fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(scale * 0.8)).point(
        lambda v: 255 if v > 127 else 0).resize(canvas, Image.LANCZOS)
    m = np.asarray(mask).astype(np.float32) / 255

    # Kenardan içe yükselen şişkin yüzey.
    surface = np.asarray(mask.filter(ImageFilter.GaussianBlur(5))).astype(
        np.float32) / 255
    surface += np.asarray(mask.filter(ImageFilter.GaussianBlur(2))).astype(
        np.float32) / 255 * 0.6
    dy, dx = np.gradient(surface)
    nz = 0.11
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nz3 = -dx / length, -dy / length, nz / length
    # Işık sol üstten.
    light = np.array([-0.35, -0.62, 0.70])
    light /= np.linalg.norm(light)
    diffuse = np.clip(nx * light[0] + ny * light[1] + nz3 * light[2], 0, 1)
    color = green_ramp(diffuse ** 1.3 * 1.12 - 0.1)

    # Alt gölge (EMU harflerindeki gibi yumuşak).
    shadow = Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(7))
    shadow = np.roll(np.asarray(shadow).astype(np.float32) / 255, 6, 0) * 0.28

    alpha = np.maximum(m, shadow)
    # Gölge pikselleri koyu, yazı pikselleri renkli.
    shadow_color = np.array([0x6E, 0x5E, 0x50], np.float32)
    weight = (m / np.maximum(alpha, 1e-3))[..., None]
    rgb = color * weight + shadow_color * (1 - weight)
    rgba = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(path_out, "WEBP", quality=92, method=6)


def write_arc_path(source: str) -> None:
    with open(source, encoding="utf-8") as f:
        body = f.read()
    body = body[body.index("const double logoCanvasAspectRatio"):]
    color = "0xFF%02X%02X%02X" % BACKGROUND
    target = os.path.join(ROOT, "lib", "features", "splash", "logo_arc_path.g.dart")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            "// Üretildi: tool/brand/build_intro_layers.py. Elle düzenlemeyin.\n"
            "//\n"
            "// Açılış logosundaki yayın orta çizgisi (soldan sağa çizim sırası).\n"
            "// Koordinatlar katman tuvaline oranlıdır (0..1).\n\n"
            "import 'dart:ui';\n\n"
            "/// Açılış zemini (Flutter açılış ekranı ve yerel açılış).\n"
            f"const Color logoSplashBackground = Color({color});\n\n" + body)


def write_launch_image() -> None:
    """iOS yerel açılışı: logonun son hâli, EmuMini ile aynı genişlikte."""
    layers = [Image.open(os.path.join(OUT, f"{n}.webp")).convert("RGBA")
              for n in ("emu", "arc", "gider")]
    full = Image.new("RGBA", layers[0].size, (*BACKGROUND, 255))
    for layer in layers:
        full.alpha_composite(layer)
    folder = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets",
                          "LaunchImage.imageset")
    width = 168
    height = round(width * full.height / full.width)
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        full.convert("RGB").resize((width * scale, height * scale),
                                   Image.LANCZOS).save(
            os.path.join(folder, f"LaunchImage{suffix}.png"), optimize=True)


def full_logo() -> Image.Image:
    """Katmanların krem zemin üzerindeki son hâli."""
    layers = [Image.open(os.path.join(OUT, f"{n}.webp")).convert("RGBA")
              for n in ("emu", "arc", "gider")]
    full = Image.new("RGBA", layers[0].size, (*BACKGROUND, 255))
    for layer in layers:
        full.alpha_composite(layer)
    return full


def icon_square(ratio: float) -> Image.Image:
    """Logo ortada, krem kare; ratio: kare kenarı / logo genişliği."""
    logo = full_logo()
    side = round(logo.width * ratio)
    canvas = Image.new("RGBA", (side, side), (*BACKGROUND, 255))
    canvas.alpha_composite(logo, ((side - logo.width) // 2,
                                  (side - logo.height) // 2))
    return canvas.convert("RGB")


def write_icons() -> None:
    """Uygulama ikonları: EMU ailesiyle aynı, EmuMini'deki oranlarla."""
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    legacy = icon_square(1.08)
    # Uyarlanabilir ikon: logo güvenli alanın (orta %66) içinde kalır.
    adaptive = icon_square(1.55)
    for name, scale in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                        ("xxhdpi", 3), ("xxxhdpi", 4)):
        px = int(48 * scale)
        legacy.resize((px, px), Image.LANCZOS).save(
            os.path.join(res, f"mipmap-{name}", "ic_launcher.png"), optimize=True)
        px = int(108 * scale)
        adaptive.resize((px, px), Image.LANCZOS).save(
            os.path.join(res, f"drawable-{name}", "ic_launcher_foreground.png"),
            optimize=True)

    with open(os.path.join(res, "mipmap-anydpi-v26", "ic_launcher.xml"), "w",
              encoding="utf-8", newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<!-- tool/brand/build_intro_layers.py ile üretilir. -->\n"
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
            "</adaptive-icon>\n")

    color = "#FF%02X%02X%02X" % BACKGROUND
    with open(os.path.join(res, "values", "colors.xml"), "w", encoding="utf-8",
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
        # iOS ikonu saydamlık içermemeli (icon_square zaten RGB döner).
        legacy.resize((px, px), Image.LANCZOS).save(
            os.path.join(iconset, image["filename"]), optimize=True)

    legacy.resize((512, 512), Image.LANCZOS).save(
        os.path.join(ROOT, "tool", "brand", "icon_preview.png"), optimize=True)


def main() -> None:
    sibling = (sys.argv[1] if len(sys.argv) > 1
               else os.path.join(ROOT, "..", "emumini"))
    source = os.path.join(sibling, "assets", "images", "brand", "splash")
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(os.path.join(source, "emu.webp"), os.path.join(OUT, "emu.webp"))
    recolor_arc(os.path.join(source, "arc.webp"), os.path.join(OUT, "arc.webp"))
    canvas = Image.open(os.path.join(source, "emu.webp")).size
    render_word("Gider", canvas, word_box(os.path.join(source, "mini.webp")),
                os.path.join(OUT, "gider.webp"))
    write_arc_path(os.path.join(sibling, "lib", "features", "splash",
                                "logo_arc_path.g.dart"))
    write_launch_image()
    write_icons()


if __name__ == "__main__":
    main()
