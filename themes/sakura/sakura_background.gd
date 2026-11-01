extends Node2D

## Фон темы «Сакура»: рассветное небо, гора с шапкой снега, цветущие ветви и падающие лепестки.
## Неподвижное рисуется один раз (_draw), лепестки — на отдельном слое 20 раз в секунду.

@export var top_color := Color(1.0, 0.86, 0.9)
@export var bottom_color := Color(0.86, 0.8, 1.0)
@export var petal_count := 42

var _area := Vector2(900, 1600)
var _petals: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 15
	for i in range(petal_count):
		_petals.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"speed": rng.randf_range(28.0, 60.0),
			"sway": rng.randf_range(18.0, 40.0),
			"phase": rng.randf() * TAU,
			"spin": rng.randf_range(-1.6, 1.6),
			"size": rng.randf_range(7.0, 13.0),
			"color": Color(1, 0.72, 0.82) if rng.randf() < 0.6 else Color(1, 0.9, 0.94),
		})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_petals)

func _process(delta: float) -> void:
	_time += delta
	for petal in _petals:
		var pos: Vector2 = petal["pos"]
		pos.y += petal["speed"] * delta
		pos.x += sin(_time * 0.8 + petal["phase"]) * petal["sway"] * delta
		if pos.y > _area.y + 20:
			pos.y = -20
			pos.x = fposmod(pos.x + 137.0, _area.x)
		petal["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), _area, Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# Солнце в дымке
	draw_circle(Vector2(w * 0.72, h * 0.3), w * 0.2, Color(1, 0.95, 0.9, 0.35))
	draw_circle(Vector2(w * 0.72, h * 0.3), w * 0.14, Color(1, 0.92, 0.88, 0.55))
	# Гора со снежной шапкой
	var base_y = h * 0.66
	var mountain = PackedVector2Array([Vector2(-w * 0.1, base_y), Vector2(w * 0.42, h * 0.38), Vector2(w * 0.5, h * 0.37),
		Vector2(w * 1.1, base_y)])
	draw_colored_polygon(mountain, Color(0.66, 0.6, 0.86, 0.55))
	var cap = PackedVector2Array([Vector2(w * 0.33, h * 0.43), Vector2(w * 0.42, h * 0.38), Vector2(w * 0.5, h * 0.37),
		Vector2(w * 0.58, h * 0.425), Vector2(w * 0.53, h * 0.415), Vector2(w * 0.48, h * 0.44), Vector2(w * 0.42, h * 0.42),
		Vector2(w * 0.38, h * 0.445)])
	draw_colored_polygon(cap, Color(1, 1, 1, 0.75))
	# Холмы
	var hills = PackedVector2Array([Vector2(0, h)])
	for k in range(13):
		hills.append(Vector2(w * k / 12.0, h * 0.74 + sin(k * 0.8) * h * 0.02))
	hills.append(Vector2(w, h))
	draw_colored_polygon(hills, Color(0.78, 0.62, 0.86, 0.5))
	# Цветущие ветви в верхних углах
	_branch(Vector2(-10, h * 0.1), Vector2(w * 0.32, h * 0.05), 1.0)
	_branch(Vector2(w + 10, h * 0.16), Vector2(w * 0.7, h * 0.1), -1.0)

func _branch(from: Vector2, to: Vector2, side: float) -> void:
	var mid = (from + to) / 2.0 + Vector2(0, 24)
	var points = PackedVector2Array()
	for i in range(11):
		var t = i / 10.0
		points.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
	draw_polyline(points, Color(0.36, 0.22, 0.22), 9.0, true)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(from.x) + 7
	for i in range(14):
		var t = rng.randf_range(0.25, 1.0)
		var at = points[int(t * 10)] + Vector2(rng.randf_range(-26, 26) * side, rng.randf_range(-22, 26))
		var radius = rng.randf_range(9.0, 15.0)
		var color = Color(1, 0.7, 0.8) if rng.randf() < 0.65 else Color(1, 0.88, 0.92)
		for petal in range(5):
			var angle = TAU * petal / 5.0 + i
			draw_circle(at + Vector2(cos(angle), sin(angle)) * radius * 0.55, radius * 0.5, color)
		draw_circle(at, radius * 0.22, Color(1, 0.85, 0.4))

func _draw_petals() -> void:
	for petal in _petals:
		var pos: Vector2 = petal["pos"]
		var angle = _time * petal["spin"] + petal["phase"]
		var size: float = petal["size"]
		var squash = 0.45 + 0.35 * absf(sin(_time * 1.7 + petal["phase"]))
		var points = PackedVector2Array()
		for k in range(8):
			var a = TAU * k / 8.0
			points.append(pos + Vector2(cos(a) * size, sin(a) * size * squash).rotated(angle))
		_fx.draw_colored_polygon(points, petal["color"])
