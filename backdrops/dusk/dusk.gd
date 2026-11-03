extends BackdropBase

## «Сумерки» (статичный): небо от глубокого индиго к розово-персиковому горизонту,
## первые звёзды и тёплое свечение у земли.

var stars: Array = []

func is_animated() -> bool:
	return false

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 401
	for i in range(60):
		stars.append([Vector2(rng.randf() * area.x, rng.randf() * area.y * 0.45), rng.randf_range(0.8, 2.0)])

func _paint_static() -> void:
	vertical_gradient(0, area.y * 0.45, Color(0.1, 0.08, 0.27), Color(0.36, 0.17, 0.45))
	vertical_gradient(area.y * 0.45, area.y * 0.8, Color(0.36, 0.17, 0.45), Color(0.82, 0.42, 0.5))
	vertical_gradient(area.y * 0.8, area.y, Color(0.82, 0.42, 0.5), Color(0.55, 0.25, 0.4))
	soft_blob(self, Vector2(area.x * 0.5, area.y * 0.85), area.x * 0.8, Color(1.0, 0.65, 0.45, 0.45))
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for star in stars:
		add_polygon(points, colors, circle_polygon(star[0], star[1], 6), Color(1, 1, 1, 0.3 + star[1] * 0.25))
	fill_triangles(self, points, colors)
