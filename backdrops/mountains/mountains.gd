extends BackdropBase

## «Горы» (статичный): плоская иллюстрация — закатное небо, солнце и пять слоёв гор,
## которые темнеют к зрителю (воздушная перспектива).

var ridges: Array = []

func is_animated() -> bool:
	return false

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 818
	for layer in range(5):
		var base = area.y * (0.42 + layer * 0.12)
		var points = PackedVector2Array([Vector2(0, area.y)])
		var x = 0.0
		while x <= area.x + 1.0:
			points.append(Vector2(x, base - rng.randf_range(0.0, area.y * (0.12 - layer * 0.015))))
			x += area.x / rng.randf_range(5.0, 9.0)
		points.append(Vector2(area.x, base - rng.randf_range(0.0, area.y * 0.05)))
		points.append(Vector2(area.x, area.y))
		ridges.append(points)

func _paint_static() -> void:
	vertical_gradient(0, area.y * 0.5, Color(0.2, 0.16, 0.38), Color(0.95, 0.55, 0.45))
	vertical_gradient(area.y * 0.5, area.y, Color(0.95, 0.55, 0.45), Color(0.95, 0.55, 0.45))
	var sun = Vector2(area.x * 0.66, area.y * 0.36)
	soft_blob(self, sun, area.x * 0.5, Color(1.0, 0.85, 0.55, 0.5))
	draw_circle(sun, area.x * 0.09, Color(1.0, 0.9, 0.65))
	var colors = [Color(0.62, 0.38, 0.52), Color(0.45, 0.27, 0.45), Color(0.3, 0.18, 0.37), Color(0.18, 0.11, 0.27), Color(0.09, 0.06, 0.16)]
	for layer in range(ridges.size()):
		draw_colored_polygon(ridges[layer], colors[layer])
