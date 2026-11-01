extends Node2D

## Фон темы «Космос»: градиент, туманности, мерцающие звёзды и редкие кометы.
## Рисуется кодом, без картинок, поэтому почти ничего не весит.

@export var star_count := 160
@export var top_color := Color(0.02, 0.02, 0.09)
@export var bottom_color := Color(0.09, 0.03, 0.2)
@export var nebula_colors: Array[Color] = [Color(0.45, 0.2, 0.85, 0.05), Color(0.1, 0.55, 0.9, 0.04)]
@export var comet_chance_per_second := 0.08

var _area := Vector2(900, 1600)
var _stars: Array = []
var _nebulas: Array = []
var _comet = null
var _time := 0.0
var _since_redraw := 0.0
var _backdrop: Texture2D

# Градиент с туманностями запекается в маленькую картинку один раз за запуск игры:
# раньше это было 18 полупрозрачных кругов на весь экран 20 раз в секунду — тяжело для
# видеочипа телефона. Картинка растягивается с фильтрацией, края туманностей остаются мягкими.
static var _backdrop_cache: Dictionary = {}

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 2026  # одинаковое небо при каждом запуске

	for i in range(star_count):
		_stars.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"size": rng.randf_range(0.7, 2.6),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.5, 2.2),
		})

	for i in range(3):
		_nebulas.append({
			"pos": Vector2(rng.randf_range(0.1, 0.9) * _area.x, rng.randf_range(0.1, 0.9) * _area.y),
			"radius": rng.randf_range(0.35, 0.6) * _area.x,
			"color": nebula_colors[i % nebula_colors.size()] if not nebula_colors.is_empty() else Color(1, 1, 1, 0.03),
		})
	_backdrop = _get_backdrop()

func _get_backdrop() -> Texture2D:
	var key = "%s|%s|%s|%s" % [_area, top_color, bottom_color, nebula_colors]
	if _backdrop_cache.has(key):
		return _backdrop_cache[key]
	var width = 60
	var height = maxi(int(round(width * _area.y / _area.x)), 2)
	var image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for y in range(height):
		var base = top_color.lerp(bottom_color, float(y) / float(height - 1))
		for x in range(width):
			var point = Vector2((x + 0.5) / width * _area.x, (y + 0.5) / height * _area.y)
			var color = base
			for nebula in _nebulas:
				var distance = point.distance_to(nebula["pos"]) / nebula["radius"]
				if distance < 1.0:
					# Как 6 вложенных кругов: чем ближе к центру, тем больше слоёв
					var layers = 6.0 * clampf((1.0 - distance) / 0.8, 0.0, 1.0)
					var tint: Color = nebula["color"]
					color = color.lerp(Color(tint.r, tint.g, tint.b), 1.0 - pow(1.0 - tint.a, layers))
			image.set_pixel(x, y, color)
	var texture = ImageTexture.create_from_image(image)
	_backdrop_cache[key] = texture
	return texture

func _process(delta: float) -> void:
	_time += delta

	if _comet == null and randf() < delta * comet_chance_per_second:
		var start = Vector2(randf_range(0.3, 1.1) * _area.x, randf_range(-0.05, 0.3) * _area.y)
		_comet = {"pos": start, "vel": Vector2(-1, 0.55).normalized() * randf_range(500, 800), "life": 0.0}
	if _comet != null:
		_comet["pos"] += _comet["vel"] * delta
		_comet["life"] += delta
		if _comet["life"] > 2.5:
			_comet = null

	# Мерцание звёзд не требует 60 кадров — экономим батарею
	_since_redraw += delta
	var frame_time = 1.0 / 30.0 if _comet != null else 1.0 / 20.0
	if _since_redraw >= frame_time:
		_since_redraw = 0.0
		queue_redraw()

# Планета с кольцом — «Космос» венчает коллекцию тем
func _draw_planet(center: Vector2, radius: float) -> void:
	var ring_color = Color(0.85, 0.75, 1.0, 0.55)
	draw_set_transform(center, -0.35, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, radius * 1.75, PI, TAU, 40, ring_color, radius * 0.16, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(center, radius * 1.15, Color(0.5, 0.35, 1.0, 0.08))
	draw_circle(center, radius, Color(0.45, 0.32, 0.85))
	draw_circle(center + Vector2(radius * 0.18, radius * 0.16), radius * 0.86, Color(0.3, 0.18, 0.62))
	for band in range(3):
		var y = (band - 1) * radius * 0.38
		var half = sqrt(maxf(radius * radius - y * y, 0.0)) * 0.92
		draw_line(center + Vector2(-half, y), center + Vector2(half, y), Color(0.75, 0.6, 1.0, 0.25), radius * 0.12, true)
	draw_circle(center - Vector2(radius * 0.38, radius * 0.38), radius * 0.2, Color(1, 1, 1, 0.22))
	draw_set_transform(center, -0.35, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, radius * 1.75, 0.0, PI, 40, ring_color, radius * 0.16, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw() -> void:
	# Градиент и туманности — одной запечённой картинкой
	draw_texture_rect(_backdrop, Rect2(Vector2.ZERO, _area), false)
	_draw_planet(Vector2(_area.x * 0.8, _area.y * 0.15), _area.x * 0.085)

	# Звёзды
	for star in _stars:
		var twinkle = 0.5 + 0.5 * sin(_time * star["speed"] + star["phase"])
		var color = Color(1, 1, 1, 0.3 + 0.7 * twinkle)
		draw_circle(star["pos"], star["size"], color)
		if star["size"] > 2.2:
			var arm = star["size"] * (2.0 + 2.0 * twinkle)
			draw_line(star["pos"] - Vector2(arm, 0), star["pos"] + Vector2(arm, 0), Color(1, 1, 1, 0.35 * twinkle), 1.0)
			draw_line(star["pos"] - Vector2(0, arm), star["pos"] + Vector2(0, arm), Color(1, 1, 1, 0.35 * twinkle), 1.0)

	# Комета с хвостом
	if _comet != null:
		var fade = clampf(1.0 - _comet["life"] / 2.5, 0.0, 1.0)
		var head: Vector2 = _comet["pos"]
		var direction: Vector2 = _comet["vel"].normalized()
		for i in range(12):
			var t = float(i) / 12.0
			var seg_start = head - direction * 180.0 * t
			var seg_end = head - direction * 180.0 * (t + 1.0 / 12.0)
			draw_line(seg_start, seg_end, Color(0.75, 0.9, 1, (1.0 - t) * 0.8 * fade), 3.0 * (1.0 - t) + 0.5)
		draw_circle(head, 3.5, Color(1, 1, 1, fade))
