extends Node2D

## Фон темы «Конфеты»: пастельный градиент, горошек и медленно падающая посыпка.

@export var top_color := Color(1.0, 0.82, 0.9)
@export var bottom_color := Color(0.8, 0.74, 1.0)
@export var sprinkle_colors: Array[Color] = [
	Color(1, 0.45, 0.7), Color(0.4, 0.85, 0.7), Color(1, 0.84, 0.3), Color(0.6, 0.5, 1), Color(0.45, 0.75, 1),
]
@export var sprinkle_count := 46

var _area := Vector2(900, 1600)
var _dots: Array = []
var _sprinkles: Array = []
var _since_redraw := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(28):
		_dots.append({"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y), "radius": rng.randf_range(10.0, 34.0)})
	for i in range(sprinkle_count):
		_sprinkles.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"angle": rng.randf() * TAU,
			"spin": rng.randf_range(-1.2, 1.2),
			"speed": rng.randf_range(12.0, 30.0),
			"color": sprinkle_colors[i % sprinkle_colors.size()],
		})

func _process(delta: float) -> void:
	for sprinkle in _sprinkles:
		var pos: Vector2 = sprinkle["pos"]
		pos.y += sprinkle["speed"] * delta
		if pos.y > _area.y + 20:
			pos.y = -20
		sprinkle["pos"] = pos
		sprinkle["angle"] += sprinkle["spin"] * delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_area.x, 0), _area, Vector2(0, _area.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	for dot in _dots:
		draw_circle(dot["pos"], dot["radius"], Color(1, 1, 1, 0.22))
	for sprinkle in _sprinkles:
		var half = Vector2(cos(sprinkle["angle"]), sin(sprinkle["angle"])) * 9.0
		draw_line(sprinkle["pos"] - half, sprinkle["pos"] + half, sprinkle["color"], 7.0, true)
