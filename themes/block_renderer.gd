class_name BlockRenderer
extends RefCounted

## Рисует поле, пустые клетки и блоки в стиле темы. Используется Grid, Block и превью тем.
## Все функции принимают CanvasItem и должны вызываться из его _draw().

const BASE_CELL = 80.0

static var _box_cache: Dictionary = {}

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

static func draw_empty_cell(canvas: CanvasItem, rect: Rect2, theme: BlockTheme) -> void:
	var scale = rect.size.x / BASE_CELL
	var inner = rect.grow(-rect.size.x * 0.05)
	canvas.draw_style_box(_box(theme.cell_color, theme.block_corner_radius * 0.8 * scale), inner)

static func draw_block(canvas: CanvasItem, rect: Rect2, color: Color, theme: BlockTheme, alpha: float = 1.0) -> void:
	var size = rect.size.x
	var scale = size / BASE_CELL
	var radius = theme.block_corner_radius * scale
	var inner = rect.grow(-size * 0.04)
	var base = Color(color, color.a * alpha)

	match theme.block_style:
		BlockTheme.BlockStyle.FLAT:
			canvas.draw_style_box(_box(base, radius), inner)

		BlockTheme.BlockStyle.BEVEL:
			var shadow_rect = Rect2(inner.position + Vector2(2, 2) * scale, inner.size)
			canvas.draw_style_box(_box(Color(base.darkened(0.3), base.a), radius), shadow_rect)
			canvas.draw_style_box(_box(base, radius), inner)
			var top = Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5))
			canvas.draw_style_box(_box(Color(base.lightened(0.2), base.a), radius, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), top)
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(1, 1, 1, 0.9 * alpha),
				maxi(2, int(3 * scale))), inner)

		BlockTheme.BlockStyle.GLOSSY:
			canvas.draw_style_box(_box(base, radius), inner)
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
			canvas.draw_style_box(_box(base, radius), inner)
			canvas.draw_style_box(_box(Color(base.lightened(0.2), base.a), radius * 0.8), inner.grow(-size * 0.11))
			var shine = Rect2(inner.position + Vector2(size * 0.15, size * 0.12), Vector2(size * 0.32, size * 0.13))
			canvas.draw_style_box(_box(Color(1, 1, 1, 0.6 * alpha), size * 0.065), shine)
			canvas.draw_circle(inner.position + Vector2(size * 0.62, size * 0.19), size * 0.045, Color(1, 1, 1, 0.65 * alpha))

		BlockTheme.BlockStyle.GLASS:
			canvas.draw_style_box(_box(Color(base, 0.65 * alpha), radius, Color(base.lightened(0.55), 0.95 * alpha),
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
			canvas.draw_style_box(_box(base, radius), inner)
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
			canvas.draw_rect(body, base)
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
			canvas.draw_style_box(_box(Color(base.darkened(0.12), base.a), radius), inner)
			var top = Rect2(p, Vector2(s, s * 0.48))
			canvas.draw_style_box(_box(Color(base.lightened(0.28), base.a), radius, Color(0, 0, 0, 0), 0,
				Color(0, 0, 0, 0), 0, true), top)
			canvas.draw_rect(Rect2(p + Vector2(s * 0.06, s * 0.4), Vector2(s * 0.88, s * 0.08)), Color(1, 1, 1, 0.55 * alpha))
			canvas.draw_rect(Rect2(p + Vector2(s * 0.06, s * 0.48), Vector2(s * 0.88, s * 0.04)), Color(base.darkened(0.3), 0.6 * alpha))
			canvas.draw_style_box(_box(Color(0, 0, 0, 0), radius, Color(base.lightened(0.55), 0.85 * alpha),
				maxi(1, int(2 * scale))), inner)
			canvas.draw_circle(p + Vector2(s * 0.24, s * 0.2), s * 0.05, Color(1, 1, 1, 0.9 * alpha))

# Вспышка при очистке: клетка светлеет и сжимается (t от 0 до 1)
static func draw_flash(canvas: CanvasItem, rect: Rect2, color: Color, theme: BlockTheme, t: float) -> void:
	var shrink = rect.size.x * 0.5 * t
	var flash_rect = rect.grow(-shrink)
	if flash_rect.size.x <= 1.0:
		return
	var mixed = color.lerp(theme.flash_color, clampf(t * 2.0, 0.0, 1.0))
	draw_block(canvas, flash_rect, mixed, theme, 1.0 - t * 0.6)
