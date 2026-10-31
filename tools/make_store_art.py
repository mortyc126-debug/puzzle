#!/usr/bin/env python3
"""Иконка приложения и картинки для магазина (SVG).

Запуск из корня проекта:  python3 tools/make_store_art.py
SVG:  icon.svg (иконка проекта), assets/icon/*.svg, store/feature_graphic.svg
PNG для Android и магазина получаются из SVG любым конвертером (Inkscape, браузер):
  assets/icon/icon_192.png              192×192   — иконка лаунчера
  assets/icon/icon_foreground_432.png   432×432   — адаптивная иконка, передний план
  assets/icon/icon_background_432.png   432×432   — адаптивная иконка, фон
  store/icon_512.png                    512×512   — иконка в Google Play / RuStore
  store/feature_graphic.png             1024×500  — баннер Google Play
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

COLORS = ["#4170ff", "#ffd23f", "#ff4d5e", "#33c770"]
LIGHT = {"#4170ff": "#7095ff", "#ffd23f": "#ffe27a", "#ff4d5e": "#ff8590", "#33c770": "#6ddc9a"}
DARK = {"#4170ff": "#2b4cb3", "#ffd23f": "#b8921f", "#ff4d5e": "#b3323f", "#33c770": "#22874c"}


def block(x, y, s, color):
    """Блок в стиле темы «Классика»: тень, светлая верхняя половина, белая обводка."""
    r = s * 0.14
    w = max(3, s * 0.05)
    return (
        f'<rect x="{x + s * 0.04}" y="{y + s * 0.06}" width="{s}" height="{s}" rx="{r}" fill="{DARK[color]}"/>'
        f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{r}" fill="{color}"/>'
        f'<path d="M{x + r} {y} H{x + s - r} A{r} {r} 0 0 1 {x + s} {y + r} V{y + s / 2} H{x} V{y + r} '
        f'A{r} {r} 0 0 1 {x + r} {y} Z" fill="{LIGHT[color]}"/>'
        f'<rect x="{x + w / 2}" y="{y + w / 2}" width="{s - w}" height="{s - w}" rx="{r}" fill="none" '
        f'stroke="#fff" stroke-width="{w}"/>'
    )


def sparkle(x, y, s, color="#fff"):
    return (f'<path d="M{x} {y - s} L{x + s * 0.25} {y - s * 0.25} L{x + s} {y} L{x + s * 0.25} {y + s * 0.25} '
            f'L{x} {y + s} L{x - s * 0.25} {y + s * 0.25} L{x - s} {y} L{x - s * 0.25} {y - s * 0.25} Z" fill="{color}"/>')


BG_DEFS = ('<radialGradient id="bg" cx="0.5" cy="0.2" r="0.9"><stop offset="0" stop-color="#2a3a8c"/>'
           '<stop offset="0.65" stop-color="#121a45"/><stop offset="1" stop-color="#0b1030"/></radialGradient>')


def icon_blocks(size, scale=1.0):
    """Четыре блока 2×2 по центру квадрата size."""
    s = size * 0.28 * scale
    gap = size * 0.035 * scale
    total = 2 * s + gap
    x0 = (size - total) / 2
    y0 = (size - total) / 2 + size * 0.01
    out = ""
    for i, color in enumerate(COLORS):
        out += block(x0 + (i % 2) * (s + gap), y0 + (i // 2) * (s + gap), s, color)
    out += sparkle(x0 + total + s * 0.15, y0 - s * 0.05, s * 0.18)
    return out


def svg(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{defs}</defs>{body}</svg>\n')


def write(path, content):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full) or ".", exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    # Полная иконка: фон со скруглением + блоки
    full_icon = svg(512, 512, '<rect width="512" height="512" rx="112" fill="url(#bg)"/>' + icon_blocks(512), BG_DEFS)
    write("icon.svg", full_icon)
    write("assets/icon/icon.svg", full_icon)
    # Для магазина — квадрат без скругления: Google Play и RuStore скругляют сами
    write("store/icon_512.svg", svg(512, 512, '<rect width="512" height="512" fill="url(#bg)"/>' + icon_blocks(512), BG_DEFS))

    # Адаптивная иконка Android: фон и передний план отдельно, без скругления —
    # форму маски задаёт система. Значимое — в центральных 66%.
    write("assets/icon/icon_background.svg", svg(432, 432, '<rect width="432" height="432" fill="url(#bg)"/>', BG_DEFS))
    write("assets/icon/icon_foreground.svg", svg(432, 432, icon_blocks(432, 0.72)))

    # Баннер Google Play 1024×500: мини-поле слева, название справа
    cells = ""
    pattern = [
        "....YY..", "B...YY..", "BB......", "B..RRR..",
        "......G.", "Y....GG.", "YYBB..G.", "BBBBRRR.",
    ]
    letter_color = {"B": COLORS[0], "Y": COLORS[1], "R": COLORS[2], "G": COLORS[3]}
    cell = 50
    ox, oy = 80, 50
    cells += f'<rect x="{ox - 12}" y="{oy - 12}" width="{cell * 8 + 24}" height="{cell * 8 + 24}" rx="22" fill="#171e45" opacity="0.95"/>'
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            px, py = ox + x * cell, oy + y * cell
            if ch == ".":
                cells += f'<rect x="{px + 3}" y="{py + 3}" width="{cell - 6}" height="{cell - 6}" rx="7" fill="#232c5e"/>'
            else:
                cells += block(px + 2, py + 2, cell - 4, letter_color[ch])
    title = (
        '<text x="580" y="215" font-family="Arial Black, Arial, sans-serif" font-size="78" font-weight="900" fill="#fff">Block</text>'
        '<text x="580" y="300" font-family="Arial Black, Arial, sans-serif" font-size="78" font-weight="900" fill="#ffd23f">Puzzle</text>'
        '<text x="582" y="360" font-family="Arial, sans-serif" font-size="30" fill="#b9c3f2">Без рекламы · без интернета</text>'
    )
    stars = "".join(sparkle(x, y, r) for x, y, r in ((960, 70, 9), (540, 440, 7), (990, 420, 6), (520, 60, 5)))
    write("store/feature_graphic.svg", svg(1024, 500, '<rect width="1024" height="500" fill="url(#bg)"/>' + cells + title + stars, BG_DEFS))
    print("SVG готовы")


if __name__ == "__main__":
    main()
