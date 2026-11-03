extends BackdropBase

## «Ар-деко» (статичный): угольно-чёрный фон, золотые лучи веером из-за горизонта,
## ступенчатая рамка и ромбы по краям — как в отелях 1920-х.

const GOLD = Color(0.86, 0.7, 0.32)

func is_animated() -> bool:
	return false

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.07, 0.07, 0.08), Color(0.03, 0.03, 0.04))
	var lines = PackedVector2Array()
	# Лучи веером от точки внизу по центру
	var origin = Vector2(area.x * 0.5, area.y * 1.05)
	for k in range(25):
		var a = PI + PI * (k + 0.5) / 25.0
		lines.append_array([origin + Vector2(cos(a), sin(a)) * area.x * 0.25, origin + Vector2(cos(a), sin(a)) * area.y * 1.2])
	# Ступенчатая рамка: три вложенных прямоугольника со срезанными углами
	for k in range(3):
		var inset = area.x * (0.03 + k * 0.022)
		var cut = area.x * (0.08 - k * 0.015)
		var r = Rect2(Vector2(inset, inset), area - Vector2(inset, inset) * 2.0)
		var corners = PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
			Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
			Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut)])
		for i in range(corners.size()):
			lines.append_array([corners[i], corners[(i + 1) % corners.size()]])
	draw_multiline(lines, Color(GOLD, 0.3), 2.0)
	# Ромбы по бокам
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	var y = area.y * 0.12
	while y < area.y * 0.92:
		for x in [area.x * 0.035, area.x * 0.965]:
			var d = area.x * 0.012
			add_polygon(points, colors, PackedVector2Array([Vector2(x, y - d * 1.6), Vector2(x + d, y), Vector2(x, y + d * 1.6), Vector2(x - d, y)]),
				Color(GOLD, 0.55))
		y += area.y * 0.08
	fill_triangles(self, points, colors)
	soft_blob(self, Vector2(area.x * 0.5, area.y), area.x * 0.9, Color(1.0, 0.8, 0.4, 0.12))
