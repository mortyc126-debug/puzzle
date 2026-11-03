extends BackdropBase

## «Конфетти» (статичный): глубокий фиолетовый праздник — полоски, кружочки и треугольники
## конфетти, рассыпанные по фону. Всё — одним вызовом отрисовки.

const COLORS = [Color(1.0, 0.36, 0.55), Color(1.0, 0.8, 0.25), Color(0.3, 0.85, 0.95), Color(0.55, 0.95, 0.5), Color(1.0, 0.55, 0.25)]
var pieces: Array = []

func is_animated() -> bool:
	return false

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 1031
	for i in range(160):
		var center = Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var size = area.x * rng.randf_range(0.008, 0.016)
		var turn = rng.randf() * TAU
		var polygon: PackedVector2Array
		match rng.randi() % 3:
			0:
				var along = Vector2(cos(turn), sin(turn)) * size * 1.6
				var across = Vector2(-sin(turn), cos(turn)) * size * 0.45
				polygon = PackedVector2Array([center - along - across, center + along - across, center + along + across, center - along + across])
			1:
				polygon = circle_polygon(center, size * 0.7, 8)
			_:
				polygon = PackedVector2Array([center + Vector2(cos(turn), sin(turn)) * size,
					center + Vector2(cos(turn + 2.1), sin(turn + 2.1)) * size, center + Vector2(cos(turn + 4.2), sin(turn + 4.2)) * size])
		pieces.append([polygon, Color(COLORS[rng.randi() % COLORS.size()], rng.randf_range(0.6, 0.95))])

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.22, 0.08, 0.36), Color(0.12, 0.04, 0.22))
	soft_blob(self, Vector2(area.x * 0.5, area.y * 0.45), area.x * 0.9, Color(0.6, 0.25, 0.8, 0.25))
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for piece in pieces:
		add_polygon(points, colors, piece[0], piece[1])
	fill_triangles(self, points, colors)
