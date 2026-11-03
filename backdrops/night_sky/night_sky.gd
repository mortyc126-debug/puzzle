extends BackdropBase

## «Ночное небо» (статичный): тёмно-синее небо, россыпь звёзд разной яркости,
## полоса Млечного Пути и тонкий месяц со свечением.

var stars: Array = []

func is_animated() -> bool:
	return false

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 512
	for i in range(170):
		var pos = Vector2(rng.randf() * area.x, rng.randf() * area.y)
		stars.append([pos, rng.randf_range(0.6, 2.2), rng.randf_range(0.25, 0.9)])
	# Млечный Путь: звёзды гуще вдоль диагонали
	for i in range(140):
		var t = rng.randf()
		var pos = Vector2(area.x * t, area.y * (0.7 - 0.5 * t)) + Vector2(rng.randfn(0, 1), rng.randfn(0, 1)) * area.x * 0.06
		stars.append([pos, rng.randf_range(0.5, 1.4), rng.randf_range(0.2, 0.6)])

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.02, 0.04, 0.12), Color(0.05, 0.08, 0.22))
	for k in range(5):
		var t = (k + 0.5) / 5.0
		soft_blob(self, Vector2(area.x * t, area.y * (0.7 - 0.5 * t)), area.x * 0.3, Color(0.45, 0.5, 0.95, 0.12))
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for star in stars:
		add_polygon(points, colors, circle_polygon(star[0], star[1], 6), Color(1, 1, 1, star[2]))
	fill_triangles(self, points, colors)
	# Месяц: светлый круг, «откушенный» кругом цвета неба
	var moon = Vector2(area.x * 0.78, area.y * 0.16)
	var r = area.x * 0.07
	soft_blob(self, moon, r * 4.0, Color(0.85, 0.88, 1.0, 0.25))
	draw_circle(moon, r, Color(0.98, 0.95, 0.82))
	draw_circle(moon + Vector2(r * 0.42, -r * 0.22), r * 0.88, Color(0.03, 0.05, 0.14))
