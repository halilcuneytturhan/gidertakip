#!/usr/bin/env python3
"""Mağaza başvurusu için barındırılan yasal sayfaları üretir.

Kaynak: assets/legal/*.md (uygulama içinde gösterilen metinlerle AYNI dosya).
Çıktı:  docs/legal/gizlilik.html, docs/legal/kosullar.html, docs/legal/index.html

    python3 tool/legal/build_legal_pages.py \
        --developer "Ad Soyad" --contact destek@ornek.com

Sayfalar GitHub Pages (Settings → Pages → /docs) veya herhangi bir statik
sunucuda yayınlanabilir; gizlilik adresi mağaza kayıtlarına girilir. Markdown kuralları
lib/features/legal/legal_document_screen.dart → parseLegalMarkdown ile aynıdır.
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "gizlilik.html": ROOT / "assets/legal/gizlilik_politikasi.md",
    "kosullar.html": ROOT / "assets/legal/kullanim_kosullari.md",
}
OUT = ROOT / "docs/legal"

DEFAULT_DEVELOPER = "EmuGider geliştiricisi"
DEFAULT_CONTACT = (
    "uygulamanın App Store / Google Play sayfasındaki geliştirici e-posta adresi"
)

STYLE = """
:root { color-scheme: light dark; --bg:#f6f5f2; --fg:#1b1b1a; --muted:#5e5c57;
  --accent:#0f6b5c; --card:#ffffff; }
@media (prefers-color-scheme: dark) { :root { --bg:#1d1b20; --fg:#f2eef4;
  --muted:#b5afb9; --accent:#5fc2ad; --card:#2a272e; } }
body { margin:0; background:var(--bg); color:var(--fg);
  font:16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
main { max-width:760px; margin:0 auto; padding:24px 16px 48px; }
article { background:var(--card); border-radius:20px; padding:8px 24px 24px; }
h1 { font-size:1.6rem; } h2 { font-size:1.2rem; margin-top:1.8em; }
h3 { font-size:1.05rem; }
a { color:var(--accent); word-break:break-word; }
nav { margin-bottom:16px; color:var(--muted); }
"""


def inline(text: str) -> str:
    out = []
    for i, part in enumerate(text.split("**")):
        part = html.escape(part)
        part = re.sub(
            r"(https?://[^\s)]+[^\s).,;])", r'<a href="\1">\1</a>', part
        )
        part = re.sub(
            r"([\w.+-]+@[\w-]+\.[\w.-]+[\w])", r'<a href="mailto:\1">\1</a>', part
        )
        out.append(f"<strong>{part}</strong>" if i % 2 else part)
    return "".join(out)


def render(markdown: str) -> tuple[str, str]:
    title = ""
    body: list[str] = []
    paragraph: list[str] = []
    in_list = False

    def flush() -> None:
        nonlocal in_list
        if paragraph:
            body.append(f"<p>{inline(' '.join(paragraph))}</p>")
            paragraph.clear()

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            body.append("</ul>")
            in_list = False

    for raw in markdown.split("\n"):
        line = raw.strip()
        if not line:
            flush()
            close_list()
            continue
        for prefix, tag in (("### ", "h3"), ("## ", "h2"), ("# ", "h1")):
            if line.startswith(prefix):
                flush()
                close_list()
                text = line[len(prefix):].strip()
                if tag == "h1":
                    title = text
                body.append(f"<{tag}>{inline(text)}</{tag}>")
                break
        else:
            if line.startswith("- "):
                flush()
                if not in_list:
                    body.append("<ul>")
                    in_list = True
                body.append(f"<li>{inline(line[2:].strip())}</li>")
            else:
                close_list()
                paragraph.append(line)
    flush()
    close_list()
    return title, "\n".join(body)


def page(title: str, content: str) -> str:
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · EmuGider</title>
<style>{STYLE}</style>
</head>
<body>
<main>
<nav><a href="index.html">EmuGider</a> · <a href="gizlilik.html">Gizlilik</a> · <a href="kosullar.html">Koşullar</a></nav>
<article>
{content}
</article>
</main>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--developer", default=DEFAULT_DEVELOPER)
    parser.add_argument("--contact", default=DEFAULT_CONTACT)
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    titles = {}
    for name, source in SOURCES.items():
        text = (
            source.read_text(encoding="utf-8")
            .replace("{{DEVELOPER}}", args.developer)
            .replace("{{CONTACT}}", args.contact)
        )
        title, content = render(text)
        titles[name] = title
        (OUT / name).write_text(page(title, content), encoding="utf-8")
        print(f"yazıldı: {(OUT / name).relative_to(ROOT)}")

    links = "\n".join(
        f'<li><a href="{name}">{html.escape(title)}</a></li>'
        for name, title in titles.items()
    )
    index = (
        "<h1>EmuGider</h1>\n<p>Yazdığın harcamaları gün gün toplayan sade "
        "gider takibi. Hesap gerekmez, veriler yalnızca cihazda kalır.</p>\n"
        f"<ul>\n{links}\n</ul>\n<p>İletişim: {inline(args.contact)}</p>"
    )
    (OUT / "index.html").write_text(page("EmuGider", index), encoding="utf-8")
    print(f"yazıldı: {(OUT / 'index.html').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
