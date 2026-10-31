#!/usr/bin/env python3
"""Генерирует аватарки и рамки в SVG для Block Puzzle.

Запуск из корня проекта:  python3 tools/make_avatars.py
Результат: assets/avatars/avatar_<id>.svg и assets/frames/frame_<id>.svg

Правила стиля (чтобы новые аватарки выглядели как один набор):
- квадрат 256×256, отрисовка 512×512 (width/height), фон — скруглённый квадрат с градиентом;
- персонаж по центру, главное — в зоне y 30..195: нижнюю часть закрывает плашка рамки с именем;
- плоские формы, 2–3 тона на деталь, мягкий блик сверху, без тонких линий тоньше 3 px.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AVATAR_DIR = os.path.join(ROOT, "assets", "avatars")
FRAME_DIR = os.path.join(ROOT, "assets", "frames")


def svg(body, defs=""):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 256 256">'
        f"<defs>{defs}</defs>{body}</svg>\n"
    )


def background(top, bottom, gid="bg"):
    defs = (
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
    )
    body = f'<rect x="0" y="0" width="256" height="256" rx="34" fill="url(#{gid})"/>'
    return defs, body


STAR_POSITIONS = [(28, 34, 2.2), (214, 28, 1.6), (232, 92, 2.4), (40, 120, 1.4), (196, 150, 1.8),
                  (24, 196, 2.0), (120, 22, 1.5), (90, 62, 1.2), (226, 210, 1.4), (66, 228, 1.6)]


def stars(opacity=0.85):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity="{opacity}"/>'
                   for x, y, r in STAR_POSITIONS)


def sparkle(x, y, s, color="#fff"):
    return (f'<path d="M{x} {y - s} L{x + s * 0.25} {y - s * 0.25} L{x + s} {y} L{x + s * 0.25} {y + s * 0.25} '
            f'L{x} {y + s} L{x - s * 0.25} {y + s * 0.25} L{x - s} {y} L{x - s * 0.25} {y - s * 0.25} Z" fill="{color}"/>')


def eyes(lx, rx, y, r=11, pupil="#1b1f3a"):
    out = ""
    for x in (lx, rx):
        out += f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 1.15}" fill="#fff"/>'
        out += f'<circle cx="{x + 2}" cy="{y + 2}" r="{r * 0.55}" fill="{pupil}"/>'
        out += f'<circle cx="{x + 4}" cy="{y - 2}" r="{r * 0.2}" fill="#fff"/>'
    return out


AVATARS = {}

# 1. Кубик — блок из игры с лицом
d, b = background("#4a78ff", "#1c2a7a")
AVATARS[1] = svg(
    b
    + '<rect x="62" y="56" width="132" height="132" rx="18" fill="#c78f12"/>'
    + '<rect x="58" y="50" width="132" height="132" rx="18" fill="#ffd23f"/>'
    + '<path d="M76 50 H172 a18 18 0 0 1 18 18 V112 H58 V68 a18 18 0 0 1 18 -18 Z" fill="#ffe27a"/>'
    + '<rect x="58" y="50" width="132" height="132" rx="18" fill="none" stroke="#fff" stroke-width="6"/>'
    + eyes(98, 150, 104, 13)
    + '<path d="M100 140 Q124 160 148 140" fill="none" stroke="#1b1f3a" stroke-width="7" stroke-linecap="round"/>'
    + '<circle cx="84" cy="134" r="8" fill="#ff8a6a" opacity="0.7"/><circle cx="164" cy="134" r="8" fill="#ff8a6a" opacity="0.7"/>',
    d,
)

# 2. Котоблок — кот с квадратной головой
d, b = background("#2fc4a2", "#0d5a58")
AVATARS[2] = svg(
    b
    + '<path d="M60 92 L66 36 L104 70 Z" fill="#ff8a2b"/><path d="M196 92 L190 36 L152 70 Z" fill="#ff8a2b"/>'
    + '<path d="M70 82 L73 52 L94 72 Z" fill="#ffc2a0"/><path d="M186 82 L183 52 L162 72 Z" fill="#ffc2a0"/>'
    + '<rect x="54" y="62" width="148" height="128" rx="30" fill="#ff8a2b"/>'
    + '<path d="M84 62 h88 a30 30 0 0 1 30 30 v4 H54 v-4 a30 30 0 0 1 30 -30 Z" fill="#ffa457"/>'
    + '<path d="M110 62 l6 18 l6 -18 Z M130 62 l6 18 l6 -18 Z" fill="#d86a14"/>'
    + '<ellipse cx="98" cy="118" rx="13" ry="15" fill="#d9ff7a"/><ellipse cx="158" cy="118" rx="13" ry="15" fill="#d9ff7a"/>'
    + '<rect x="95" y="106" width="6" height="24" rx="3" fill="#1b1f3a"/><rect x="155" y="106" width="6" height="24" rx="3" fill="#1b1f3a"/>'
    + '<path d="M120 142 h16 l-8 9 Z" fill="#ff5f8f"/>'
    + '<path d="M128 151 q-8 12 -18 4 M128 151 q8 12 18 4" fill="none" stroke="#1b1f3a" stroke-width="5" stroke-linecap="round"/>'
    + '<path d="M40 138 L82 144 M40 156 L82 152 M216 138 L174 144 M216 156 L174 152" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity="0.85"/>',
    d,
)

# 3. Робо — голова робота с визором
d, b = background("#8a5cff", "#2c1670")
AVATARS[3] = svg(
    b
    + '<rect x="124" y="22" width="8" height="30" rx="4" fill="#c9d3ea"/><circle cx="128" cy="22" r="11" fill="#ff4d5e"/>'
    + '<circle cx="124" cy="18" r="4" fill="#ffb3ba"/>'
    + '<rect x="38" y="96" width="22" height="48" rx="8" fill="#8d9ab8"/><rect x="196" y="96" width="22" height="48" rx="8" fill="#8d9ab8"/>'
    + '<rect x="56" y="50" width="144" height="140" rx="28" fill="#c9d3ea"/>'
    + '<rect x="56" y="50" width="144" height="60" rx="28" fill="#e2e8f5"/>'
    + '<rect x="72" y="82" width="112" height="56" rx="18" fill="#141a3a"/>'
    + '<rect x="88" y="98" width="28" height="22" rx="7" fill="#2fd3e6"/><rect x="140" y="98" width="28" height="22" rx="7" fill="#2fd3e6"/>'
    + '<rect x="92" y="101" width="10" height="6" rx="3" fill="#c9f8ff"/><rect x="144" y="101" width="10" height="6" rx="3" fill="#c9f8ff"/>'
    + '<rect x="96" y="154" width="64" height="18" rx="6" fill="#8d9ab8"/>'
    + '<path d="M108 154 v18 M120 154 v18 M132 154 v18 M144 154 v18" stroke="#5c6886" stroke-width="4"/>'
    + '<circle cx="72" cy="66" r="5" fill="#8d9ab8"/><circle cx="184" cy="66" r="5" fill="#8d9ab8"/>',
    d,
)

# 4. Лисёнок — геометрическая лиса
d, b = background("#2e7d4f", "#0f3b2a")
AVATARS[4] = svg(
    b
    + '<path d="M54 40 L104 84 L70 108 Z" fill="#ff7a1f"/><path d="M202 40 L152 84 L186 108 Z" fill="#ff7a1f"/>'
    + '<path d="M62 54 L92 82 L74 96 Z" fill="#3a1a0a"/><path d="M194 54 L164 82 L182 96 Z" fill="#3a1a0a"/>'
    + '<path d="M48 96 Q128 40 208 96 L128 196 Z" fill="#ff8a2b"/>'
    + '<path d="M48 96 Q128 40 208 96 L196 110 Q128 64 60 110 Z" fill="#ffa457"/>'
    + '<path d="M60 112 L128 196 L104 196 Q74 150 60 112 Z" fill="#fff4e6"/>'
    + '<path d="M196 112 L128 196 L152 196 Q182 150 196 112 Z" fill="#fff4e6"/>'
    + '<path d="M86 118 q12 -10 24 0 q-12 8 -24 0 Z" fill="#1b1f3a"/><path d="M146 118 q12 -10 24 0 q-12 8 -24 0 Z" fill="#1b1f3a"/>'
    + '<circle cx="100" cy="115" r="3" fill="#fff"/><circle cx="160" cy="115" r="3" fill="#fff"/>'
    + '<path d="M116 170 h24 l-12 14 Z" fill="#1b1f3a"/>',
    d,
)

# 5. Космонавт — шлем с визором, в котором отражаются звёзды
d, b = background("#1a2a6c", "#070b26")
d += ('<linearGradient id="visor" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3a7bff"/>'
      '<stop offset="1" stop-color="#140a4a"/></linearGradient>')
AVATARS[5] = svg(
    b + stars()
    + '<rect x="58" y="176" width="140" height="60" rx="26" fill="#d9e1f2"/>'
    + '<rect x="96" y="186" width="64" height="22" rx="8" fill="#ff4d5e"/>'
    + '<circle cx="128" cy="112" r="84" fill="#e9eef8"/>'
    + '<circle cx="128" cy="112" r="84" fill="none" stroke="#b8c3dc" stroke-width="8"/>'
    + '<rect x="62" y="64" width="132" height="98" rx="46" fill="url(#visor)"/>'
    + '<path d="M80 92 q14 -22 44 -24" fill="none" stroke="#fff" stroke-width="8" stroke-linecap="round" opacity="0.7"/>'
    + sparkle(160, 104, 7) + '<circle cx="146" cy="134" r="2.5" fill="#fff"/><circle cx="110" cy="140" r="2" fill="#fff"/>'
    + '<circle cx="48" cy="112" r="10" fill="#b8c3dc"/><circle cx="208" cy="112" r="10" fill="#b8c3dc"/>',
    d,
)

# 6. Ракета — взлетает по диагонали
d, b = background("#3b1c7a", "#100630")
AVATARS[6] = svg(
    b + stars()
    + '<g transform="rotate(35 128 120)">'
    + '<path d="M112 176 Q128 236 144 176 Z" fill="#ff8a2b"/><path d="M118 176 Q128 214 138 176 Z" fill="#ffd23f"/>'
    + '<path d="M98 132 L74 178 L104 170 Z" fill="#ff4d5e"/><path d="M158 132 L182 178 L152 170 Z" fill="#ff4d5e"/>'
    + '<path d="M128 26 Q170 70 160 176 H96 Q86 70 128 26 Z" fill="#eef2fb"/>'
    + '<path d="M128 26 Q170 70 160 176 H140 Q148 80 128 26 Z" fill="#c6cfe2"/>'
    + '<path d="M128 26 Q148 44 156 66 H100 Q108 44 128 26 Z" fill="#ff4d5e"/>'
    + '<circle cx="128" cy="104" r="20" fill="#5b7cff" stroke="#8d9ab8" stroke-width="6"/>'
    + '<path d="M118 98 q6 -8 14 -6" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/>'
    + '<rect x="122" y="150" width="12" height="26" rx="5" fill="#ff4d5e"/>'
    + '</g>',
    d,
)

# 7. Планета с кольцами
d, b = background("#123a7a", "#06112e")
d += ('<linearGradient id="planet" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffb36b"/>'
      '<stop offset="1" stop-color="#c2366b"/></linearGradient>')
AVATARS[7] = svg(
    b + stars()
    + '<ellipse cx="128" cy="116" rx="110" ry="30" fill="none" stroke="#ffe3a3" stroke-width="10" opacity="0.55" transform="rotate(-18 128 116)"/>'
    + '<circle cx="128" cy="116" r="64" fill="url(#planet)"/>'
    + '<path d="M70 96 Q128 80 186 104 L188 116 Q128 92 68 110 Z" fill="#fff" opacity="0.18"/>'
    + '<path d="M66 132 Q128 120 190 140 L186 152 Q128 132 72 146 Z" fill="#7a1f4e" opacity="0.35"/>'
    + '<circle cx="104" cy="92" r="14" fill="#fff" opacity="0.25"/>'
    + '<path d="M18 152 A110 30 -18 0 0 238 80" fill="none" stroke="#ffe3a3" stroke-width="10" transform="rotate(0)"/>',
    d,
)

# 8. Пришелец
d, b = background("#0f6d6a", "#05262f")
AVATARS[8] = svg(
    b + stars(0.6)
    + '<path d="M90 50 L78 26" stroke="#7dff8a" stroke-width="6" stroke-linecap="round"/><circle cx="76" cy="22" r="8" fill="#ffd23f"/>'
    + '<path d="M166 50 L178 26" stroke="#7dff8a" stroke-width="6" stroke-linecap="round"/><circle cx="180" cy="22" r="8" fill="#ffd23f"/>'
    + '<path d="M128 40 C196 40 214 96 196 136 C180 172 152 196 128 196 C104 196 76 172 60 136 C42 96 60 40 128 40 Z" fill="#7dff8a"/>'
    + '<path d="M128 40 C196 40 214 96 196 136 C190 120 170 64 128 60 C86 64 66 120 60 136 C42 96 60 40 128 40 Z" fill="#a6ffb0"/>'
    + '<path d="M76 108 Q96 88 120 108 Q104 136 76 108 Z" fill="#101528"/>'
    + '<path d="M180 108 Q160 88 136 108 Q152 136 180 108 Z" fill="#101528"/>'
    + '<ellipse cx="94" cy="104" rx="6" ry="4" fill="#fff"/><ellipse cx="158" cy="104" rx="6" ry="4" fill="#fff"/>'
    + '<path d="M114 160 Q128 168 142 160" fill="none" stroke="#2a6b3a" stroke-width="5" stroke-linecap="round"/>',
    d,
)

# 9. НЛО с лучом
d, b = background("#4a1d7a", "#120626")
d += ('<linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ff3ff" stop-opacity="0.75"/>'
      '<stop offset="1" stop-color="#9ff3ff" stop-opacity="0"/></linearGradient>')
AVATARS[9] = svg(
    b + stars()
    + '<path d="M100 120 L60 236 H196 L156 120 Z" fill="url(#beam)"/>'
    + '<ellipse cx="128" cy="88" rx="44" ry="40" fill="#7fe3ff" opacity="0.9"/>'
    + '<ellipse cx="114" cy="74" rx="12" ry="8" fill="#fff" opacity="0.7"/>'
    + '<ellipse cx="128" cy="112" rx="100" ry="30" fill="#aab4cc"/>'
    + '<ellipse cx="128" cy="104" rx="100" ry="22" fill="#d9e1f2"/>'
    + "".join(f'<circle cx="{x}" cy="114" r="7" fill="#ffd23f"/>' for x in (64, 96, 128, 160, 192))
    + '<ellipse cx="128" cy="130" rx="40" ry="8" fill="#6b7591"/>',
    d,
)

# 10. Чёрная дыра
d, b = background("#140a2a", "#000000")
d += ('<radialGradient id="disk" cx="0.5" cy="0.5" r="0.5"><stop offset="0.35" stop-color="#ffcf6b"/>'
      '<stop offset="0.65" stop-color="#ff5a3c"/><stop offset="1" stop-color="#5a1a8a" stop-opacity="0"/></radialGradient>')
AVATARS[10] = svg(
    b + stars(0.5)
    + '<ellipse cx="128" cy="116" rx="120" ry="46" fill="url(#disk)" transform="rotate(-12 128 116)"/>'
    + '<circle cx="128" cy="116" r="52" fill="#ffcf6b" opacity="0.35"/>'
    + '<circle cx="128" cy="116" r="44" fill="#000"/>'
    + '<circle cx="128" cy="116" r="44" fill="none" stroke="#ffe9b0" stroke-width="3" opacity="0.9"/>'
    + '<path d="M28 132 Q128 170 228 100" fill="none" stroke="#ffcf6b" stroke-width="8" opacity="0.85" stroke-linecap="round"/>'
    + '<path d="M40 136 Q128 160 216 108" fill="none" stroke="#fff3cf" stroke-width="3" opacity="0.8" stroke-linecap="round"/>',
    d,
)

# 11. Луна — сонная
d, b = background("#1b2558", "#070b22")
AVATARS[11] = svg(
    b + stars()
    + '<circle cx="128" cy="118" r="80" fill="#e9e2c9"/>'
    + '<path d="M128 38 A80 80 0 0 1 128 198 A64 80 0 0 0 128 38 Z" fill="#cfc6a6"/>'
    + '<circle cx="86" cy="80" r="14" fill="#d4ccad"/><circle cx="170" cy="150" r="18" fill="#c3b994"/>'
    + '<circle cx="160" cy="76" r="8" fill="#d4ccad"/><circle cx="92" cy="160" r="9" fill="#d4ccad"/>'
    + '<path d="M92 118 q12 10 24 0 M140 118 q12 10 24 0" fill="none" stroke="#4a4466" stroke-width="6" stroke-linecap="round"/>'
    + '<path d="M114 146 q14 10 28 0" fill="none" stroke="#4a4466" stroke-width="6" stroke-linecap="round"/>'
    + '<circle cx="90" cy="138" r="8" fill="#ffb3a0" opacity="0.6"/><circle cx="166" cy="138" r="8" fill="#ffb3a0" opacity="0.6"/>'
    + '<text x="186" y="64" font-family="sans-serif" font-size="26" font-weight="bold" fill="#fff" opacity="0.8">z</text>'
    + '<text x="204" y="44" font-family="sans-serif" font-size="18" font-weight="bold" fill="#fff" opacity="0.6">z</text>',
    d,
)

# 12. Комета
d, b = background("#2a1f8a", "#0a0630")
d += ('<linearGradient id="tail" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ff3ff"/>'
      '<stop offset="1" stop-color="#9ff3ff" stop-opacity="0"/></linearGradient>'
      '<radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffffff"/>'
      '<stop offset="0.45" stop-color="#bff6ff"/><stop offset="1" stop-color="#5ad1ff" stop-opacity="0"/></radialGradient>')
AVATARS[12] = svg(
    b + stars()
    + '<path d="M176 62 L30 210 L60 220 L196 88 Z" fill="url(#tail)" opacity="0.9"/>'
    + '<path d="M172 70 L70 214 L98 222 L190 92 Z" fill="url(#tail)" opacity="0.6"/>'
    + '<path d="M164 58 L44 168 L54 180 L176 74 Z" fill="url(#tail)" opacity="0.5"/>'
    + '<circle cx="182" cy="74" r="48" fill="url(#glow)"/>'
    + '<circle cx="182" cy="74" r="20" fill="#fff"/>'
    + sparkle(60, 60, 10) + sparkle(214, 170, 7),
    d,
)


# 13. Сова
d, b = background("#3b3f8f", "#141638")
AVATARS[13] = svg(
    b + stars(0.5)
    + '<circle cx="206" cy="46" r="18" fill="#fff6c9" opacity="0.8"/>'
    + '<path d="M70 70 L80 30 L104 60 Z" fill="#6e4229"/><path d="M186 70 L176 30 L152 60 Z" fill="#6e4229"/>'
    + '<ellipse cx="128" cy="128" rx="72" ry="80" fill="#8b5a3c"/>'
    + '<ellipse cx="62" cy="140" rx="18" ry="44" fill="#6e4229"/><ellipse cx="194" cy="140" rx="18" ry="44" fill="#6e4229"/>'
    + '<ellipse cx="128" cy="160" rx="46" ry="44" fill="#e8c9a0"/>'
    + '<path d="M108 150 q6 6 12 0 M136 150 q6 6 12 0 M120 168 q6 6 12 0" fill="none" stroke="#b9895f" stroke-width="4" stroke-linecap="round"/>'
    + '<circle cx="100" cy="104" r="30" fill="#f3dcb8"/><circle cx="156" cy="104" r="30" fill="#f3dcb8"/>'
    + '<circle cx="100" cy="104" r="21" fill="#ffd23f"/><circle cx="156" cy="104" r="21" fill="#ffd23f"/>'
    + '<circle cx="102" cy="106" r="11" fill="#1b1f3a"/><circle cx="154" cy="106" r="11" fill="#1b1f3a"/>'
    + '<circle cx="106" cy="101" r="4" fill="#fff"/><circle cx="158" cy="101" r="4" fill="#fff"/>'
    + '<path d="M119 122 H137 L128 140 Z" fill="#ff8a2b"/>',
    d,
)

# 14. Пингвин в шарфе
d, b = background("#5ec8ff", "#1c5fa8")
AVATARS[14] = svg(
    b + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity="0.7"/>' for x, y, r in
                ((30, 40, 4), (220, 60, 3), (200, 30, 5), (44, 110, 3), (226, 140, 4), (30, 180, 3)))
    + '<ellipse cx="54" cy="150" rx="16" ry="40" fill="#1f2438" transform="rotate(18 54 150)"/>'
    + '<ellipse cx="202" cy="150" rx="16" ry="40" fill="#1f2438" transform="rotate(-18 202 150)"/>'
    + '<ellipse cx="128" cy="132" rx="74" ry="90" fill="#1f2438"/>'
    + '<ellipse cx="128" cy="160" rx="50" ry="60" fill="#fff"/>'
    + '<circle cx="104" cy="104" r="30" fill="#fff"/><circle cx="152" cy="104" r="30" fill="#fff"/>'
    + '<circle cx="108" cy="104" r="9" fill="#1b1f3a"/><circle cx="148" cy="104" r="9" fill="#1b1f3a"/>'
    + '<circle cx="111" cy="100" r="3" fill="#fff"/><circle cx="151" cy="100" r="3" fill="#fff"/>'
    + '<path d="M116 120 H140 L128 136 Z" fill="#ff9a3d"/>'
    + '<circle cx="90" cy="126" r="8" fill="#ffb3c0" opacity="0.8"/><circle cx="166" cy="126" r="8" fill="#ffb3c0" opacity="0.8"/>'
    + '<rect x="74" y="150" width="108" height="18" rx="9" fill="#ff4d5e"/>'
    + '<rect x="146" y="160" width="18" height="40" rx="7" fill="#ff4d5e"/>'
    + '<path d="M150 192 h10 M150 184 h10" stroke="#fff" stroke-width="3" opacity="0.6"/>',
    d,
)

# 15. Призрак
d, b = background("#5a2a9a", "#1a0a3a")
AVATARS[15] = svg(
    b + stars(0.7)
    + '<path d="M64 196 L64 110 C64 62 96 40 128 40 C160 40 192 62 192 110 L192 196 '
      'Q176 178 160 196 Q144 214 128 196 Q112 178 96 196 Q80 214 64 196 Z" fill="#f4f1ff"/>'
    + '<path d="M160 50 C182 64 192 86 192 110 L192 196 Q176 178 160 196 Z" fill="#d9d0ff" opacity="0.7"/>'
    + '<path d="M64 140 q-18 -6 -22 -26 q14 4 22 10 Z" fill="#f4f1ff"/><path d="M192 140 q18 -6 22 -26 q-14 4 -22 10 Z" fill="#d9d0ff"/>'
    + '<ellipse cx="104" cy="108" rx="11" ry="15" fill="#1b1f3a"/><ellipse cx="152" cy="108" rx="11" ry="15" fill="#1b1f3a"/>'
    + '<circle cx="107" cy="102" r="4" fill="#fff"/><circle cx="155" cy="102" r="4" fill="#fff"/>'
    + '<ellipse cx="128" cy="142" rx="9" ry="11" fill="#2a1f4a"/>'
    + '<circle cx="88" cy="130" r="8" fill="#ff9ad5" opacity="0.6"/><circle cx="168" cy="130" r="8" fill="#ff9ad5" opacity="0.6"/>',
    d,
)

# 16. Король блоков
d, b = background("#c0392b", "#4a0f2a")
d += ('<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff1a8"/>'
      '<stop offset="1" stop-color="#e0a21a"/></linearGradient>')
AVATARS[16] = svg(
    b + sparkle(40, 50, 8, "#ffe9a3") + sparkle(214, 70, 6, "#ffe9a3")
    + '<rect x="66" y="92" width="128" height="116" rx="18" fill="#5a2aa8"/>'
    + '<rect x="62" y="86" width="128" height="116" rx="18" fill="#9d5cff"/>'
    + '<path d="M80 86 H172 a18 18 0 0 1 18 18 V140 H62 V104 a18 18 0 0 1 18 -18 Z" fill="#b98aff"/>'
    + '<rect x="62" y="86" width="128" height="116" rx="18" fill="none" stroke="#fff" stroke-width="6"/>'
    + '<path d="M68 90 L78 38 L104 66 L126 26 L148 66 L174 38 L184 90 Z" fill="url(#gold)" stroke="#b07a0c" stroke-width="4" stroke-linejoin="round"/>'
    + '<circle cx="78" cy="38" r="7" fill="#ff4d5e"/><circle cx="126" cy="26" r="8" fill="#4170ff"/><circle cx="174" cy="38" r="7" fill="#33c770"/>'
    + '<rect x="70" y="76" width="112" height="14" rx="4" fill="#e0a21a"/>'
    + eyes(102, 150, 136, 11)
    + '<path d="M106 170 Q126 184 150 166" fill="none" stroke="#1b1f3a" stroke-width="7" stroke-linecap="round"/>',
    d,
)

# === РАМКИ ===
# Квадратная рамка с прозрачным центром и плашкой под имя внизу (как frame_1.png).

def frame(stops, gem, plate_fill, plate_stroke, corner, extra=""):
    gradient = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    defs = f'<linearGradient id="metal" x1="0" y1="0" x2="1" y2="1">{gradient}</linearGradient>'
    body = (
        # Внешняя полоса рамки с прозрачной серединой (evenodd)
        '<path fill-rule="evenodd" fill="url(#metal)" d="M10 10 H246 V246 H10 Z M24 24 V232 H232 V24 Z"/>'
        '<path fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="2" d="M24 24 V232 H232 V24 Z"/>'
        '<path fill="none" stroke="#fff" stroke-opacity="0.5" stroke-width="2" d="M11 11 H245 V245 H11 Z"/>'
        + extra
        # Уголки
        + "".join(f'<path d="M{x} {y} l12 -12 l12 12 l-12 12 Z" fill="{corner}" stroke="#fff" stroke-opacity="0.6" stroke-width="2"/>'
                  for x, y in ((5, 17), (227, 17), (5, 239), (227, 239)))
        # Самоцветы по бокам
        + f'<circle cx="17" cy="128" r="11" fill="{gem}" stroke="#fff" stroke-opacity="0.7" stroke-width="2"/>'
        + f'<circle cx="239" cy="128" r="11" fill="{gem}" stroke="#fff" stroke-opacity="0.7" stroke-width="2"/>'
        + '<circle cx="14" cy="124" r="3.5" fill="#fff" opacity="0.8"/><circle cx="236" cy="124" r="3.5" fill="#fff" opacity="0.8"/>'
        # Плашка под имя
        + f'<path d="M66 216 H190 L200 231 L190 246 H66 L56 231 Z" fill="{plate_fill}" stroke="{plate_stroke}" stroke-width="4"/>'
        + '<path d="M70 220 H186 L192 228 H64 Z" fill="#fff" opacity="0.18"/>'
    )
    return svg(body, defs)


FRAMES = {
    2: frame([(0, "#ffffff"), (0.45, "#b9c3d4"), (0.55, "#8a94a6"), (1, "#e6ebf3")],
             "#4f8dff", "#5b6478", "#d9e1f2", "#c9d3ea"),
    3: frame([(0, "#fff3b0"), (0.4, "#f2b82e"), (0.6, "#c78a12"), (1, "#ffe07a")],
             "#ff3b5c", "#9c3a12", "#ffd23f", "#ffd23f"),
    4: frame([(0, "#5ad1ff"), (0.5, "#9d5cff"), (1, "#ff5fd2")],
             "#7fffe0", "#1a1040", "#9ff3ff", "#9ff3ff",
             extra=(
                 # Неоновое свечение: несколько полупрозрачных обводок
                 '<path fill="none" stroke="#e8fbff" stroke-opacity="0.8" stroke-width="2.5" d="M17 17 V239 H239 V17 Z"/>'
                 '<path fill="none" stroke="#9ff3ff" stroke-opacity="0.45" stroke-width="3" d="M26 26 V230 H230 V26 Z"/>'
                 + sparkle(128, 17, 7) + sparkle(64, 17, 4) + sparkle(192, 17, 4)
             )),
}


FRAMES.update({
    5: frame([(0, "#b8ffd6"), (0.45, "#2ecc71"), (0.6, "#0e7a43"), (1, "#8affc1")],
             "#00e676", "#0b5d33", "#7dffb0", "#9dffcc"),
    6: frame([(0, "#ffd0d6"), (0.45, "#ff3b5c"), (0.6, "#a3122e"), (1, "#ff8a9c")],
             "#ff1744", "#6d0a1f", "#ff8a9c", "#ffb3c0"),
    7: frame([(0, "#cfe3ff"), (0.45, "#3a7bff"), (0.6, "#123a9c"), (1, "#8fb8ff")],
             "#2979ff", "#0d2a6e", "#8fb8ff", "#b3d1ff"),
    8: frame([(0, "#f0d9ff"), (0.45, "#9d5cff"), (0.6, "#4a1d8a"), (1, "#d1a8ff")],
             "#b388ff", "#3a1470", "#d1a8ff", "#e3c9ff"),
    9: frame([(0, "#8a8fa8"), (0.45, "#2a2d3e"), (0.6, "#0b0c14"), (1, "#5a5f78")],
             "#ff6a00", "#0b0c14", "#ff8a2b", "#5a5f78",
             extra='<path fill="none" stroke="#ff6a00" stroke-opacity="0.55" stroke-width="2" d="M17 17 V239 H239 V17 Z"/>'),
    10: frame([(0, "#ff4d5e"), (0.2, "#ff8a2b"), (0.4, "#ffd23f"), (0.6, "#33c770"), (0.8, "#4170ff"), (1, "#9d5cff")],
              "#ffffff", "#1a1040", "#ffd23f", "#ffffff"),
    11: frame([(0, "#ffffff"), (0.4, "#cdeffd"), (0.6, "#7fd6ff"), (1, "#ffffff")],
              "#e0f7ff", "#0e3a5c", "#ffffff", "#ffffff",
              extra=(sparkle(128, 17, 8) + sparkle(17, 72, 5) + sparkle(239, 72, 5)
                     + sparkle(17, 184, 5) + sparkle(239, 184, 5) + sparkle(72, 239, 4) + sparkle(184, 239, 4))),
})


def main():
    os.makedirs(AVATAR_DIR, exist_ok=True)
    os.makedirs(FRAME_DIR, exist_ok=True)
    for avatar_id, content in AVATARS.items():
        with open(os.path.join(AVATAR_DIR, f"avatar_{avatar_id}.svg"), "w", encoding="utf-8") as f:
            f.write(content)
    for frame_id, content in FRAMES.items():
        with open(os.path.join(FRAME_DIR, f"frame_{frame_id}.svg"), "w", encoding="utf-8") as f:
            f.write(content)
    print(f"Аватарок: {len(AVATARS)}, рамок: {len(FRAMES)}")


if __name__ == "__main__":
    main()
