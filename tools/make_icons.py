#!/usr/bin/env python3
"""Иконки интерфейса в одном стиле: белая линия 2.2 px на сетке 24×24, скруглённые концы.
Белые иконки перекрашиваются в игре через modulate. Монета — цветная.

Запуск из корня проекта:  python3 tools/make_icons.py  →  assets/ui/icons/<имя>.svg
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "icons")

STROKE = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24" fill="none" '
          'stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">{}</svg>\n')

ICONS = {
    "hammer": '<path d="M14 4l6 6-3 3-6-6z"/><path d="M12.5 10.5L4.2 18.8a1.6 1.6 0 0 0 2.3 2.3l8.3-8.3"/><path d="M14 4l1.6-1.6 6 6L20 10"/>',
    "rotate": '<rect x="3" y="10" width="10" height="10" rx="2"/><path d="M8 6h6a5 5 0 0 1 5 5v3"/><path d="M16 12l3 3 3-3"/>',
    "shuffle": '<path d="M3 7h4l10 10h4"/><path d="M3 17h4l3-3"/><path d="M14 10l3-3h4"/><path d="M18 4l3 3-3 3"/><path d="M18 14l3 3-3 3"/>',
    "undo": '<path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
    "restart": '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 4v5h-5"/>',
    "tasks": '<rect x="5" y="4" width="14" height="17" rx="2.5"/><path d="M9 4V2.8h6V4"/><path d="M8.5 12.5l2.3 2.3 4.7-4.8"/>',
    "settings": None,  # шестерёнка строится в gear_path()
    "trophy": '<path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4"/><path d="M12 13v4M8 21h8M9.5 21v-2h5v2"/>',
    "flame": '<path d="M12 21a6 6 0 0 0 6-6c0-4-3-6-4-10-2 2-3 4-3 6-1-1-1.5-2-1.5-3C7 10 6 12.5 6 15a6 6 0 0 0 6 6z"/>',
    "star": '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    "gift": '<rect x="3.5" y="9" width="17" height="12" rx="2"/><path d="M3.5 13h17M12 9v12"/><path d="M12 9C10.5 5 6.5 4.5 7 7.5 7.4 9 10 9 12 9zM12 9c1.5-4 5.5-4.5 5-1.5-.4 1.5-3 1.5-5 1.5z"/>',
    "lock": '<rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    "back": '<path d="M15 5l-7 7 7 7"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7"/>',
    "edit": '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    "sparkle": '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 16v4M17 18h4"/>',
    "palette": '<path d="M12 3a9 9 0 1 0 0 18c1.2 0 1.8-.8 1.8-1.7 0-1.3-1.2-1.6-1.2-2.8 0-1 .8-1.5 1.8-1.5H17a4 4 0 0 0 4-4c0-4.4-4-8-9-8z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="14.5" cy="7" r="1"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    "chart": '<path d="M4 20h16"/><rect x="5.5" y="11" width="3" height="7" rx="1"/><rect x="10.5" y="5" width="3" height="13" rx="1"/><rect x="15.5" y="13.5" width="3" height="4.5" rx="1"/>',
    "layers": '<path d="M12 3.5l8.5 4.5-8.5 4.5-8.5-4.5z"/><path d="M3.5 12.5l8.5 4.5 8.5-4.5"/><path d="M3.5 16.5l8.5 4.5 8.5-4.5"/>',
    "frame": '<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><rect x="8" y="8" width="8" height="8" rx="2"/>',
    "circle": '<circle cx="12" cy="12" r="8"/>',
    "zen": '<path d="M12 20c-4 0-8-2-9-6 3 0 6 1 9 4 3-3 6-4 9-4-1 4-5 6-9 6z"/><path d="M12 18c-2-2-3-5-3-8 1-2 2-4 3-6 1 2 2 4 3 6 0 3-1 6-3 8z"/>',
}

def gear_path(teeth=8, outer=9.6, inner=7.4):
    """Шестерёнка: зубцы — трапеции по окружности."""
    points = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step
        for da, r in ((-0.30, inner), (-0.17, outer), (0.17, outer), (0.30, inner)):
            points.append((12 + r * math.cos(a + da * step * 1.6), 12 + r * math.sin(a + da * step * 1.6)))
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in points) + " Z"
    return f'<path d="{d}"/><circle cx="12" cy="12" r="3"/>'


COIN = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24">'
        '<defs><radialGradient id="g" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff3b8"/>'
        '<stop offset="0.5" stop-color="#ffcf4a"/><stop offset="1" stop-color="#d9930f"/></radialGradient></defs>'
        '<circle cx="12" cy="12" r="10.5" fill="url(#g)" stroke="#a86d06" stroke-width="1.2"/>'
        '<circle cx="12" cy="12" r="7" fill="none" stroke="#c4840d" stroke-width="1.4" opacity="0.8"/>'
        '<path d="M12 7.5l1.3 2.8 3 .4-2.2 2.1.6 3L12 14.3l-2.7 1.5.6-3-2.2-2.1 3-.4z" fill="#fff6d0" opacity="0.9"/>'
        '</svg>\n')


def main():
    os.makedirs(OUT, exist_ok=True)
    ICONS["settings"] = gear_path()
    for name, body in ICONS.items():
        with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as f:
            f.write(STROKE.format(body))
    with open(os.path.join(OUT, "coin.svg"), "w", encoding="utf-8") as f:
        f.write(COIN)
    print(f"Иконок: {len(ICONS) + 1}")


if __name__ == "__main__":
    main()
