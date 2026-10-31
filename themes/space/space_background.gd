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

func _draw() -> void:
	# Градиент сверху вниз
	var points = PackedVector2Array([Vector2.ZERO, Vector2(_area.x, 0), _area, Vector2(0, _area.y)])
	var colors = PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	draw_polygon(points, colors)

	# Туманности: несколько полупрозрачных кругов дают мягкий край
	for nebula in _nebulas:
		for ring in range(6):
			var t = float(ring) / 6.0
			draw_circle(nebula["pos"], nebula["radius"] * (1.0 - t * 0.8), nebula["color"])

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
