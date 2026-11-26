"""EmuGider'ın beyaz fiş işaretini koddan üretir.

    python3 tool/brand/build_brand_assets.py

İşaret: beyaz bir fiş; satırlar fişten oyulmuştur, alttaki kalın satır
"toplam"dır. Uygulama ikonları ve açılış logosu build_intro_layers.py ile
üretilir.

Üretilenler:
  * Android: drawable-*/ic_notification.png (bildirim simgesi)
  * assets/images/brand/splash_mark.png (PDF raporunun başlığındaki işaret)
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
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


def save(img: Image.Image, *parts: str) -> None:
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
RES = ("android", "app", "src", "main", "res")


def android() -> None:
    for name, scale in ANDROID_DENSITIES.items():
        # Bildirim simgesi: 24 dp, beyaz fiş (Android yalnızca saydamlığı kullanır).
        ni = int(24 * scale)
        save(mark(ni, 0.92), *RES, f"drawable-{name}", "ic_notification.png")


def flutter_assets() -> None:
    save(mark(288, 0.92), "assets", "images", "brand", "splash_mark.png")


if __name__ == "__main__":
    android()
    flutter_assets()
    print("ok")
