extends Node2D

## Фон темы «Пустыня»: закатное небо, низкое солнце, три слоя дюн и кактусы.
## Неподвижное рисуется один раз, песчинки, которые несёт ветер, — на отдельном слое 20 раз в секунду.

@export var top_color := Color(0.3, 0.17, 0.42)
@export var mid_color := Color(0.96, 0.5, 0.36)
@export var low_color := Color(1.0, 0.78, 0.48)
@export var grain_count := 46

var _area := Vector2(900, 1600)
var _grains: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 26
	for i in range(grain_count):
		_grains.append({"pos": Vector2(rng.randf() * _area.x, _area.y * rng.randf_range(0.55, 1.0)),
			"speed": rng.randf_range(40.0, 110.0), "phase": rng.randf() * TAU, "size": rng.randf_range(1.2, 2.8)})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	for grain in _grains:
		var pos: Vector2 = grain["pos"]
		pos.x += grain["speed"] * delta
		pos.y += sin(_time * 2.0 + grain["phase"]) * 10.0 * delta
		if pos.x > _area.x + 10:
			pos.x = -10
		grain["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	_gradient(0.0, h * 0.5, top_color, mid_color)
	_gradient(h * 0.5, h * 0.66, mid_color, low_color)
	# Солнце в дымке над горизонтом
	var sun = Vector2(w * 0.66, h * 0.5)
	draw_circle(sun, w * 0.22, Color(1, 0.8, 0.5, 0.18))
	draw_circle(sun, w * 0.15, Color(1, 0.85, 0.55, 0.3))
	draw_circle(sun, w * 0.1, Color(1, 0.9, 0.62))
	for k in range(4):
		draw_rect(Rect2(sun.x - w * 0.12, sun.y + w * (0.02 + k * 0.025), w * 0.24, w * 0.008), Color(0.96, 0.55, 0.38, 0.6))
	# Дюны: дальние темнее и холоднее, ближние светлее
	_dune(h * 0.58, h * 0.03, 1.3, 0.0, Color(0.82, 0.48, 0.42))
	_dune(h * 0.66, h * 0.04, 0.9, 1.7, Color(0.9, 0.6, 0.42))
	_dune(h * 0.78, h * 0.05, 0.7, 3.1, Color(0.96, 0.72, 0.46))
	_cactus(Vector2(w * 0.14, h * 0.8), h * 0.11)
	_cactus(Vector2(w * 0.86, h * 0.84), h * 0.08)
	_cactus(Vector2(w * 0.4, h * 0.665), h * 0.035)

func _gradient(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w = _area.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

func _dune(base_y: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var w = _area.x
	var points = PackedVector2Array([Vector2(0, _area.y)])
	var ridge = PackedVector2Array()
	for k in range(25):
		var x = w * k / 24.0
		var y = base_y - sin(k / 24.0 * TAU * freq + phase) * amp - sin(k * 0.9 + phase) * amp * 0.25
		points.append(Vector2(x, y))
		ridge.append(Vector2(x, y))
	points.append(Vector2(w, _area.y))
	draw_colored_polygon(points, color)
	draw_polyline(ridge, color.lightened(0.25), 3.0, true)

func _cactus(foot: Vector2, height: float) -> void:
	var c = Color(0.36, 0.26, 0.28, 0.85)
	var trunk = height * 0.16
	draw_rect(Rect2(foot.x - trunk / 2, foot.y - height, trunk, height), c)
	draw_circle(Vector2(foot.x, foot.y - height), trunk / 2, c)
	for side in [-1, 1]:
		var arm_y = foot.y - height * (0.55 if side < 0 else 0.68)
		var arm_x = foot.x + side * height * 0.26
		draw_rect(Rect2(minf(foot.x, arm_x) , arm_y, absf(arm_x - foot.x), trunk * 0.7), c)
		draw_rect(Rect2(arm_x - trunk * 0.35, arm_y - height * 0.28, trunk * 0.7, height * 0.28 + trunk * 0.7), c)
		draw_circle(Vector2(arm_x, arm_y - height * 0.28), trunk * 0.35, c)

func _draw_fx() -> void:
	for grain in _grains:
		_fx.draw_circle(grain["pos"], grain["size"], Color(1, 0.9, 0.72, 0.55))
	# Дрожание воздуха у солнца
	var sun = Vector2(_area.x * 0.66, _area.y * 0.5)
	_fx.draw_arc(sun, _area.x * (0.12 + 0.01 * sin(_time * 1.3)), 0, TAU, 48, Color(1, 0.95, 0.75, 0.22), 4.0, true)
