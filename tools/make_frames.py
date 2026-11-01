#!/usr/bin/env python3
"""Рамки аватарок для Block Puzzle (SVG).

Запуск из корня проекта:  python3 tools/make_frames.py  →  assets/frames/frame_<id>.svg

Как устроена рамка (сетка 256×256, отрисовка 320×320):
- скруглённое кольцо облегает аватарку: аватарка занимает 17.6…238.4 (так её кладут игра и профиль —
  рамка на 16% больше аватарки), кольцо — от 5 до 20, поэтому край аватарки чуть заходит под рамку;
- объём: металлический градиент, светлая кромка снаружи, тень по внутреннему краю, блик сверху;
- чем выше редкость, тем богаче украшения: заклёпки → камни по углам → гербы сверху и снизу →
  свечение → корона. Тематические рамки (карамель, волна, дуб, пиксели) — со своими мотивами.
Названия, редкость и условия открытия — в autoload/items_db.gd.
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME_DIR = os.path.join(ROOT, "assets", "frames")

OUTER, OUTER_R = 5.0, 46.0   # внешний край кольца
INNER, INNER_R = 20.0, 31.0  # внутренний край (под ним край аватарки)
MID = (OUTER + INNER) / 2.0  # средняя линия кольца — сюда садятся камни и заклёпки
MID_R = (OUTER_R + INNER_R) / 2.0


def rounded(inset, r, size=256.0):
    a, b = inset, size - inset
    return (f"M{a + r:.2f} {a:.2f} H{b - r:.2f} A{r:.2f} {r:.2f} 0 0 1 {b:.2f} {a + r:.2f} "
            f"V{b - r:.2f} A{r:.2f} {r:.2f} 0 0 1 {b - r:.2f} {b:.2f} H{a + r:.2f} "
            f"A{r:.2f} {r:.2f} 0 0 1 {a:.2f} {b - r:.2f} V{a + r:.2f} A{r:.2f} {r:.2f} 0 0 1 {a + r:.2f} {a:.2f} Z")


def square(inset, size=256.0):
    a, b = inset, size - inset
    return f"M{a} {a} H{b} V{b} H{a} Z"


RING = rounded(OUTER, OUTER_R) + " " + rounded(INNER, INNER_R)

# Точки на средней линии кольца: середины сторон и углы (под 45°)
_corner = MID + MID_R - MID_R * math.cos(math.radians(45))
CORNERS = [(_corner, _corner), (256 - _corner, _corner), (_corner, 256 - _corner), (256 - _corner, 256 - _corner)]
SIDES = [(MID, 128.0), (256 - MID, 128.0)]
TOP, BOTTOM = (128.0, MID), (128.0, 256 - MID)


def gradient(gid, stops, x2=1, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def gem_defs(gid, color, light="#ffffff"):
    return (f'<radialGradient id="{gid}" cx="0.35" cy="0.3" r="0.8">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="0.35" stop-color="{color}"/>'
            f'<stop offset="1" stop-color="#000000" stop-opacity="0.55"/></radialGradient>')


def gem(x, y, r, gid, rim="#ffffff"):
    return (f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r + 2:.2f}" fill="{rim}" opacity="0.85"/>'
            f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="url(#{gid})"/>'
            f'<circle cx="{x - r * 0.35:.2f}" cy="{y - r * 0.38:.2f}" r="{r * 0.28:.2f}" fill="#fff" opacity="0.9"/>')


def rivet(x, y, color):
    return (f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4.4" fill="{color}"/>'
            f'<circle cx="{x - 1.2:.2f}" cy="{y - 1.3:.2f}" r="1.6" fill="#fff" opacity="0.8"/>')


def crest(x, y, plate, gid, rim, flip=False):
    """Ромбовидный герб на кольце с камнем посередине."""
    d = -1 if flip else 1
    path = (f"M{x - 22:.2f} {y:.2f} L{x - 9:.2f} {y - 11 * d:.2f} L{x + 9:.2f} {y - 11 * d:.2f} "
            f"L{x + 22:.2f} {y:.2f} L{x + 9:.2f} {y + 11 * d:.2f} L{x - 9:.2f} {y + 11 * d:.2f} Z")
    return (f'<path d="{path}" fill="{plate}" stroke="{rim}" stroke-width="2.5" stroke-linejoin="round"/>'
            + gem(x, y, 6.5, gid, rim))


def sparkle(x, y, s, color="#ffffff", opacity=1.0):
    return (f'<path d="M{x} {y - s} Q{x} {y} {x + s} {y} Q{x} {y} {x} {y + s} Q{x} {y} {x - s} {y} Q{x} {y} {x} {y - s} Z" '
            f'fill="{color}" opacity="{opacity}"/>')


def glow(color, strength=1.0):
    return (f'<path d="{rounded(OUTER + 2, OUTER_R - 2)}" fill="none" stroke="{color}" stroke-width="12" opacity="{0.22 * strength}"/>'
            f'<path d="{rounded(OUTER + 1, OUTER_R - 1)}" fill="none" stroke="{color}" stroke-width="5" opacity="{0.35 * strength}"/>')


def ring_body(metal_stops, edge="#ffffff", shadow="#000000", ring=RING, ring_outer=None, ring_inner=None, direction=(1, 1)):
    """Кольцо: металл + светлая внешняя кромка + тень по внутреннему краю + блик сверху."""
    outer_path = ring_outer or rounded(OUTER + 0.8, OUTER_R - 0.8)
    inner_path = ring_inner or rounded(INNER - 0.6, INNER_R + 0.6)
    defs = (gradient("metal", metal_stops, *direction)
            + '<linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">'
              '<stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>'
              '<stop offset="0.35" stop-color="#ffffff" stop-opacity="0.08"/>'
              '<stop offset="0.6" stop-color="#ffffff" stop-opacity="0"/></linearGradient>')
    body = (f'<path d="{ring}" fill="url(#metal)" fill-rule="evenodd"/>'
            f'<path d="{ring}" fill="url(#shine)" fill-rule="evenodd"/>'
            f'<path d="{outer_path}" fill="none" stroke="{edge}" stroke-width="1.6" opacity="0.7"/>'
            f'<path d="{inner_path}" fill="none" stroke="{shadow}" stroke-width="2.4" opacity="0.4"/>')
    return defs, body


def frame_svg(defs, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 256 256">'
            f"<defs>{defs}</defs>{body}</svg>\n")


def build(metal, *, glow_color=None, glow_strength=1.0, rivets=None, corner_gem=None, side_gem=None,
          top=None, bottom=None, extra_back="", extra_front="", extra_defs="", **ring_args):
    """metal — стопы градиента; corner_gem/side_gem — цвет камней; top/bottom — (плашка, камень, кант) герба."""
    defs, body = ring_body(metal, **ring_args)
    defs += extra_defs
    back = glow(glow_color, glow_strength) if glow_color else ""
    front = ""
    if rivets:
        front += "".join(rivet(x, y, rivets) for x, y in SIDES + [TOP, BOTTOM])
    gem_colors = {}
    for key, color in (("corner", corner_gem), ("side", side_gem), ("top", top and top[1]), ("bottom", bottom and bottom[1])):
        if color:
            gem_colors[key] = f"gem_{key}"
            defs += gem_defs(f"gem_{key}", color)
    if corner_gem:
        front += "".join(gem(x, y, 7.5, gem_colors["corner"]) for x, y in CORNERS)
    if side_gem:
        front += "".join(gem(x, y, 6.5, gem_colors["side"]) for x, y in SIDES)
    if top:
        front += crest(TOP[0], TOP[1] + 1, top[0], gem_colors["top"], top[2])
    if bottom:
        front += crest(BOTTOM[0], BOTTOM[1] - 1, bottom[0], gem_colors["bottom"], bottom[2], flip=True)
    return frame_svg(defs, back + extra_back + body + extra_front + front)


def stripes(c1, c2, n=18):
    stops = []
    for i in range(n):
        color = c1 if i % 2 == 0 else c2
        stops += [(round(i / n, 4), color), (round((i + 1) / n, 4), color)]
    return stops


def stars(points, color="#ffffff"):
    return "".join(sparkle(x, y, s, color, o) for x, y, s, o in points)


def crown(x, y, gold_id="metal"):
    path = (f"M{x - 30} {y + 20} L{x - 34} {y - 4} L{x - 17} {y + 7} L{x} {y - 14} "
            f"L{x + 17} {y + 7} L{x + 34} {y - 4} L{x + 30} {y + 20} Z")
    return (f'<path d="{path}" fill="url(#{gold_id})" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round"/>'
            + "".join(f'<circle cx="{cx}" cy="{cy}" r="3.6" fill="#ffffff"/>'
                      for cx, cy in ((x - 34, y - 4), (x, y - 14), (x + 34, y - 4))))


def leaf(x, y, angle, color="#5bd17a"):
    return (f'<g transform="translate({x} {y}) rotate({angle})">'
            f'<path d="M0 0 Q9 -13 22 -4 Q10 6 0 0 Z" fill="{color}" stroke="#1f5a2e" stroke-width="1.5"/>'
            f'<path d="M2 -1 Q11 -5 19 -4" fill="none" stroke="#1f5a2e" stroke-width="1.2" opacity="0.7"/></g>')


def wave_crest(x, y, color="#e0fbff"):
    return (f'<path d="M{x - 30} {y + 4} q7.5 -12 15 0 q7.5 12 15 0 q7.5 -12 15 0 q7.5 12 15 0" '
            f'fill="none" stroke="{color}" stroke-width="3.5" stroke-linecap="round"/>')


# Пиксельная рамка: квадратное кольцо со ступенчатыми углами
def pixel_ring():
    def stepped(a, step):
        b = 256 - a
        return (f"M{a + 2 * step} {a} H{b - 2 * step} V{a + step} H{b - step} V{a + 2 * step} H{b} "
                f"V{b - 2 * step} H{b - step} V{b - step} H{b - 2 * step} V{b} H{a + 2 * step} V{b - step} "
                f"H{a + step} V{b - 2 * step} H{a} V{a + 2 * step} H{a + step} V{a + step} H{a + 2 * step} Z")
    return stepped(5, 10) + " " + stepped(20, 7), stepped(5.8, 10), stepped(19.4, 7)


FRAMES = {}

# 1 Бронза — обычная: тёплый металл и заклёпки
FRAMES[1] = build([(0, "#ffd9b0"), (0.35, "#d08a4f"), (0.65, "#8c4f22"), (1, "#e7a46c")], rivets="#ffe1c2")

# 2 Серебро — необычная: камни по углам
FRAMES[2] = build([(0, "#ffffff"), (0.35, "#c5cddc"), (0.65, "#7d8799"), (1, "#eef2f8")],
                  corner_gem="#4f8dff", rivets="#ffffff")

# 3 Золото — эпическая: гербы сверху и снизу, рубины по бокам
FRAMES[3] = build([(0, "#fff6c4"), (0.35, "#f6c03a"), (0.65, "#b67a0c"), (1, "#ffe27e")],
                  corner_gem="#ff3b5c", side_gem="#ff3b5c",
                  top=("#7a4a06", "#ff3b5c", "#ffe27e"), bottom=("#7a4a06", "#ff3b5c", "#ffe27e"),
                  extra_front=f'<path d="{rounded(OUTER + 4.5, OUTER_R - 4.5)}" fill="none" stroke="#fff6c4" stroke-width="1.2" opacity="0.8"/>')

# 4 Туманность — легендарная: космический градиент, свечение, звёзды
FRAMES[4] = build([(0, "#5ad1ff"), (0.5, "#9d5cff"), (1, "#ff5fd2")], glow_color="#9ff3ff",
                  corner_gem="#7fffe0", top=("#1a1040", "#ffffff", "#9ff3ff"),
                  extra_front=stars([(64, 12, 5, 1), (192, 12, 5, 1), (12, 70, 4, 0.9), (244, 186, 4, 0.9), (70, 244, 4, 0.9), (190, 244, 5, 1)]))

# 5 Изумруд — необычная
FRAMES[5] = build([(0, "#c9ffe0"), (0.4, "#2ecc71"), (0.65, "#0e7a43"), (1, "#8affc1")], corner_gem="#00e676", rivets="#d9ffe9")

# 6 Рубин — редкая: камни и герб сверху
FRAMES[6] = build([(0, "#ffd6dc"), (0.4, "#e8364f"), (0.65, "#8a0f24"), (1, "#ff8a9c")],
                  corner_gem="#ff1744", top=("#5c0a19", "#ff1744", "#ffb3c0"))

# 7 Сапфир — редкая
FRAMES[7] = build([(0, "#d6e8ff"), (0.4, "#3a7bff"), (0.65, "#123a9c"), (1, "#8fb8ff")],
                  corner_gem="#2979ff", top=("#0b2466", "#2979ff", "#b3d1ff"))

# 8 Аметист — эпическая: гербы и камни по бокам
FRAMES[8] = build([(0, "#f3e2ff"), (0.4, "#a46bff"), (0.65, "#4a1d8a"), (1, "#d6b3ff")],
                  corner_gem="#b388ff", side_gem="#e040fb",
                  top=("#2e0f5c", "#e040fb", "#e3c9ff"), bottom=("#2e0f5c", "#b388ff", "#e3c9ff"))

# 9 Обсидиан — эпическая: чёрное стекло с раскалёнными прожилками
FRAMES[9] = build([(0, "#7c8099"), (0.3, "#2a2d3e"), (0.6, "#0b0c14"), (1, "#4a4f66")], glow_color="#ff6a00", glow_strength=0.8,
                  corner_gem="#ff6a00", top=("#0b0c14", "#ff8a2b", "#ff8a2b"), bottom=("#0b0c14", "#ff8a2b", "#ff8a2b"),
                  extra_front=('<path d="M30 9 l10 6 l8 -3 l9 5" fill="none" stroke="#ff8a2b" stroke-width="1.6" opacity="0.85"/>'
                               '<path d="M247 70 l-5 10 l3 9 l-4 8" fill="none" stroke="#ff8a2b" stroke-width="1.6" opacity="0.85"/>'
                               '<path d="M200 247 l-9 -5 l-8 3 l-10 -4" fill="none" stroke="#ff8a2b" stroke-width="1.6" opacity="0.85"/>'
                               '<path d="M9 180 l5 -9 l-3 -8 l5 -9" fill="none" stroke="#ff8a2b" stroke-width="1.6" opacity="0.85"/>'))

# 10 Радуга — легендарная: все цвета блоков, белое свечение
FRAMES[10] = build([(0, "#ff4d5e"), (0.2, "#ff8a2b"), (0.4, "#ffd23f"), (0.6, "#33c770"), (0.8, "#4170ff"), (1, "#9d5cff")],
                   glow_color="#ffffff", glow_strength=0.9, corner_gem="#ffffff", side_gem="#ffffff",
                   top=("#1a1040", "#ffd23f", "#ffffff"),
                   extra_front=stars([(70, 12, 5, 1), (186, 12, 5, 1), (244, 70, 4, 0.9), (12, 186, 4, 0.9)]))

# 11 Алмаз — мифическая: ледяной блеск, свечение, корона
FRAMES[11] = build([(0, "#ffffff"), (0.35, "#d8f4ff"), (0.6, "#7fd6ff"), (1, "#ffffff")],
                   glow_color="#bff0ff", glow_strength=1.2, corner_gem="#e0f7ff", side_gem="#e0f7ff",
                   bottom=("#0e3a5c", "#e0f7ff", "#ffffff"),
                   extra_front=(crown(128, 14)
                                + stars([(40, 12, 6, 1), (216, 12, 6, 1), (12, 92, 5, 1), (244, 92, 5, 1),
                                         (12, 170, 4, 0.9), (244, 170, 4, 0.9), (84, 246, 4, 0.9), (172, 246, 4, 0.9)])))

# 12 Карамель — необычная: леденцовые полосы
FRAMES[12] = build(stripes("#ff5c9a", "#fff4f8"), corner_gem="#ff7eb6", edge="#ffe3ee", shadow="#7a1c46")

# 13 Волна — редкая: морская синева, гребни волн, жемчуг
FRAMES[13] = build([(0, "#c9f8ff"), (0.4, "#3fb8e0"), (0.7, "#0b4a8a"), (1, "#7fe3ff")],
                   corner_gem="#e8fbff", top=("#073a5c", "#3fe0d0", "#bff6ff"),
                   extra_front=wave_crest(64, 10) + wave_crest(192, 10) + wave_crest(128 - 2, 244))

# 14 Дубовая — редкая: дерево и листья
FRAMES[14] = build([(0, "#e3b585"), (0.35, "#a0653a"), (0.65, "#5e371a"), (1, "#c08850")], edge="#f3d3ad", shadow="#2a1606",
                   rivets="#3a2010",
                   extra_front=(leaf(20, 30, -60) + leaf(30, 18, -20, "#7fe08f")
                                + leaf(236, 30, -120) + leaf(226, 18, -160, "#7fe08f")
                                + leaf(20, 226, 60, "#7fe08f") + leaf(236, 226, 120)
                                + '<ellipse cx="128" cy="10" rx="9" ry="10" fill="#c9893f" stroke="#3a2010" stroke-width="2"/>'
                                + '<path d="M118 6 Q128 -4 138 6 Z" fill="#6b4220" stroke="#3a2010" stroke-width="2"/>'))

# 15 Пиксельная — эпическая: неоновые ступенчатые грани
_pixel, _pixel_outer, _pixel_inner = pixel_ring()
FRAMES[15] = build([(0, "#ff4dd9"), (0.5, "#7a2be0"), (1, "#3bd6e8")], ring=_pixel, ring_outer=_pixel_outer, ring_inner=_pixel_inner,
                   glow_color="#ff4dd9", glow_strength=0.7,
                   extra_front=("".join(f'<rect x="{x}" y="{y}" width="7" height="7" fill="{c}"/>'
                                        for x, y, c in ((60, 9, "#ffffff"), (120, 9, "#4ade3b"), (186, 9, "#ffffff"),
                                                        (9, 70, "#3bd6e8"), (9, 180, "#ffffff"), (240, 70, "#ffffff"),
                                                        (240, 180, "#3bd6e8"), (66, 240, "#4ade3b"), (180, 240, "#ffffff")))
                                + "".join(f'<rect x="{x - 6}" y="{y - 6}" width="12" height="12" fill="#4ade3b" stroke="#0b0c14" stroke-width="2"/>'
                                          for x, y in ((24, 24), (232, 24), (24, 232), (232, 232)))))


def blossom(x, y, r, color="#ffb3c6", center="#ffd23f"):
    petals = "".join(f'<circle cx="{x + math.cos(a) * r * 0.62:.2f}" cy="{y + math.sin(a) * r * 0.62:.2f}" r="{r * 0.5:.2f}" fill="{color}"/>'
                     for a in [math.tau * k / 5 - math.pi / 2 for k in range(5)])
    return petals + f'<circle cx="{x}" cy="{y}" r="{r * 0.28:.2f}" fill="{center}"/>'


def hexagon(x, y, r, fill, stroke):
    points = " ".join(f"{x + r * math.cos(math.pi / 3 * k):.2f},{y + r * math.sin(math.pi / 3 * k):.2f}" for k in range(6))
    return f'<polygon points="{points}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'


def flame(x, y, h, angle, outer="#ff5a1f", inner="#ffd23f"):
    return (f'<g transform="translate({x} {y}) rotate({angle})">'
            f'<path d="M0 0 Q-{h * 0.45:.1f} -{h * 0.45:.1f} 0 -{h:.1f} Q{h * 0.45:.1f} -{h * 0.45:.1f} 0 0 Z" fill="{outer}"/>'
            f'<path d="M0 0 Q-{h * 0.22:.1f} -{h * 0.3:.1f} 0 -{h * 0.6:.1f} Q{h * 0.22:.1f} -{h * 0.3:.1f} 0 0 Z" fill="{inner}"/></g>')


GOLD_DEFS = gradient("gold", [(0, "#fff6c4"), (0.4, "#f6c03a"), (0.7, "#b67a0c"), (1, "#ffe27e")])

# 16 Сакура — необычная: розовое кольцо и цветки по углам
FRAMES[16] = build([(0, "#ffe3ee"), (0.4, "#ff9ec4"), (0.7, "#d65c92"), (1, "#ffd0e3")], edge="#fff4f8", shadow="#7a1c46",
                   extra_front="".join(blossom(x, y, 15) for x, y in CORNERS) + blossom(128, 11, 12, "#ffffff") + blossom(128, 245, 10, "#ffffff"))

# 17 Медовая — необычная: медовое золото и соты
FRAMES[17] = build([(0, "#ffe9a8"), (0.4, "#f5b52a"), (0.7, "#b8700a"), (1, "#ffd66b")], edge="#fff3c9", shadow="#5c3604",
                   extra_front="".join(hexagon(x, y, 9, "#ffc93a", "#8a5206") for x, y in SIDES + [TOP, BOTTOM] + CORNERS))

# 18 Неон — редкая: тёмное кольцо с двумя светящимися трубками
FRAMES[18] = build([(0, "#2a2140"), (0.5, "#120e22"), (1, "#2a2140")], glow_color="#ff3df0", glow_strength=0.9, edge="#ff3df0", shadow="#000000",
                   extra_front=(f'<path d="{rounded(OUTER + 3, OUTER_R - 3)}" fill="none" stroke="#ff3df0" stroke-width="3"/>'
                                f'<path d="{rounded(INNER - 3, INNER_R + 3)}" fill="none" stroke="#3df5ff" stroke-width="3"/>'
                                + "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="#ffffff"/>' for x, y in CORNERS)))

# 19 Магма — эпическая: чёрный камень с раскалёнными трещинами
_cracks = "".join(f'<path d="{d}" fill="none" stroke="#ffb03a" stroke-width="2.4" stroke-linejoin="round"/>'
                  f'<path d="{d}" fill="none" stroke="#ff5a1f" stroke-width="6" stroke-linejoin="round" opacity="0.35"/>'
                  for d in ("M40 8 l14 6 l10 -3 l16 6", "M248 60 l-6 12 l3 10 l-5 12", "M200 248 l-12 -6 l-10 3 l-14 -5",
                            "M8 190 l6 -12 l-3 -10 l6 -12", "M150 8 l10 5 l12 -2", "M248 180 l-5 10 l2 12"))
FRAMES[19] = build([(0, "#5a3a32"), (0.4, "#2a1612"), (0.7, "#120806"), (1, "#4a2a22")], glow_color="#ff5a1f", glow_strength=0.9,
                   edge="#ff8a4a", shadow="#000000", corner_gem="#ff6a00",
                   top=("#1a0806", "#ff8a2b", "#ff8a2b"), extra_front=_cracks)

# 20 Кристальная — эпическая: гранёное кольцо, камни и герб
_facets = "".join(
    f'<path d="M{128 + 123 * math.cos(a0):.1f} {128 + 123 * math.sin(a0):.1f} L{128 + 123 * math.cos(a1):.1f} {128 + 123 * math.sin(a1):.1f} '
    f'L128 128 Z" fill="#ffffff" opacity="{0.16 if k % 2 else 0.0}"/>'
    for k, (a0, a1) in enumerate((math.tau * i / 24, math.tau * (i + 1) / 24) for i in range(24)))
FRAMES[20] = build([(0, "#e8d9ff"), (0.35, "#9b6bff"), (0.65, "#3fb8e0"), (1, "#d6f6ff")], glow_color="#bfa8ff", glow_strength=0.7,
                   corner_gem="#3fd3e6", side_gem="#b388ff", top=("#2e0f5c", "#e0f7ff", "#e3c9ff"),
                   extra_defs=f'<clipPath id="ring"><path d="{RING}" fill-rule="evenodd" clip-rule="evenodd"/></clipPath>',
                   extra_front=f'<g clip-path="url(#ring)">{_facets}</g>')

# 21 Сияние — легендарная: переливы северного неба, звёзды
FRAMES[21] = build([(0, "#3dffb0"), (0.35, "#3dd6ff"), (0.7, "#8a6bff"), (1, "#ff7ad9")], glow_color="#7affd4", glow_strength=1.0,
                   corner_gem="#e8fff6", top=("#06283a", "#7affd4", "#bff6ff"),
                   extra_front=stars([(60, 12, 5, 1), (196, 12, 5, 1), (12, 76, 4, 0.9), (244, 76, 4, 0.9), (12, 180, 4, 0.8), (244, 180, 4, 0.8)]))

# 22 Огненная — эпическая (за бонусы): языки пламени по верху
FRAMES[22] = build([(0, "#ffd23f"), (0.35, "#ff8a2b"), (0.7, "#d8231f"), (1, "#ffb03a")], glow_color="#ff8a2b", glow_strength=0.9,
                   edge="#fff0b0", shadow="#5a0a04", corner_gem="#ffd23f",
                   extra_front="".join(flame(x, y, h, a) for x, y, h, a in (
                       (28, 40, 30, -40), (228, 40, 30, 40), (60, 26, 26, -8), (196, 26, 26, 8), (94, 26, 28, -4),
                       (162, 26, 28, 4), (128, 27, 30, 0), (18, 96, 22, -80), (238, 96, 22, 80))))

# 23 Королевская — легендарная: пурпур с золотой окантовкой и корона
FRAMES[23] = build([(0, "#c9a0ff"), (0.4, "#6a2bd6"), (0.7, "#2e0f6e"), (1, "#a77bff")], glow_color="#ffd23f", glow_strength=0.6,
                   edge="#ffe27e", shadow="#12052e", corner_gem="#ff3b5c", side_gem="#ffd23f",
                   bottom=("#2e0f6e", "#ff3b5c", "#ffe27e"), extra_defs=GOLD_DEFS,
                   extra_front=(f'<path d="{rounded(OUTER + 1.5, OUTER_R - 1.5)}" fill="none" stroke="url(#gold)" stroke-width="3"/>'
                                f'<path d="{rounded(INNER - 1.5, INNER_R + 1.5)}" fill="none" stroke="url(#gold)" stroke-width="3"/>'
                                + crown(128, 14, "gold")))

# 24 Галактика — мифическая: глубокий космос, звёздная россыпь, планетка с кольцом
_planet = ('<circle cx="128" cy="14" r="13" fill="#7a4dff" stroke="#ffffff" stroke-width="2"/>'
           '<circle cx="124" cy="10" r="4" fill="#ffffff" opacity="0.6"/>'
           '<ellipse cx="128" cy="15" rx="24" ry="6" fill="none" stroke="#ffd23f" stroke-width="3" transform="rotate(-12 128 15)"/>')
FRAMES[24] = build([(0, "#3a4cff"), (0.35, "#1a1060"), (0.65, "#3d0f6e"), (1, "#ff5fd2")], glow_color="#9d7bff", glow_strength=1.2,
                   corner_gem="#ffffff", side_gem="#3df5ff", bottom=("#0b0830", "#ff5fd2", "#e3c9ff"),
                   extra_front=(stars([(20, 40, 3, 0.9), (52, 10, 4, 1), (204, 10, 4, 1), (236, 40, 3, 0.9), (10, 110, 3, 0.8),
                                       (246, 110, 3, 0.8), (10, 150, 4, 1), (246, 150, 4, 1), (40, 246, 3, 0.9), (216, 246, 3, 0.9)])
                                + _planet))


def main():
    os.makedirs(FRAME_DIR, exist_ok=True)
    for frame_id, content in FRAMES.items():
        with open(os.path.join(FRAME_DIR, f"frame_{frame_id}.svg"), "w", encoding="utf-8") as f:
            f.write(content)
    print(f"Рамок: {len(FRAMES)}")


if __name__ == "__main__":
    main()
