extends BackdropBase

## «Соты» (статичный): тёплый янтарный фон, сетка шестиугольников и редкие соты,
## залитые мёдом. Контуры — одним вызовом, заливка — одним.

func is_animated() -> bool:
	return false

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.32, 0.17, 0.04), Color(0.16, 0.07, 0.02))
	var size = area.x / 11.0  # радиус шестиугольника
	var width = sqrt(3.0) * size
	var rng = RandomNumberGenerator.new()
	rng.seed = 733
	var lines = PackedVector2Array()
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	var row = 0
	var y = 0.0
	while y < area.y + size * 2.0:
		var x = (width / 2.0) * (row % 2)
		while x < area.x + width:
			var hexagon = PackedVector2Array()
			for k in range(6):
				var a = PI / 6.0 + TAU * k / 6.0
				hexagon.append(Vector2(x, y) + Vector2(cos(a), sin(a)) * size * 0.94)
			for k in range(6):
				lines.append_array([hexagon[k], hexagon[(k + 1) % 6]])
			if rng.randf() < 0.16:
				var honey = Color(1.0, 0.68, 0.15, rng.randf_range(0.35, 0.7))
				add_polygon(points, colors, hexagon, honey)
			x += width
		y += size * 1.5
		row += 1
	fill_triangles(self, points, colors)
	draw_multiline(lines, Color(1.0, 0.75, 0.3, 0.35), 2.0)
	soft_blob(self, Vector2(area.x * 0.3, area.y * 0.3), area.x * 0.7, Color(1.0, 0.7, 0.3, 0.18))
