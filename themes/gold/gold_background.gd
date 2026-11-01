extends Node2D

## Фон темы «Золото»: чёрный бархат, золотые лучи ар-деко, рамка с уголками и медленная золотая пыль.

@export var top_color := Color(0.05, 0.04, 0.035)
@export var bottom_color := Color(0.13, 0.09, 0.04)
@export var gold := Color(1.0, 0.8, 0.35)
@export var dust_count := 50

var _area := Vector2(900, 1600)
var _dust: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 85
	for i in range(dust_count):
		_dust.append({"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y), "speed": rng.randf_range(8, 22),
			"phase": rng.randf() * TAU, "size": rng.randf_range(1.2, 3.2)})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_dust)

func _process(delta: float) -> void:
	_time += delta
	for mote in _dust:
		var pos: Vector2 = mote["pos"]
		pos.y -= mote["speed"] * delta
		pos.x += sin(_time * 0.6 + mote["phase"]) * 6.0 * delta
		if pos.y < -10:
			pos.y = _area.y + 10
		mote["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), _area, Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# Лучи ар-деко из нижней середины
	var origin = Vector2(w / 2.0, h * 1.02)
	for i in range(19):
		var angle = PI + PI * (i + 0.5) / 19.0
		var dir = Vector2(cos(angle), sin(angle))
		var side = Vector2(-dir.y, dir.x)
		var length = h * 1.1
		var spread = 0.012 if i % 2 == 0 else 0.006
		draw_colored_polygon(PackedVector2Array([origin, origin + dir * length + side * length * spread,
			origin + dir * length - side * length * spread]), Color(gold, 0.05 if i % 2 == 0 else 0.03))
	# Полукруги солнца ар-деко
	for ring in range(4):
		draw_arc(origin, w * (0.18 + ring * 0.09), PI, TAU, 48, Color(gold, 0.16 - ring * 0.03), 3.0, true)
	# Рамка с уголками
	var m = 22.0
	draw_rect(Rect2(m, m, w - m * 2, h - m * 2), Color(gold, 0.22), false, 2.0)
	draw_rect(Rect2(m + 10, m + 10, w - m * 2 - 20, h - m * 2 - 20), Color(gold, 0.12), false, 1.5)
	for corner in [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]:
		var sx = 1.0 if corner.x < w / 2.0 else -1.0
		var sy = 1.0 if corner.y < h / 2.0 else -1.0
		draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(46 * sx, 0), corner + Vector2(0, 46 * sy)]), Color(gold, 0.35))
		draw_circle(corner + Vector2(22 * sx, 22 * sy), 5.0, Color(gold, 0.5))

func _draw_dust() -> void:
	for mote in _dust:
		var twinkle = 0.45 + 0.55 * absf(sin(_time * 1.8 + mote["phase"]))
		_fx.draw_circle(mote["pos"], mote["size"], Color(gold, 0.7 * twinkle))
