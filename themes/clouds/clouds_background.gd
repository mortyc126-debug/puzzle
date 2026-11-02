extends Node2D

## Фон темы «Облака»: яркое небо как в аниме, солнце с лучами, пушистые облака плывут,
## пролетают птицы. Небо — один раз, облака, лучи и птицы — на отдельном слое 20 раз в секунду.

@export var top_color := Color(0.24, 0.55, 1.0)
@export var bottom_color := Color(0.78, 0.92, 1.0)

var _area := Vector2(900, 1600)
var _clouds: Array = []
var _birds: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 47
	for i in range(9):
		_clouds.append({"pos": Vector2(rng.randf() * _area.x, _area.y * rng.randf_range(0.08, 0.92)),
			"speed": rng.randf_range(6.0, 16.0), "scale": rng.randf_range(0.6, 1.3)})
	for i in range(3):
		_birds.append({"pos": Vector2(rng.randf() * _area.x, _area.y * rng.randf_range(0.12, 0.35)),
			"speed": rng.randf_range(30.0, 45.0), "phase": rng.randf() * TAU})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	for cloud in _clouds:
		var pos: Vector2 = cloud["pos"]
		pos.x += cloud["speed"] * delta
		if pos.x > _area.x + 260 * cloud["scale"]:
			pos.x = -260 * cloud["scale"]
		cloud["pos"] = pos
	for bird in _birds:
		var pos: Vector2 = bird["pos"]
		pos.x += bird["speed"] * delta
		if pos.x > _area.x + 40:
			pos.x = -40
		bird["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), _area, Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# Далёкие бледные облака у горизонта
	for k in range(7):
		_cloud(Vector2(w * (k / 6.0), h * 0.95), 1.4, Color(1, 1, 1, 0.55), Color(0.85, 0.92, 1, 0.4))
	var sun = Vector2(w * 0.8, h * 0.1)
	draw_circle(sun, w * 0.16, Color(1, 1, 0.9, 0.25))
	draw_circle(sun, w * 0.09, Color(1, 0.98, 0.85))

func _cloud(center: Vector2, size_k: float, color: Color, shade: Color) -> void:
	var r = 46.0 * size_k
	for part in [[-1.6, 0.25, 0.75], [-0.8, -0.2, 1.0], [0.2, -0.45, 1.2], [1.2, -0.1, 0.95], [1.9, 0.3, 0.7]]:
		draw_circle(center + Vector2(part[0] * r, part[1] * r + r * 0.18), r * part[2], shade)
	for part in [[-1.6, 0.25, 0.75], [-0.8, -0.2, 1.0], [0.2, -0.45, 1.2], [1.2, -0.1, 0.95], [1.9, 0.3, 0.7]]:
		draw_circle(center + Vector2(part[0] * r, part[1] * r), r * part[2], color)

func _draw_fx() -> void:
	var w = _area.x
	var h = _area.y
	# Лучи солнца медленно поворачиваются
	var sun = Vector2(w * 0.8, h * 0.1)
	for k in range(10):
		var a = _time * 0.05 + TAU * k / 10.0
		var tip0 = sun + Vector2(cos(a - 0.05), sin(a - 0.05)) * w * 0.55
		var tip1 = sun + Vector2(cos(a + 0.05), sin(a + 0.05)) * w * 0.55
		_fx.draw_colored_polygon(PackedVector2Array([sun, tip0, tip1]), Color(1, 1, 0.9, 0.07))
	for cloud in _clouds:
		var pos: Vector2 = cloud["pos"]
		var size_k: float = cloud["scale"]
		var r = 46.0 * size_k
		for part in [[-1.6, 0.25, 0.75], [-0.8, -0.2, 1.0], [0.2, -0.45, 1.2], [1.2, -0.1, 0.95], [1.9, 0.3, 0.7]]:
			_fx.draw_circle(pos + Vector2(part[0] * r, part[1] * r + r * 0.18), r * part[2], Color(0.78, 0.86, 1, 0.9))
		for part in [[-1.6, 0.25, 0.75], [-0.8, -0.2, 1.0], [0.2, -0.45, 1.2], [1.2, -0.1, 0.95], [1.9, 0.3, 0.7]]:
			_fx.draw_circle(pos + Vector2(part[0] * r, part[1] * r), r * part[2], Color(1, 1, 1, 0.97))
	for bird in _birds:
		var pos: Vector2 = bird["pos"]
		var flap = sin(_time * 7.0 + bird["phase"]) * 6.0
		_fx.draw_polyline(PackedVector2Array([pos + Vector2(-14, -flap), pos, pos + Vector2(14, -flap)]),
			Color(0.2, 0.3, 0.5, 0.7), 3.0, true)
