extends BackdropBase

## «Синтвейв»: ретро-закат — полосатое солнце, звёзды, неоновая сетка пола бежит к зрителю.
## Горизонт ниже поля: солнце садится за поле и подсвечивает его края, а сетка лежит под фигурами.

const HORIZON = 0.7
var stars: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 115
	for i in range(70):
		stars.append([Vector2(rng.randf() * area.x, rng.randf() * area.y * 0.55), rng.randf_range(0.6, 1.8)])

func _paint_static() -> void:
	var horizon = area.y * HORIZON
	vertical_gradient(0, horizon * 0.6, Color(0.07, 0.0, 0.18), Color(0.3, 0.02, 0.4))
	vertical_gradient(horizon * 0.6, horizon, Color(0.3, 0.02, 0.4), Color(1.0, 0.18, 0.55))
	vertical_gradient(horizon, area.y, Color(0.12, 0.0, 0.2), Color(0.03, 0.0, 0.08))
	for star in stars:
		draw_circle(star[0], star[1], Color(1, 1, 1, 0.55))
	# Солнце: жёлто-розовое, нижняя часть разрезана полосами, ниже горизонта обрезано
	var sun = Vector2(area.x * 0.5, horizon - area.x * 0.04)
	var r = area.x * 0.3
	soft_blob(self, sun, area.x * 0.75, Color(1.0, 0.3, 0.6, 0.55))
	for k in range(24):
		var t = float(k) / 23.0
		var y = sun.y - r + 2.0 * r * t
		var half = sqrt(maxf(r * r - pow(y - sun.y, 2), 0.0))
		var gap = t > 0.55 and int(t * 30) % 3 == 0
		if not gap and y < horizon:  # солнце садится: ниже горизонта его не видно
			draw_rect(Rect2(sun.x - half, y, half * 2.0, 2.0 * r / 23.0 + 1.0), Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.2, 0.6), t))
	draw_rect(Rect2(0, horizon - 2, area.x, 4), Color(1, 0.4, 0.85, 0.8))

func _paint_fx() -> void:
	var horizon = area.y * HORIZON
	var line = Color(0.95, 0.3, 1.0, 0.55)
	# Горизонтальные линии бегут вниз, расходясь к зрителю
	for k in range(12):
		var t = fposmod(float(k) / 12.0 + time * 0.08, 1.0)
		var y = horizon + (area.y - horizon) * t * t
		fx.draw_line(Vector2(0, y), Vector2(area.x, y), Color(line, line.a * (0.3 + t)), 2.0)
	# Лучи сходятся в точку на горизонте
	var vanish = Vector2(area.x * 0.5, horizon)
	for k in range(-8, 9):
		fx.draw_line(vanish, Vector2(area.x * 0.5 + k * area.x * 0.16, area.y), Color(0.3, 0.9, 1.0, 0.4), 1.6)
