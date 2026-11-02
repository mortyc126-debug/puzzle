class_name BlockRenderer
extends RefCounted

## Рисует поле, пустые клетки и блоки в стиле темы. Используется Grid, Block и превью тем.
## Все функции принимают CanvasItem и должны вызываться из его _draw().

const BASE_CELL = 80.0

static var _box_cache: Dictionary = {}

# Окраска с градиентом (ItemsDB.paints_data): пока рисуется блок, здесь его верхний и нижний цвет.
# Тело блока тогда — скруглённая текстура-градиент, а светлые и тёмные накладки полупрозрачны,
# чтобы градиент просвечивал. Без окраски всё рисуется как раньше.
static var _grad_on := false
static var _grad_top := Color.WHITE
static var _grad_bottom := Color.WHITE
static var _grad_cache: Dictionary = {}
static var _grad_clear_scheduled := false
# Стили, где градиент виден; у остальных (неон, магма, самоцвет…) блок берёт средний цвет
const GRADIENT_STYLES = [BlockTheme.BlockStyle.FLAT, BlockTheme.BlockStyle.BEVEL, BlockTheme.BlockStyle.GLOSSY,
	BlockTheme.BlockStyle.CANDY, BlockTheme.BlockStyle.WOOD, BlockTheme.BlockStyle.PIXEL, BlockTheme.BlockStyle.METAL,
	BlockTheme.BlockStyle.ANIME, BlockTheme.BlockStyle.KAWAII, BlockTheme.BlockStyle.JELLY, BlockTheme.BlockStyle.CUBE3D,
	BlockTheme.BlockStyle.BRICK, BlockTheme.BlockStyle.FROST, BlockTheme.BlockStyle.GLASS]

# StyleBoxFlat кэшируются: поле перерисовывается при каждом движении пальца
static func _box(fill: Color, radius: float, border: Color = Color(0, 0, 0, 0), border_width: int = 0,
		shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0, top_only: bool = false) -> StyleBoxFlat:
	var key = "%s|%d|%s|%d|%s|%d|%s" % [fill.to_html(), int(radius), border.to_html(), border_width,
		shadow.to_html(), shadow_size, top_only]
	if _box_cache.has(key):
		return _box_cache[key]

	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.anti_aliasing = true
	if top_only:
		box.corner_radius_top_left = int(radius)
		box.corner_radius_top_right = int(radius)
	else:
		box.set_corner_radius_all(int(radius))
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	if shadow_size > 0:
		box.shadow_color = shadow
		box.shadow_size = shadow_size

	if _box_cache.size() > 600:
		_box_cache.clear()
	_box_cache[key] = box
	return box

static func draw_board(canvas: CanvasItem, rect: Rect2, theme: BlockTheme) -> void:
	var padded = rect.grow(theme.board_padding)
	canvas.draw_style_box(_box(theme.board_color, theme.board_corner_radius), padded)

# Подложка под поле цвета фона темы: поле темы полупрозрачное и рассчитано на её фон, а на чужом
# (коллекция «Фоны» — например, светлый мрамор под тёмной «Классикой») клетки сливались бы с полем
static func draw_board_underlay(canvas: CanvasItem, rect: Rect2, theme: BlockTheme) -> void:
	var padded = rect.grow(theme.board_padding)
	canvas.draw_style_box(_box(Color(theme.background_color, 1.0), theme.board_corner_radius), padded)

static func draw_empty_cell(canvas: CanvasItem, rect: Rect2, theme: BlockTheme) -> void:
	var scale = rect.size.x / BASE_CELL
	var inner = rect.grow(-rect.size.x * 0.05)
	canvas.draw_style_box(_box(theme.cell_color, theme.block_corner_radius * 0.8 * scale), inner)

# grad_top/grad_bottom — градиент окраски (прозрачный — без градиента), rim — кайма окраски
static func draw_block(canvas: CanvasItem, rect: Rect2, color: Color, theme: BlockTheme, alpha: float = 1.0,
		grad_top: Color = Color(0, 0, 0, 0), grad_bottom: Color = Color(0, 0, 0, 0), rim: Color = Color(0, 0, 0, 0)) -> void:
	var size = rect.size.x
	var scale = size / BASE_CELL
	var radius = theme.block_corner_radius * scale
	var inner = rect.grow(-size * 0.04)
	var base = Color(color, color.a * alpha)
	_grad_on = grad_top.a > 0.0 and theme.block_style in GRADIENT_STYLES
	if _grad_on:
		_grad_top = grad_top
		_grad_bottom = grad_bottom
	_draw_styled(canvas, rect, inner, base, theme, radius, scale, alpha)
	_grad_on = false
	if rim.a > 0.0:
		canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(rim, rim.a * alpha), maxi(2, int(3.5 * scale))), inner)
		canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius * 0.8, Color(1, 1, 1, 0.35 * alpha), maxi(1, int(1.2 * scale))),
			inner.grow(-3.5 * scale))

static func _draw_styled(canvas: CanvasItem, rect: Rect2, inner: Rect2, base: Color, theme: BlockTheme, radius: float,
		scale: float, alpha: float) -> void:
	var size = rect.size.x

	match theme.block_style:
		BlockTheme.BlockStyle.FLAT:
			_body(canvas, inner, base, radius)

		BlockTheme.BlockStyle.BEVEL:
			var shadow_rect = Rect2(inner.position + Vector2(2, 2) * scale, inner.size)
			canvas.draw_style_box(_box(Color(base.darkened(0.3), base.a), radius), shadow_rect)
			_body(canvas, inner, base, radius)
			var top = Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5))
			canvas.draw_style_box(_box(_lighter(base, 0.2), radius, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), top)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(1, 1, 1, 0.9 * alpha),
				maxi(2, int(3 * scale))), inner)

		BlockTheme.BlockStyle.GLOSSY:
			_body(canvas, inner, base, radius)
			var low = Rect2(inner.position + Vector2(0, inner.size.y * 0.55), Vector2(inner.size.x, inner.size.y * 0.45))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0.22 * alpha), radius), low)
			var shine = Rect2(inner.position + Vector2(size * 0.1, size * 0.08), Vector2(inner.size.x - size * 0.2, size * 0.28))
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.3 * alpha), radius * 0.7), shine)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.35), 0.8 * alpha),
				maxi(1, int(2 * scale))), inner)

		BlockTheme.BlockStyle.GLOW:
			var glow = Color(base, 0.55 * theme.glow_strength * alpha)
			var core = Color(base.darkened(0.6), 0.92 * alpha)
			canvas.draw_style_box(_box(core, radius, base, maxi(2, int(4 * scale)), glow, int(14 * scale)), inner)
			var center = inner.get_center()
			canvas.draw_circle(center, size * 0.16, Color(base, 0.35 * alpha))
			canvas.draw_circle(center, size * 0.07, Color(base.lightened(0.6), 0.9 * alpha))
			var spark = Rect2(inner.position + Vector2(size * 0.14, size * 0.12), Vector2(size * 0.22, size * 0.07))
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.45 * alpha), size * 0.035), spark)

		BlockTheme.BlockStyle.TEXTURE:
			if theme.block_texture:
				canvas.draw_texture_rect(theme.block_texture, inner, false, base)
			else:
				canvas.draw_style_box(_box(base, radius), inner)

		BlockTheme.BlockStyle.CANDY:
			var depth = Rect2(inner.position + Vector2(0, size * 0.05), inner.size)
			canvas.draw_style_box(_box(Color(base.darkened(0.25), base.a), radius), depth)
			_body(canvas, inner, base, radius)
			canvas.draw_style_box(_box(_lighter(base, 0.2), radius * 0.8), inner.grow(-size * 0.11))
			var shine = Rect2(inner.position + Vector2(size * 0.15, size * 0.12), Vector2(size * 0.32, size * 0.13))
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.6 * alpha), size * 0.065), shine)
			canvas.draw_circle(inner.position + Vector2(size * 0.62, size * 0.19), size * 0.045, Color(1, 1, 1, 0.65 * alpha))

		BlockTheme.BlockStyle.GLASS:
			_body(canvas, inner, Color(base, 0.65 * alpha), radius)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.55), 0.95 * alpha),
				maxi(2, int(3 * scale))), inner)
			var p = inner.position
			var s = inner.size.x
			var streak = PackedVector2Array([p + Vector2(s * 0.2, s * 0.1), p + Vector2(s * 0.44, s * 0.1),
				p + Vector2(s * 0.12, s * 0.62), p + Vector2(s * 0.1, s * 0.42)])
			canvas.draw_colored_polygon(streak, Color(1, 1, 1, 0.32 * alpha))
			canvas.draw_arc(p + Vector2(s * 0.72, s * 0.7), s * 0.09, 0.0, TAU, 16, Color(1, 1, 1, 0.6 * alpha), maxf(1.0, 2.0 * scale))
			canvas.draw_circle(p + Vector2(s * 0.69, s * 0.67), s * 0.025, Color(1, 1, 1, 0.8 * alpha))

		BlockTheme.BlockStyle.WOOD:
			var edge = Rect2(inner.position + Vector2(0, size * 0.04), inner.size)
			canvas.draw_style_box(_box(Color(base.darkened(0.4), base.a), radius), edge)
			_body(canvas, inner, base, radius)
			# Рисунок волокон зависит от положения клетки — у соседних блоков он разный
			var grain_seed = int(rect.position.x / maxf(size, 1.0)) * 7 + int(rect.position.y / maxf(size, 1.0)) * 13
			var grain = Color(base.darkened(0.28), 0.6 * alpha)
			for i in range(3):
				var y = inner.position.y + inner.size.y * (0.25 + 0.25 * i) + (posmod(grain_seed + i * 5, 7) - 3) * scale
				var points = PackedVector2Array()
				for k in range(6):
					var x = inner.position.x + inner.size.x * (0.08 + 0.168 * k)
					points.append(Vector2(x, y + sin(k * 1.3 + grain_seed + i) * 2.5 * scale))
				canvas.draw_polyline(points, grain, maxf(1.0, 2.0 * scale), true)
			if posmod(grain_seed, 5) == 0:
				canvas.draw_circle(inner.position + inner.size * Vector2(0.68, 0.42), size * 0.07, Color(base.darkened(0.35), 0.7 * alpha))
				canvas.draw_circle(inner.position + inner.size * Vector2(0.68, 0.42), size * 0.03, Color(base.darkened(0.5), 0.8 * alpha))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.3), 0.7 * alpha),
				maxi(1, int(2 * scale))), inner)

		BlockTheme.BlockStyle.PIXEL:
			var px = maxf(2.0, round(size * 0.1))
			var outline = rect.grow(-size * 0.03)
			canvas.draw_rect(outline, Color(base.darkened(0.6), base.a))
			var body = outline.grow(-px * 0.6)
			_body(canvas, body, base, 0.0)
			var light = Color(base.lightened(0.45), base.a)
			var dark = Color(base.darkened(0.35), base.a)
			canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, px)), light)
			canvas.draw_rect(Rect2(body.position, Vector2(px, body.size.y)), light)
			canvas.draw_rect(Rect2(body.position + Vector2(0, body.size.y - px), Vector2(body.size.x, px)), dark)
			canvas.draw_rect(Rect2(body.position + Vector2(body.size.x - px, 0), Vector2(px, body.size.y)), dark)
			canvas.draw_rect(Rect2(body.position + Vector2(px * 1.5, px * 1.5), Vector2(px, px)), Color(1, 1, 1, 0.85 * alpha))

		BlockTheme.BlockStyle.MAGMA:
			# Раскалённая лава внутри, сверху — тёмная каменная корка из четырёх плит;
			# сквозь щели между плитами светится цвет блока
			var glow = Color(base, 0.5 * theme.glow_strength * alpha)
			canvas.draw_style_box(_box(Color(base.lightened(0.15), alpha), radius, Color(0, 0, 0, 0), 0, glow, int(8 * scale)), inner)
			var p = inner.position
			var s = inner.size.x
			var crack_seed = int(rect.position.x / maxf(size, 1.0)) * 5 + int(rect.position.y / maxf(size, 1.0)) * 11
			var jitter = func(k: int) -> float: return (posmod(crack_seed * 7 + k * 13, 11) - 5) * 0.018
			var cx = s * (0.5 + jitter.call(1))
			var cy = s * (0.5 + jitter.call(2))
			var top_x = s * (0.45 + jitter.call(3))
			var bottom_x = s * (0.55 + jitter.call(4))
			var left_y = s * (0.52 + jitter.call(5))
			var right_y = s * (0.46 + jitter.call(6))
			var gap = s * 0.035
			var rock = Color(0.17, 0.09, 0.08, alpha).lerp(Color(base.darkened(0.75), alpha), 0.25)
			var plates = [
				[Vector2(gap, gap), Vector2(top_x - gap, gap), Vector2(cx - gap, cy - gap), Vector2(gap, left_y - gap)],
				[Vector2(top_x + gap, gap), Vector2(s - gap, gap), Vector2(s - gap, right_y - gap), Vector2(cx + gap, cy - gap)],
				[Vector2(cx + gap, cy + gap), Vector2(s - gap, right_y + gap), Vector2(s - gap, s - gap), Vector2(bottom_x + gap, s - gap)],
				[Vector2(gap, left_y + gap), Vector2(cx - gap, cy + gap), Vector2(bottom_x - gap, s - gap), Vector2(gap, s - gap)],
			]
			for plate in plates:
				var points = PackedVector2Array()
				for corner in plate:
					points.append(p + corner)
				canvas.draw_colored_polygon(points, rock)
				canvas.draw_line(points[0], points[1], Color(1, 1, 1, 0.12 * alpha), maxf(1.0, 1.5 * scale))
			canvas.draw_circle(p + Vector2(cx, cy), s * 0.06, Color(base.lightened(0.55), 0.95 * alpha))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.darkened(0.2), 0.9 * alpha), maxi(1, int(2 * scale))), inner)

		BlockTheme.BlockStyle.GEM:
			var p = inner.position
			var s = inner.size.x
			var t0 = s * 0.27
			var t1 = s * 0.73
			var a = p
			var b = p + Vector2(s, 0)
			var c = p + Vector2(s, s)
			var d = p + Vector2(0, s)
			var ta = p + Vector2(t0, t0)
			var tb = p + Vector2(t1, t0)
			var tc = p + Vector2(t1, t1)
			var td = p + Vector2(t0, t1)
			canvas.draw_colored_polygon(PackedVector2Array([a, b, tb, ta]), Color(base.lightened(0.4), alpha))
			canvas.draw_colored_polygon(PackedVector2Array([a, ta, td, d]), Color(base.lightened(0.15), alpha))
			canvas.draw_colored_polygon(PackedVector2Array([b, c, tc, tb]), Color(base.darkened(0.2), alpha))
			canvas.draw_colored_polygon(PackedVector2Array([d, td, tc, c]), Color(base.darkened(0.4), alpha))
			canvas.draw_colored_polygon(PackedVector2Array([ta, tb, tc, td]), Color(base.lightened(0.08), alpha))
			var edge = Color(1, 1, 1, 0.35 * alpha)
			canvas.draw_polyline(PackedVector2Array([a, b, c, d, a]), Color(base.darkened(0.5), 0.8 * alpha), maxf(1.0, 2.0 * scale))
			canvas.draw_polyline(PackedVector2Array([ta, tb, tc, td, ta]), edge, maxf(1.0, 1.5 * scale))
			for corner in [[a, ta], [b, tb], [c, tc], [d, td]]:
				canvas.draw_line(corner[0], corner[1], edge, maxf(1.0, 1.2 * scale))
			# Искра на площадке
			var spark = p + Vector2(s * 0.38, s * 0.38)
			var arm = s * 0.11
			canvas.draw_colored_polygon(PackedVector2Array([spark + Vector2(0, -arm), spark + Vector2(arm * 0.28, 0),
				spark + Vector2(0, arm), spark + Vector2(-arm * 0.28, 0)]), Color(1, 1, 1, 0.85 * alpha))
			canvas.draw_colored_polygon(PackedVector2Array([spark + Vector2(-arm, 0), spark + Vector2(0, arm * 0.28),
				spark + Vector2(arm, 0), spark + Vector2(0, -arm * 0.28)]), Color(1, 1, 1, 0.85 * alpha))

		BlockTheme.BlockStyle.METAL:
			var p = inner.position
			var s = inner.size.x
			canvas.draw_style_box(_box(Color(base.darkened(0.45), base.a), radius), Rect2(p + Vector2(0, s * 0.04), inner.size))
			_body(canvas, inner, Color(base.darkened(0.12), base.a), radius)
			var top = Rect2(p, Vector2(s, s * 0.48))
			canvas.draw_style_box(_box(_lighter(base, 0.28), radius, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), top)
			canvas.draw_rect(Rect2(p + Vector2(s * 0.06, s * 0.4), Vector2(s * 0.88, s * 0.08)), Color(1, 1, 1, 0.55 * alpha))
			canvas.draw_rect(Rect2(p + Vector2(s * 0.06, s * 0.48), Vector2(s * 0.88, s * 0.04)), Color(base.darkened(0.3), 0.6 * alpha))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.55), 0.85 * alpha),
				maxi(1, int(2 * scale))), inner)
			canvas.draw_circle(p + Vector2(s * 0.24, s * 0.2), s * 0.05, Color(1, 1, 1, 0.9 * alpha))

		_:
			_draw_skin(canvas, inner, base, theme, radius, scale, alpha)

# === КУБИКИ (ItemsDB.skins_data) ===
# Детали рисуются от размера клетки: одинаково на поле, в лотке и в превью профиля.
# Ничего случайного — иначе при перетаскивании узор «прыгал» бы.
static func _draw_skin(canvas: CanvasItem, inner: Rect2, base: Color, theme: BlockTheme, radius: float,
		scale: float, alpha: float) -> void:
	var p = inner.position
	var s = inner.size.x
	var x0 = p.x
	var y0 = p.y
	var x1 = p.x + s
	var y1 = p.y + s
	match theme.block_style:
		BlockTheme.BlockStyle.NEON:
			# Яркая трубка: насыщенный цвет, широкое свечение, белая сердцевина и лёгкая подсветка внутри
			var neon = Color.from_hsv(base.h, minf(base.s * 1.1, 1.0), 1.0, base.a)
			var glow = Color(neon, 0.6 * theme.glow_strength * alpha)
			canvas.draw_style_box(_box(Color(neon.darkened(0.8), 0.55 * alpha), radius, Color(0, 0, 0, 0), 0, glow,
				int(20 * scale)), inner)
			canvas.draw_style_box(_box(Color(neon, 0.16 * alpha), radius * 0.8), inner.grow(-s * 0.14))
			var tube = inner.grow(-s * 0.07)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius * 0.85, Color(neon, alpha), maxi(3, int(6 * scale))), tube)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius * 0.75, Color(neon.lightened(0.8), alpha),
				maxi(1, int(2.2 * scale))), tube.grow(-2.0 * scale))

		BlockTheme.BlockStyle.CYBER:
			var c = s * 0.18
			var poly = PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1, y0), Vector2(x1, y1 - c), Vector2(x1 - c, y1),
				Vector2(x0, y1), Vector2(x0, y0 + c)])
			canvas.draw_colored_polygon(poly, Color(base.darkened(0.72), 0.95 * alpha))
			var m = s * 0.12
			var panel = PackedVector2Array([Vector2(x0 + c, y0 + m), Vector2(x1 - m, y0 + m), Vector2(x1 - m, y1 - c),
				Vector2(x1 - c, y1 - m), Vector2(x0 + m, y1 - m), Vector2(x0 + m, y0 + c)])
			canvas.draw_colored_polygon(panel, Color(base.darkened(0.45), 0.95 * alpha))
			var edge = poly.duplicate()
			edge.append(poly[0])
			canvas.draw_polyline(edge, Color(base.lightened(0.2), alpha), maxf(1.5, 2.5 * scale), true)
			# Вторая неоновая кромка — дополнительного цвета, как вывески ночного города
			var accent = Color.from_hsv(fposmod(base.h + 0.5, 1.0), 0.75, 1.0, alpha)
			canvas.draw_line(Vector2(x0 + c + s * 0.06, y0 + s * 0.05), Vector2(x1 - s * 0.08, y0 + s * 0.05), accent,
				maxf(1.0, 2.0 * scale))
			var trace = y1 - s * 0.3
			canvas.draw_line(Vector2(x0 + s * 0.2, trace), Vector2(x0 + s * 0.45, trace), Color(base.lightened(0.5), 0.8 * alpha),
				maxf(1.0, 1.6 * scale))
			canvas.draw_line(Vector2(x0 + s * 0.45, trace), Vector2(x0 + s * 0.55, trace - s * 0.1), Color(base.lightened(0.5), 0.8 * alpha),
				maxf(1.0, 1.6 * scale))
			canvas.draw_circle(Vector2(x0 + s * 0.55, trace - s * 0.1), s * 0.04, Color(base.lightened(0.7), alpha))

		BlockTheme.BlockStyle.ANIME:
			var line = maxi(2, int(3.5 * scale))
			_body(canvas, inner, base, radius)
			var b = line + radius * 0.3
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0 + b, y1 - b - s * 0.26), Vector2(x1 - b, y1 - b - s * 0.5),
				Vector2(x1 - b, y1 - b), Vector2(x0 + b, y1 - b)]), _darker(Color(base, alpha), 0.2))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.darkened(0.6), alpha), line), inner)
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.85 * alpha), s * 0.05),
				Rect2(p + Vector2(s * 0.17, s * 0.15), Vector2(s * 0.3, s * 0.09)))
			_spark(canvas, p + Vector2(s * 0.72, s * 0.26), s * 0.1, Color(1, 1, 1, 0.9 * alpha))

		BlockTheme.BlockStyle.KAWAII:
			var depth = Rect2(p + Vector2(0, s * 0.05), inner.size)
			canvas.draw_style_box(_box(Color(base.darkened(0.22), base.a), radius * 1.4), depth)
			_body(canvas, inner, base, radius * 1.4)
			canvas.draw_style_box(_box(_lighter(base, 0.18), radius * 1.2,
				Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, true), Rect2(p, Vector2(s, s * 0.46)))
			var ink = Color(base.darkened(0.75), alpha)
			for eye_x in [0.33, 0.67]:
				canvas.draw_circle(p + Vector2(s * eye_x, s * 0.46), s * 0.065, ink)
				canvas.draw_circle(p + Vector2(s * (eye_x + 0.02), s * 0.43), s * 0.022, Color(1, 1, 1, alpha))
			canvas.draw_arc(p + Vector2(s * 0.5, s * 0.55), s * 0.09, deg_to_rad(20), deg_to_rad(160), 10, ink,
				maxf(1.5, 2.6 * scale), true)
			for cheek_x in [0.2, 0.8]:
				canvas.draw_circle(p + Vector2(s * cheek_x, s * 0.6), s * 0.06, Color(1, 0.45, 0.55, 0.45 * alpha))

		BlockTheme.BlockStyle.HOLO:
			canvas.draw_style_box(_box(Color(base, 0.3 * alpha), radius), inner)
			canvas.draw_style_box(_box(Color(0.35, 1, 1, 0.16 * alpha), radius, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), Rect2(p, Vector2(s, s * 0.5)))
			canvas.draw_rect(Rect2(p + Vector2(0, s * 0.62), Vector2(s, s * 0.3)), Color(1, 0.4, 1, 0.12 * alpha))
			for i in range(5):
				var y = y0 + (i + 0.5) * s / 5.0
				canvas.draw_line(Vector2(x0 + s * 0.06, y), Vector2(x1 - s * 0.06, y), Color(1, 1, 1, 0.2 * alpha), maxf(1.0, scale))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.55), 0.95 * alpha),
				maxi(1, int(2 * scale)), Color(base, 0.35 * alpha), int(8 * scale)), inner)
			canvas.draw_circle(p + Vector2(s * 0.82, s * 0.18), s * 0.04, Color(1, 1, 1, 0.9 * alpha))

		BlockTheme.BlockStyle.JELLY:
			canvas.draw_style_box(_box(Color(base.darkened(0.3), 0.8 * alpha), radius * 1.3), Rect2(p + Vector2(0, s * 0.05), inner.size))
			_body(canvas, inner, Color(base, 0.82 * alpha), radius * 1.3)
			canvas.draw_style_box(_box(Color(base.lightened(0.35), 0.55 * alpha), radius), inner.grow(-s * 0.16))
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.55 * alpha), s * 0.09), Rect2(p + Vector2(s * 0.14, s * 0.1), Vector2(s * 0.42, s * 0.16)))
			canvas.draw_circle(p + Vector2(s * 0.74, s * 0.7), s * 0.055, Color(1, 1, 1, 0.5 * alpha))
			canvas.draw_circle(p + Vector2(s * 0.62, s * 0.8), s * 0.03, Color(1, 1, 1, 0.45 * alpha))

		BlockTheme.BlockStyle.CUBE3D:
			var d = s * 0.17
			_body(canvas, inner, base, 0.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - d, y0 + d),
				Vector2(x0 + d, y0 + d)]), Color(base.lightened(0.38), base.a))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + d, y0 + d), Vector2(x0 + d, y1 - d),
				Vector2(x0, y1)]), Color(base.lightened(0.16), base.a))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x1, y0), Vector2(x1, y1), Vector2(x1 - d, y1 - d),
				Vector2(x1 - d, y0 + d)]), Color(base.darkened(0.25), base.a))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x0, y1), Vector2(x0 + d, y1 - d), Vector2(x1 - d, y1 - d),
				Vector2(x1, y1)]), Color(base.darkened(0.42), base.a))
			canvas.draw_rect(Rect2(p + Vector2(d, d), Vector2(s - d * 2, s * 0.06)), Color(1, 1, 1, 0.22 * alpha))

		BlockTheme.BlockStyle.BRICK:
			var small = radius * 0.5
			canvas.draw_style_box(_box(Color(base.darkened(0.3), base.a), small), Rect2(p + Vector2(0, s * 0.06), inner.size))
			_body(canvas, inner, base, small)
			canvas.draw_style_box(_box(Color(base.lightened(0.15), base.a), small, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), Rect2(p, Vector2(s, s * 0.12)))
			# Кнопка: тень под ней, тёмный обод, светлый верх и блик — видна на любом цвете
			var center = p + Vector2(s * 0.5, s * 0.46)
			canvas.draw_circle(center + Vector2(0, s * 0.07), s * 0.22, Color(base.darkened(0.45), base.a))
			canvas.draw_circle(center, s * 0.22, Color(base.darkened(0.18), base.a))
			canvas.draw_circle(center + Vector2(0, -s * 0.015), s * 0.185, Color(base.lightened(0.18), base.a))
			canvas.draw_arc(center, s * 0.13, deg_to_rad(195), deg_to_rad(285), 8, Color(1, 1, 1, 0.75 * alpha), maxf(1.5, 3.2 * scale), true)

		BlockTheme.BlockStyle.FROST:
			var icy = base.lerp(Color(0.92, 0.98, 1), 0.45)
			if _grad_on:
				_grad_top = _grad_top.lerp(Color(0.92, 0.98, 1), 0.45)
				_grad_bottom = _grad_bottom.lerp(Color(0.92, 0.98, 1), 0.45)
			_body(canvas, inner, Color(icy, 0.9 * alpha), radius)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(1, 1, 1, 0.85 * alpha), maxi(1, int(2 * scale))), inner)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.06, s * 0.06), p + Vector2(s * 0.42, s * 0.06),
				p + Vector2(s * 0.06, s * 0.36)]), Color(1, 1, 1, 0.55 * alpha))
			var crack = Color(1, 1, 1, 0.7 * alpha)
			var w = maxf(1.0, 1.4 * scale)
			var hub = p + Vector2(s * 0.62, s * 0.62)
			canvas.draw_line(hub, p + Vector2(s * 0.86, s * 0.5), crack, w)
			canvas.draw_line(hub, p + Vector2(s * 0.76, s * 0.88), crack, w)
			canvas.draw_line(hub, p + Vector2(s * 0.4, s * 0.74), crack, w)
			_spark(canvas, p + Vector2(s * 0.3, s * 0.3), s * 0.07, Color(1, 1, 1, 0.9 * alpha))

		BlockTheme.BlockStyle.GALAXY:
			canvas.draw_style_box(_box(Color(base.darkened(0.78), base.a), radius, Color(base.lightened(0.15), 0.75 * alpha),
				maxi(1, int(2 * scale))), inner)
			canvas.draw_circle(p + Vector2(s * 0.58, s * 0.44), s * 0.3, Color(base, 0.35 * alpha))
			canvas.draw_circle(p + Vector2(s * 0.42, s * 0.6), s * 0.2, Color(base.lightened(0.3), 0.3 * alpha))
			for star in [[0.22, 0.24, 0.035], [0.74, 0.22, 0.025], [0.8, 0.74, 0.03], [0.3, 0.78, 0.02], [0.52, 0.5, 0.025]]:
				canvas.draw_circle(p + Vector2(s * star[0], s * star[1]), s * star[2], Color(1, 1, 1, 0.9 * alpha))

		_:
			canvas.draw_style_box(_box(base, radius), inner)

# Тело блока: сплошное или градиент окраски (скруглённая текстура из кэша; прозрачность — из color.a)
static func _body(canvas: CanvasItem, rect: Rect2, color: Color, radius: float) -> void:
	if not _grad_on:
		canvas.draw_style_box(_box(color, radius), rect)
		return
	var texture = _gradient_texture(_grad_top, _grad_bottom, radius / maxf(rect.size.x, 1.0))
	canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, color.a))

# Светлая накладка: обычно — светлее цвет блока; на градиенте — полупрозрачный белый
static func _lighter(base: Color, amount: float) -> Color:
	if _grad_on:
		return Color(1, 1, 1, amount * 1.1 * base.a)
	return Color(base.lightened(amount), base.a)

static func _darker(base: Color, amount: float) -> Color:
	if _grad_on:
		return Color(0, 0, 0, amount * 0.9 * base.a)
	return Color(base.darkened(amount), base.a)

# Квадрат 48×48 со скруглёнными углами (доля radius_share от стороны) и градиентом сверху вниз
# с лёгким наклоном. Кэшируется: окраска — несколько пар цветов, текстур выходит пара десятков.
static func _gradient_texture(top: Color, bottom: Color, radius_share: float) -> ImageTexture:
	var share = snappedf(clampf(radius_share, 0.0, 0.5), 0.04)
	var key = "%s|%s|%.2f" % [top.to_html(), bottom.to_html(), share]
	if _grad_cache.has(key):
		return _grad_cache[key]
	var n = 48
	var image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r = share * n
	for y in range(n):
		for x in range(n):
			var t = clampf((y + x * 0.25) / (n * 1.25), 0.0, 1.0)
			var c = top.lerp(bottom, t)
			# Скругление: расстояние до ближайшего «центра угла», мягкий край в 1 пиксель
			var cx = clampf(x + 0.5, r, n - r)
			var cy = clampf(y + 0.5, r, n - r)
			var d = Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			c.a = clampf(r - d + 0.5, 0.0, 1.0) if r > 0.0 else 1.0
			image.set_pixel(x, y, c)
	var texture = ImageTexture.create_from_image(image)
	# Чистить кэш посреди отрисовки нельзя: уже отправленные текстуры освободятся, и блоки выйдут
	# белыми (так и было на витрине окрасок). Очистка — в начале следующего кадра.
	if _grad_cache.size() > 400 and not _grad_clear_scheduled:
		_grad_clear_scheduled = true
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.process_frame.connect(_clear_gradients, CONNECT_ONE_SHOT)
	_grad_cache[key] = texture
	return texture

static func _clear_gradients() -> void:
	_grad_cache.clear()
	_grad_clear_scheduled = false

# Четырёхлучевая искорка
static func _spark(canvas: CanvasItem, at: Vector2, arm: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -arm), at + Vector2(arm * 0.28, 0),
		at + Vector2(0, arm), at + Vector2(-arm * 0.28, 0)]), color)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-arm, 0), at + Vector2(0, arm * 0.28),
		at + Vector2(arm, 0), at + Vector2(0, -arm * 0.28)]), color)

# Вспышка при очистке: клетка светлеет и сжимается (t от 0 до 1)
static func draw_flash(canvas: CanvasItem, rect: Rect2, color: Color, theme: BlockTheme, t: float) -> void:
	var shrink = rect.size.x * 0.5 * t
	var flash_rect = rect.grow(-shrink)
	if flash_rect.size.x <= 1.0:
		return
	var mixed = color.lerp(theme.flash_color, clampf(t * 2.0, 0.0, 1.0))
	draw_block(canvas, flash_rect, mixed, theme, 1.0 - t * 0.6)
