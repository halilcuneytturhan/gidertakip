"""EmuGider marka varlıklarını (ikon ve açılış görseli) koddan üretir.

    python3 tool/brand/build_brand_assets.py

İşaret: yeşil zemin üzerinde beyaz bir fiş; satırlar fişten oyulmuştur
(zemin rengi görünür), alttaki kalın satır "toplam"dır. Tek renkli olduğu
için Android 13+ temalı ikonda da aynen kullanılır.

Üretilenler:
  * Android: mipmap-*/ic_launcher.png (eski cihazlar), uyarlanabilir ikon
    (drawable-*/ic_launcher_foreground.png + mipmap-anydpi-v26), açılış
    işareti drawable-*/splash_mark.png
  * iOS: AppIcon.appiconset (opak), LaunchImage.imageset
  * assets/images/brand/splash_mark.png (uygulama içi açılış ekranı)
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GREEN = (0x0F, 0x6B, 0x5C, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # kenar yumuşatma için büyük çizip küçültme oranı


def mark(size: int, height_frac: float) -> Image.Image:
    """Şeffaf zeminde beyaz fiş; [height_frac] fişin tuvale oranı."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    h = S * height_frac
    w = h * 0.78
    x0 = (S - w) / 2
    y0 = (S - h) / 2
    x1 = x0 + w
    y1 = y0 + h
    r = w * 0.12
    teeth = 5
    tooth_h = h * 0.07

    # Gövde: üst köşeler yuvarlak, alt kenar testere dişli.
    d.rounded_rectangle([x0, y0, x1, y1 - tooth_h], radius=r, fill=WHITE)
    d.rectangle([x0, y0 + r, x1, y1 - tooth_h], fill=WHITE)
    step = w / teeth
    points = [(x0, y1 - tooth_h)]
    for i in range(teeth):
        points.append((x0 + step * (i + 0.5), y1))
        points.append((x0 + step * (i + 1), y1 - tooth_h))
    points.append((x1, y1 - tooth_h - 1))
    points.append((x0, y1 - tooth_h - 1))
    d.polygon(points, fill=WHITE)

    # Oyulmuş satırlar.
    clear = (0, 0, 0, 0)
    pad = w * 0.18
    line_h = h * 0.065
    lx0 = x0 + pad
    lx1 = x1 - pad
    lw = lx1 - lx0
    ys = [y0 + h * 0.20, y0 + h * 0.34, y0 + h * 0.48]
    widths = [0.82, 0.62, 0.74]
    for y, f in zip(ys, widths):
        d.rounded_rectangle(
            [lx0, y, lx0 + lw * f, y + line_h], radius=line_h / 2, fill=clear
        )
    ty = y0 + h * 0.66
    total_h = line_h * 1.6
    d.rounded_rectangle(
        [lx0, ty, lx1, ty + total_h], radius=total_h / 2, fill=clear
    )

    return img.resize((size, size), Image.LANCZOS)


def full_icon(size: int) -> Image.Image:
    """Opak, kare uygulama ikonu (iOS ve eski Android)."""
    bg = Image.new("RGBA", (size, size), GREEN)
    bg.alpha_composite(mark(size, 0.56))
    return bg


def save(img: Image.Image, *parts: str, opaque: bool = False) -> None:
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if opaque else img).save(path, optimize=True)


ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
RES = ("android", "app", "src", "main", "res")


def android() -> None:
    for name, scale in ANDROID_DENSITIES.items():
        # Eski (API < 26) ikon: 48 dp, yuvarlatılmış kare.
        legacy = int(48 * scale)
        icon = full_icon(legacy * 4)
        rounded = Image.new("L", icon.size, 0)
        ImageDraw.Draw(rounded).rounded_rectangle(
            [0, 0, icon.size[0] - 1, icon.size[1] - 1],
            radius=icon.size[0] * 0.2,
            fill=255,
        )
        icon.putalpha(rounded)
        save(icon.resize((legacy, legacy), Image.LANCZOS), *RES, f"mipmap-{name}", "ic_launcher.png")

        # Uyarlanabilir ikon ön yüzü: 108 dp tuval, güvenli alan 66 dp.
        fg = int(108 * scale)
        save(mark(fg, 0.46), *RES, f"drawable-{name}", "ic_launcher_foreground.png")

        # Açılış işareti: 96 dp.
        sm = int(96 * scale)
        save(mark(sm, 0.92), *RES, f"drawable-{name}", "splash_mark.png")

        # Bildirim simgesi: 24 dp, beyaz fiş (Android yalnızca saydamlığı kullanır).
        ni = int(24 * scale)
        save(mark(ni, 0.92), *RES, f"drawable-{name}", "ic_notification.png")


def ios() -> None:
    base = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")
    with open(os.path.join(base, "AppIcon.appiconset", "Contents.json")) as f:
        contents = json.load(f)
    master = full_icon(1024)
    for image in contents["images"]:
        pts = float(image["size"].split("x")[0])
        px = round(pts * int(image["scale"].rstrip("x")))
        save(
            master.resize((px, px), Image.LANCZOS),
            "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", image["filename"],
            opaque=True,
        )
    for suffix, scale in (("", 1), ("@2x", 2), ("@3x", 3)):
        save(
            mark(96 * scale, 0.92),
            "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset", f"LaunchImage{suffix}.png",
        )


def flutter_assets() -> None:
    save(mark(288, 0.92), "assets", "images", "brand", "splash_mark.png")
    save(full_icon(512), "tool", "brand", "icon_preview.png", opaque=True)


if __name__ == "__main__":
    android()
    ios()
    flutter_assets()
    print("ok")
