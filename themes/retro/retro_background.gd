extends Node2D

## Фон темы «Ретро»: синтвейв-закат — небо со звёздами, полосатое солнце и бегущая неоновая сетка.

@export var sky_top := Color(0.06, 0.02, 0.16)
@export var sky_horizon := Color(0.42, 0.06, 0.38)
@export var floor_color := Color(0.04, 0.01, 0.1)
@export var grid_color := Color(1, 0.2, 0.75, 0.7)
@export var horizon := 0.62  # Доля высоты экрана

var _area := Vector2(900, 1600)
var _stars: Array = []
var _time := 0.0
var _since_redraw := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 1984
	for i in range(70):
		_stars.append(Vector2(rng.randf() * _area.x, rng.randf() * _area.y * horizon * 0.8))

func _process(delta: float) -> void:
	_time += delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	var horizon_y = _area.y * horizon
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_area.x, 0), Vector2(_area.x, horizon_y), Vector2(0, horizon_y)]),
		PackedColorArray([sky_top, sky_top, sky_horizon, sky_horizon]))
	for star in _stars:
		draw_rect(Rect2(star, Vector2(3, 3)), Color(1, 1, 1, 0.7))

	# Солнце с горизонтальными прорезями
	var sun_center = Vector2(_area.x / 2.0, horizon_y)
	var sun_radius = _area.x * 0.36
	draw_circle(sun_center, sun_radius, Color(1, 0.4, 0.55))
	draw_circle(sun_center, sun_radius * 0.82, Color(1, 0.62, 0.35))
	draw_circle(sun_center + Vector2(0, -sun_radius * 0.3), sun_radius * 0.5, Color(1, 0.85, 0.3, 0.8))
	for i in range(6):
		var stripe_y = horizon_y - sun_radius * (0.08 + 0.11 * i)
		draw_rect(Rect2(sun_center.x - sun_radius, stripe_y, sun_radius * 2.0, 4.0 + i * 1.5), sky_horizon.lerp(sky_top, 0.15))

	# Пол и перспективная сетка, бегущая на зрителя
	draw_rect(Rect2(0, horizon_y, _area.x, _area.y - horizon_y), floor_color)
	draw_line(Vector2(0, horizon_y), Vector2(_area.x, horizon_y), Color(1, 0.4, 0.85), 3.0)
	var depth = _area.y - horizon_y
	var offset = fmod(_time * 0.35, 1.0)
	for i in range(12):
		var t = (float(i) + offset) / 12.0
		var y = horizon_y + depth * t * t
		draw_line(Vector2(0, y), Vector2(_area.x, y), grid_color, 2.0)
	for i in range(-8, 9):
		var bottom_x = _area.x / 2.0 + i * _area.x * 0.18
		draw_line(Vector2(_area.x / 2.0 + i * 18.0, horizon_y), Vector2(bottom_x, _area.y), grid_color, 2.0)
