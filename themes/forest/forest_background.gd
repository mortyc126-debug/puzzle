extends Node2D

## Фон темы «Ночной лес»: тёмно-бирюзовое небо, луна в ореоле, три ряда елей, туман у земли
## и светлячки. Неподвижное рисуется один раз, светлячки — на отдельном слое 20 раз в секунду.

@export var top_color := Color(0.03, 0.05, 0.14)
@export var bottom_color := Color(0.04, 0.17, 0.19)
@export var firefly_count := 34

var _area := Vector2(900, 1600)
var _stars: Array = []
var _flies: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 62
	for i in range(60):
		_stars.append([Vector2(rng.randf() * _area.x, rng.randf() * _area.y * 0.45), rng.randf_range(0.6, 1.8)])
	for i in range(firefly_count):
		_flies.append({"home": Vector2(rng.randf() * _area.x, _area.y * rng.randf_range(0.35, 0.98)),
			"radius": rng.randf_range(20.0, 70.0), "speed": rng.randf_range(0.2, 0.6), "phase": rng.randf() * TAU,
			"blink": rng.randf_range(1.0, 2.6)})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), _area, Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	for star in _stars:
		draw_circle(star[0], star[1], Color(1, 1, 1, 0.5))
	var moon = Vector2(w * 0.24, h * 0.14)
	draw_circle(moon, w * 0.16, Color(0.75, 0.95, 0.9, 0.08))
	draw_circle(moon, w * 0.1, Color(0.8, 1, 0.95, 0.12))
	draw_circle(moon, w * 0.065, Color(0.95, 0.98, 0.88))
	draw_circle(moon + Vector2(w * 0.02, -w * 0.012), w * 0.012, Color(0.85, 0.88, 0.78))
	# Три ряда елей: дальние светлее и мельче (воздушная перспектива)
	var rows = [[0.62, 0.12, Color(0.08, 0.22, 0.26)], [0.74, 0.17, Color(0.05, 0.15, 0.18)], [0.9, 0.24, Color(0.02, 0.07, 0.09)]]
	var rng = RandomNumberGenerator.new()
	rng.seed = 6
	for row in rows:
		var base_y = h * row[0]
		var tree_h = h * row[1]
		draw_rect(Rect2(0, base_y, w, h - base_y), row[2])
		var x = -40.0
		while x < w + 40:
			var th = tree_h * rng.randf_range(0.7, 1.15)
			_pine(Vector2(x, base_y + 2), th, row[2])
			x += th * rng.randf_range(0.32, 0.5)
	# Туман у земли
	for k in range(6):
		draw_rect(Rect2(0, h * (0.8 + k * 0.025), w, h * 0.03), Color(0.6, 0.9, 0.85, 0.035))

func _pine(foot: Vector2, height: float, color: Color) -> void:
	var half = height * 0.3
	for tier in range(3):
		var top = foot.y - height * (1.0 - tier * 0.22)
		var bottom = foot.y - height * (0.45 - tier * 0.2)
		var span = half * (0.6 + tier * 0.25)
		draw_colored_polygon(PackedVector2Array([Vector2(foot.x, top), Vector2(foot.x + span, bottom),
			Vector2(foot.x - span, bottom)]), color)
	draw_rect(Rect2(foot.x - height * 0.03, foot.y - height * 0.25, height * 0.06, height * 0.25), color)

func _draw_fx() -> void:
	for fly in _flies:
		var t = _time * fly["speed"] + fly["phase"]
		var pos: Vector2 = fly["home"] + Vector2(cos(t) * fly["radius"], sin(t * 1.7) * fly["radius"] * 0.5)
		var glow = 0.5 + 0.5 * sin(_time * fly["blink"] + fly["phase"])
		_fx.draw_circle(pos, 9.0, Color(0.85, 1, 0.45, 0.12 * glow))
		_fx.draw_circle(pos, 4.0, Color(0.9, 1, 0.55, 0.35 * glow))
		_fx.draw_circle(pos, 1.8, Color(1, 1, 0.8, 0.5 + 0.5 * glow))
