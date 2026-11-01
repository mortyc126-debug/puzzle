extends Node2D

## Фон темы «Лава»: вулканическая ночь, силуэты гор, светящаяся лавовая река и поднимающиеся искры.

@export var top_color := Color(0.07, 0.03, 0.05)
@export var bottom_color := Color(0.24, 0.05, 0.03)
@export var ember_count := 46

var _area := Vector2(900, 1600)
var _embers: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 40
	for i in range(ember_count):
		_embers.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"speed": rng.randf_range(35.0, 90.0),
			"drift": rng.randf_range(-15.0, 15.0),
			"phase": rng.randf() * TAU,
			"size": rng.randf_range(2.0, 4.5),
		})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	for ember in _embers:
		var pos: Vector2 = ember["pos"]
		pos.y -= ember["speed"] * delta
		pos.x += ember["drift"] * delta + sin(_time * 2.0 + ember["phase"]) * 10.0 * delta
		if pos.y < -10:
			pos.y = _area.y * randf_range(0.85, 1.0)
			pos.x = randf() * _area.x
		ember["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), _area, Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# Дальние вулканы с отсветом
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.1, h * 0.8), Vector2(w * 0.22, h * 0.56), Vector2(w * 0.3, h * 0.55),
		Vector2(w * 0.62, h * 0.8)]), Color(0.16, 0.06, 0.07))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.35, h * 0.82), Vector2(w * 0.72, h * 0.5), Vector2(w * 0.8, h * 0.495),
		Vector2(w * 1.15, h * 0.82)]), Color(0.12, 0.05, 0.06))
	# Жерло светится
	draw_circle(Vector2(w * 0.76, h * 0.5), w * 0.07, Color(1, 0.4, 0.1, 0.25))
	draw_circle(Vector2(w * 0.76, h * 0.5), w * 0.03, Color(1, 0.6, 0.2, 0.5))
	# Ближние скалы
	var rocks = PackedVector2Array([Vector2(0, h)])
	for k in range(15):
		rocks.append(Vector2(w * k / 14.0, h * 0.84 - absf(sin(k * 1.9)) * h * 0.05))
	rocks.append(Vector2(w, h))
	draw_colored_polygon(rocks, Color(0.08, 0.03, 0.04))

func _draw_fx() -> void:
	var w = _area.x
	var h = _area.y
	# Лавовая река внизу «дышит»
	var pulse = 0.75 + 0.25 * sin(_time * 1.6)
	var river = PackedVector2Array()
	var colors = PackedColorArray()
	for k in range(13):
		var x = w * k / 12.0
		river.append(Vector2(x, h * 0.9 + sin(k * 1.3 + _time * 0.8) * 10.0))
		colors.append(Color(1, 0.45, 0.08, pulse))
	river.append(Vector2(w, h))
	colors.append(Color(1, 0.8, 0.25, pulse))
	river.append(Vector2(0, h))
	colors.append(Color(1, 0.8, 0.25, pulse))
	_fx.draw_polygon(river, colors)
	for ember in _embers:
		var flicker = 0.55 + 0.45 * sin(_time * 9.0 + ember["phase"])
		var color = Color(1, 0.55 + 0.35 * flicker, 0.15, 0.85 * flicker)
		_fx.draw_circle(ember["pos"], ember["size"], color)
