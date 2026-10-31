extends Node2D

## Фон темы «Дерево»: стол из тёмных досок с волокнами. Статичный — рисуется один раз.

@export var light_color := Color(0.45, 0.27, 0.15)
@export var dark_color := Color(0.24, 0.13, 0.07)
@export var plank_width := 150.0

var _area := Vector2(900, 1600)
var _grain: Array = []  # [PackedVector2Array, Color, width]

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 23
	var plank_count = int(ceil(_area.x / plank_width))
	for plank in range(plank_count):
		var x0 = plank * plank_width
		for line in range(7):
			var points = PackedVector2Array()
			var base_x = x0 + rng.randf_range(12.0, plank_width - 12.0)
			var amplitude = rng.randf_range(3.0, 10.0)
			var phase = rng.randf() * TAU
			for k in range(41):
				var y = _area.y * k / 40.0
				points.append(Vector2(base_x + sin(y / 160.0 + phase) * amplitude, y))
			_grain.append([points, Color(0, 0, 0, rng.randf_range(0.06, 0.14)), rng.randf_range(1.0, 3.0)])

func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_area.x, 0), _area, Vector2(0, _area.y)]),
		PackedColorArray([light_color, light_color, dark_color, dark_color]))
	for item in _grain:
		draw_polyline(item[0], item[1], item[2], true)
	# Щели между досками
	var x = plank_width
	while x < _area.x:
		draw_line(Vector2(x, 0), Vector2(x, _area.y), Color(0, 0, 0, 0.35), 4.0)
		draw_line(Vector2(x + 3, 0), Vector2(x + 3, _area.y), Color(1, 0.8, 0.6, 0.08), 2.0)
		x += plank_width
