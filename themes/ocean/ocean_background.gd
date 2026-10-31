extends Node2D

## Фон темы «Океан»: толща воды, покачивающиеся лучи света, пузыри и песчаное дно.

@export var top_color := Color(0.03, 0.38, 0.5)
@export var bottom_color := Color(0.01, 0.08, 0.22)
@export var sand_color := Color(0.85, 0.72, 0.45, 0.35)
@export var bubble_count := 40

var _area := Vector2(900, 1600)
var _bubbles: Array = []
var _time := 0.0
var _since_redraw := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(bubble_count):
		_bubbles.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"radius": rng.randf_range(3.0, 11.0),
			"speed": rng.randf_range(25.0, 70.0),
			"phase": rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	for bubble in _bubbles:
		var pos: Vector2 = bubble["pos"]
		pos.y -= bubble["speed"] * delta
		if pos.y < -20:
			pos.y = _area.y + 20
		bubble["pos"] = pos
	# 20 кадров в секунду достаточно для плавных пузырей и бережёт батарею
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_area.x, 0), _area, Vector2(0, _area.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))

	# Лучи света сверху, медленно покачиваются
	for i in range(4):
		var x = _area.x * (0.15 + 0.25 * i) + sin(_time * 0.4 + i) * 40.0
		var ray = PackedVector2Array([Vector2(x - 40, 0), Vector2(x + 40, 0),
			Vector2(x + 220, _area.y * 0.75), Vector2(x - 60, _area.y * 0.75)])
		draw_colored_polygon(ray, Color(0.7, 0.95, 1, 0.045))

	# Песчаное дно
	var sand = PackedVector2Array()
	for k in range(13):
		var x = _area.x * k / 12.0
		sand.append(Vector2(x, _area.y - 70 + sin(k * 0.9) * 18.0))
	sand.append(_area)
	sand.append(Vector2(0, _area.y))
	draw_colored_polygon(sand, sand_color)

	for bubble in _bubbles:
		var pos: Vector2 = bubble["pos"] + Vector2(sin(_time * 1.5 + bubble["phase"]) * 6.0, 0)
		draw_arc(pos, bubble["radius"], 0.0, TAU, 16, Color(0.85, 1, 1, 0.45), 1.5)
		draw_circle(pos + Vector2(-bubble["radius"] * 0.35, -bubble["radius"] * 0.35), bubble["radius"] * 0.25, Color(1, 1, 1, 0.5))
