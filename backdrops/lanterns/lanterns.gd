extends BackdropBase

## «Фонарики»: ночное небо, холмы и отражение в воде; бумажные фонарики медленно поднимаются,
## покачиваясь, и светятся тёплым светом.

var stars: Array = []
var lanterns: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 210
	for i in range(60):
		stars.append([Vector2(rng.randf() * area.x, rng.randf() * area.y * 0.6), rng.randf_range(0.6, 1.6)])
	for i in range(14):
		lanterns.append({"pos": Vector2(rng.randf() * area.x, rng.randf_range(0.1, 1.0) * area.y), "speed": rng.randf_range(14, 30),
			"phase": rng.randf() * TAU, "size": rng.randf_range(18, 38)})

func _step(delta: float) -> void:
	for lantern in lanterns:
		var pos: Vector2 = lantern["pos"]
		pos.y -= lantern["speed"] * delta
		pos.x += sin(time * 0.5 + lantern["phase"]) * 6.0 * delta
		if pos.y < -60:
			pos.y = area.y * 0.85
		lantern["pos"] = pos

func _paint_static() -> void:
	vertical_gradient(0, area.y * 0.78, Color(0.04, 0.06, 0.15), Color(0.17, 0.11, 0.29))
	vertical_gradient(area.y * 0.78, area.y, Color(0.08, 0.06, 0.16), Color(0.02, 0.02, 0.06))
	for star in stars:
		draw_circle(star[0], star[1], Color(1, 1, 1, 0.5))
	var hills = PackedVector2Array([Vector2(0, area.y * 0.8)])
	for k in range(13):
		hills.append(Vector2(area.x * k / 12.0, area.y * (0.74 + 0.025 * sin(k * 1.1))))
	hills.append(Vector2(area.x, area.y * 0.8))
	draw_colored_polygon(hills, Color(0.05, 0.04, 0.12))

func _paint_fx() -> void:
	for lantern in lanterns:
		var pos: Vector2 = lantern["pos"]
		var s: float = lantern["size"]
		var flicker = 0.85 + 0.15 * sin(time * 6.0 + lantern["phase"])
		soft_blob(fx, pos, s * 3.0, Color(1, 0.6, 0.25, 0.45 * flicker))
		# Бумажный фонарик: шире сверху, уже снизу, светлая середина и огонёк внизу
		fx.draw_colored_polygon(PackedVector2Array([pos + Vector2(-s * 0.5, -s * 0.6), pos + Vector2(s * 0.5, -s * 0.6),
			pos + Vector2(s * 0.36, s * 0.6), pos + Vector2(-s * 0.36, s * 0.6)]), Color(1, 0.5, 0.2, 0.95))
		fx.draw_colored_polygon(PackedVector2Array([pos + Vector2(-s * 0.32, -s * 0.45), pos + Vector2(s * 0.32, -s * 0.45),
			pos + Vector2(s * 0.24, s * 0.45), pos + Vector2(-s * 0.24, s * 0.45)]), Color(1, 0.82, 0.45, 0.9 * flicker))
		fx.draw_circle(pos + Vector2(0, s * 0.42), s * 0.12, Color(1, 1, 0.8, flicker))
		# Отражение в воде
		if pos.y < area.y * 0.78:
			var mirror = Vector2(pos.x, area.y * 0.78 + (area.y * 0.78 - pos.y) * 0.25)
			if mirror.y < area.y:
				fx.draw_rect(Rect2(mirror - Vector2(s * 0.3, s * 0.2), Vector2(s * 0.6, s * 0.4)), Color(1, 0.6, 0.25, 0.15))
