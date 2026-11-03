extends BackdropBase

## «Сэйгайха» (статичный): японский узор «волны синего моря» — ряды чешуек из концентрических
## дуг, бирюза на глубоком синем. Ряд рисуется заливкой и дугами (два вызова на ряд), сверху вниз:
## нижний ряд перекрывает верхний, как в настоящем узоре.

const SEGMENTS = 14

func is_animated() -> bool:
	return false

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.03, 0.16, 0.26), Color(0.02, 0.09, 0.17))
	var radius = area.x / 7.0
	var step_y = radius * 0.5
	var row = 0
	var y = 0.0
	while y < area.y + radius:
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		var arcs = PackedVector2Array()
		var x = -radius + (radius * (row % 2))
		var depth = clampf(y / area.y, 0.0, 1.0)
		var fill = Color(0.04, 0.2, 0.32).lerp(Color(0.02, 0.12, 0.22), depth)
		while x < area.x + radius * 2.0:
			var center = Vector2(x, y)
			add_polygon(points, colors, circle_polygon(center, radius, SEGMENTS, PI, TAU), fill)
			for ring in [1.0, 0.75, 0.5, 0.25]:
				for k in range(SEGMENTS):
					var a0 = PI + PI * k / SEGMENTS
					var a1 = PI + PI * (k + 1) / SEGMENTS
					arcs.append_array([center + Vector2(cos(a0), sin(a0)) * radius * ring,
						center + Vector2(cos(a1), sin(a1)) * radius * ring])
			x += radius * 2.0
		fill_triangles(self, points, colors)
		draw_multiline(arcs, Color(0.35, 0.8, 0.85, 0.55), 2.0)
		y += step_y
		row += 1
