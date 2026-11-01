extends Node2D

## Фон темы «Северное сияние»: ночное небо, переливающиеся ленты сияния, заснеженные холмы
## с ёлками и редкий снег. Ленты и снег — на отдельном слое 20 раз в секунду.

@export var top_color := Color(0.02, 0.04, 0.12)
@export var bottom_color := Color(0.04, 0.12, 0.2)
@export var star_count := 110
@export var snow_count := 34

var _area := Vector2(900, 1600)
var _stars: Array = []
var _snow: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

const RIBBONS = [
	[0.3, Color(0.25, 1.0, 0.65), 0.0, 1.0],
	[0.42, Color(0.35, 0.75, 1.0), 2.1, 0.8],
	[0.24, Color(0.75, 0.45, 1.0), 4.2, 0.7],
]

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 70
	for i in range(star_count):
		_stars.append([Vector2(rng.randf() * _area.x, rng.randf() * _area.y * 0.7), rng.randf_range(0.6, 2.0)])
	for i in range(snow_count):
		_snow.append({"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y), "speed": rng.randf_range(20, 45),
			"phase": rng.randf() * TAU, "size": rng.randf_range(1.5, 3.5)})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	for flake in _snow:
		var pos: Vector2 = flake["pos"]
		pos.y += flake["speed"] * delta
		pos.x += sin(_time + flake["phase"]) * 12.0 * delta
		if pos.y > _area.y + 10:
			pos.y = -10
		flake["pos"] = pos
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
		draw_circle(star[0], star[1], Color(1, 1, 1, 0.55))
	# Заснеженные холмы и ёлки
	for layer in [[0.8, Color(0.75, 0.85, 0.95, 0.35)], [0.86, Color(0.88, 0.94, 1.0, 0.85)]]:
		var hills = PackedVector2Array([Vector2(0, h)])
		for k in range(13):
			hills.append(Vector2(w * k / 12.0, h * layer[0] + sin(k * 0.9 + layer[0] * 10.0) * h * 0.02))
		hills.append(Vector2(w, h))
		draw_colored_polygon(hills, layer[1])
	var rng = RandomNumberGenerator.new()
	rng.seed = 71
	for i in range(9):
		var x = rng.randf() * w
		var base_y = h * 0.83 + rng.randf_range(0, h * 0.04)
		var size = rng.randf_range(40, 80)
		for tier in range(3):
			var tier_w = size * (0.55 - tier * 0.13)
			var y = base_y - size * (0.35 + tier * 0.3)
			draw_colored_polygon(PackedVector2Array([Vector2(x - tier_w, y + size * 0.35), Vector2(x, y - size * 0.15),
				Vector2(x + tier_w, y + size * 0.35)]), Color(0.06, 0.16, 0.2))

func _draw_fx() -> void:
	var w = _area.x
	var h = _area.y
	# Ленты сияния: полоса вдоль волны, снизу яркая, кверху растворяется
	for ribbon in RIBBONS:
		var base_y = h * ribbon[0]
		var color: Color = ribbon[1]
		var phase: float = ribbon[2]
		var strength: float = ribbon[3]
		var segments = 24
		for k in range(segments):
			var x0 = w * k / float(segments)
			var x1 = w * (k + 1) / float(segments)
			var y0 = base_y + sin(k * 0.45 + _time * 0.35 + phase) * 60.0
			var y1 = base_y + sin((k + 1) * 0.45 + _time * 0.35 + phase) * 60.0
			var height0 = 220.0 + sin(k * 0.7 + _time * 0.5 + phase) * 70.0
			var height1 = 220.0 + sin((k + 1) * 0.7 + _time * 0.5 + phase) * 70.0
			var glow = 0.34 * strength * (0.7 + 0.3 * sin(k * 0.3 + _time + phase))
			_fx.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, y1 - height1), Vector2(x0, y0 - height0)]),
				PackedColorArray([Color(color, glow), Color(color, glow), Color(color, 0.0), Color(color, 0.0)]))
	for flake in _snow:
		_fx.draw_circle(flake["pos"], flake["size"], Color(1, 1, 1, 0.75))
