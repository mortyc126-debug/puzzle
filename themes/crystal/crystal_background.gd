extends Node2D

## Фон темы «Кристаллы»: аметистовая пещера, друзы кристаллов по краям и мерцающие искры.

@export var top_color := Color(0.13, 0.05, 0.24)
@export var bottom_color := Color(0.04, 0.02, 0.1)
@export var sparkle_count := 40

var _area := Vector2(900, 1600)
var _sparkles: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 55
	for i in range(sparkle_count):
		_sparkles.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.0, 2.6),
			"size": rng.randf_range(4.0, 9.0),
			"color": [Color(0.8, 0.6, 1), Color(0.5, 0.95, 1), Color(1, 0.7, 0.95)][i % 3],
		})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_sparkles)

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
	# Мягкие пятна света в глубине
	for spot in [[Vector2(w * 0.2, h * 0.3), Color(0.55, 0.3, 0.9, 0.08)], [Vector2(w * 0.8, h * 0.62), Color(0.2, 0.7, 0.9, 0.07)]]:
		for ring in range(4):
			draw_circle(spot[0], w * (0.4 - ring * 0.08), spot[1])
	# Друзы: снизу слева, снизу справа, сверху справа
	_cluster(Vector2(w * 0.08, h), -1.0, [Color(0.62, 0.35, 0.95), Color(0.45, 0.25, 0.8)], 1.0)
	_cluster(Vector2(w * 0.92, h), -1.0, [Color(0.3, 0.75, 0.95), Color(0.2, 0.5, 0.85)], 0.9)
	_cluster(Vector2(w * 0.86, 0), 1.0, [Color(0.85, 0.45, 0.9), Color(0.55, 0.3, 0.85)], 0.7)
	_cluster(Vector2(w * 0.1, 0), 1.0, [Color(0.4, 0.6, 1.0), Color(0.3, 0.35, 0.85)], 0.55)

# Пучок кристаллов из точки base; direction -1 — растут вверх, 1 — свисают вниз
func _cluster(base: Vector2, direction: float, colors: Array, scale_k: float) -> void:
	var specs = [[-0.5, 250, 46], [-0.2, 330, 56], [0.12, 280, 50], [0.42, 200, 40], [0.7, 150, 34]]
	for spec in specs:
		var angle: float = spec[0]
		var length = spec[1] * scale_k
		var width = spec[2] * scale_k
		var axis = Vector2(sin(angle), direction * cos(angle))
		var side = Vector2(axis.y, -axis.x)
		var tip = base + axis * length
		var shoulder = base + axis * (length * 0.78)
		var left = PackedVector2Array([base - side * width * 0.5, shoulder - side * width * 0.5, tip, base])
		var right = PackedVector2Array([base, tip, shoulder + side * width * 0.5, base + side * width * 0.5])
		draw_colored_polygon(left, Color(colors[0], 0.75))
		draw_colored_polygon(right, Color(colors[1], 0.75))
		draw_line(base, tip, Color(1, 1, 1, 0.35), 2.0)
		draw_polyline(PackedVector2Array([base - side * width * 0.5, shoulder - side * width * 0.5, tip,
			shoulder + side * width * 0.5, base + side * width * 0.5]), Color(1, 1, 1, 0.25), 2.0, true)

func _draw_sparkles() -> void:
	for sparkle in _sparkles:
		var t = 0.5 + 0.5 * sin(_time * sparkle["speed"] + sparkle["phase"])
		if t < 0.3:
			continue
		var pos: Vector2 = sparkle["pos"]
		var arm = sparkle["size"] * t
		var color = Color(sparkle["color"], 0.9 * t)
		_fx.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -arm), pos + Vector2(arm * 0.25, 0),
			pos + Vector2(0, arm), pos + Vector2(-arm * 0.25, 0)]), color)
		_fx.draw_colored_polygon(PackedVector2Array([pos + Vector2(-arm, 0), pos + Vector2(0, arm * 0.25),
			pos + Vector2(arm, 0), pos + Vector2(0, -arm * 0.25)]), color)
