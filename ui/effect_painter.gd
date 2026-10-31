class_name EffectPainter
extends RefCounted

## Частицы эффектов очистки (коллекция «Эффекты»). Без узлов: частицы — словари в массиве,
## который хранит владелец (Grid или превью в профиле). Порядок: burst() → update() → draw().

const CONFETTI_COLORS = [Color(1, 0.45, 0.7), Color(1, 0.84, 0.3), Color(0.35, 0.85, 1), Color(0.4, 0.9, 0.55), Color(0.7, 0.5, 1)]
const FIREWORK_COLORS = [Color(1, 0.35, 0.45), Color(1, 0.85, 0.3), Color(0.4, 1, 0.7), Color(0.45, 0.75, 1), Color(1, 0.5, 1)]

static var _heart: PackedVector2Array = PackedVector2Array()

# Добавляет частицы одного «взрыва». cell — размер клетки, от него масштаб.
static func burst(particles: Array, kind: String, center: Vector2, color: Color, count: int, cell: float) -> void:
	var scale = cell / 80.0
	match kind:
		"confetti":
			for i in range(count + 2):
				_add(particles, center, _random_dir() * randf_range(140, 300) * scale + Vector2(0, -120 * scale),
					1.1, 9.0 * scale, CONFETTI_COLORS.pick_random(), "rect", 650 * scale, randf_range(-8, 8))
		"stars":
			for i in range(count):
				_add(particles, center + _random_dir() * 14 * scale, Vector2(randf_range(-50, 50), randf_range(-150, -70)) * scale,
					1.0, randf_range(7, 13) * scale, Color(1, 0.88, 0.35) if randf() < 0.7 else Color.WHITE, "star", -20 * scale, randf_range(-2, 2))
		"bubbles":
			for i in range(count):
				_add(particles, center + _random_dir() * 18 * scale, Vector2(randf_range(-40, 40), randf_range(-130, -60)) * scale,
					1.1, randf_range(5, 12) * scale, Color(0.85, 1, 1), "bubble", -40 * scale, 0.0)
		"hearts":
			for i in range(count):
				_add(particles, center + _random_dir() * 12 * scale, Vector2(randf_range(-60, 60), randf_range(-140, -60)) * scale,
					1.0, randf_range(8, 13) * scale, Color(1, 0.35, 0.55) if randf() < 0.6 else Color(1, 0.6, 0.8), "heart", -30 * scale, randf_range(-1, 1))
		"pixels":
			for i in range(count + 2):
				_add(particles, center + Vector2(randf_range(-20, 20), randf_range(-20, 20)) * scale,
					_random_dir() * randf_range(80, 220) * scale + Vector2(0, -160 * scale), 0.9, 12.0 * scale,
					color if randf() < 0.7 else color.lightened(0.4), "square", 900 * scale, 0.0)
		"rainbow":
			for i in range(count + 1):
				var particle = _add(particles, center, _random_dir() * randf_range(120, 260) * scale, 0.9, randf_range(5, 9) * scale,
					Color.WHITE, "rainbow", 300 * scale, 0.0)
				particle["hue"] = randf()
		"fireworks":
			var firework_color = FIREWORK_COLORS.pick_random()
			for i in range(14):
				var angle = TAU * i / 14.0
				_add(particles, center, Vector2(cos(angle), sin(angle)) * 260 * scale, 0.8, 4.5 * scale,
					firework_color, "trail", 160 * scale, 0.0)
		_:  # "sparks" — брызги в цвет темы
			for i in range(count):
				_add(particles, center, _random_dir() * randf_range(100, 240) * scale + Vector2(0, -60 * scale),
					0.65, randf_range(5, 10) * scale, color, "square", 500 * scale, 0.0)

static func update(particles: Array, delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			particles.remove_at(i)
			continue
		var velocity: Vector2 = p["vel"]
		velocity.y += p["gravity"] * delta
		if p["shape"] == "bubble":
			velocity.x = sin(p["life"] * 9.0) * 30.0
		p["vel"] = velocity
		p["pos"] += velocity * delta
		p["rot"] += p["spin"] * delta
		if p.has("hue"):
			p["hue"] = fmod(p["hue"] + delta * 1.5, 1.0)

static func draw(canvas: CanvasItem, particles: Array) -> void:
	for p in particles:
		var fade = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var color: Color = p["color"]
		color.a *= minf(1.0, fade * 1.6)
		var pos: Vector2 = p["pos"]
		var size: float = p["size"]
		match p["shape"]:
			"rect":
				canvas.draw_colored_polygon(_rotated_rect(pos, Vector2(size, size * 0.5), p["rot"]), color)
			"star":
				color.a *= 0.6 + 0.4 * sin(p["life"] * 20.0)
				canvas.draw_colored_polygon(_star(pos, size, p["rot"]), color)
			"bubble":
				canvas.draw_arc(pos, size, 0.0, TAU, 14, color, maxf(1.0, size * 0.18))
				canvas.draw_circle(pos + Vector2(-size, -size) * 0.35, size * 0.25, Color(1, 1, 1, color.a))
			"heart":
				canvas.draw_colored_polygon(_heart_points(pos, size, p["rot"]), color)
			"rainbow":
				var rainbow = Color.from_hsv(p["hue"], 0.8, 1.0, color.a)
				canvas.draw_rect(Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), rainbow)
			"trail":
				var velocity: Vector2 = p["vel"]
				canvas.draw_line(pos - velocity * 0.06, pos, color, size)
				canvas.draw_circle(pos, size * 0.8, Color(1, 1, 1, color.a))
			_:
				canvas.draw_rect(Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), color)

static func _add(particles: Array, pos: Vector2, vel: Vector2, life: float, size: float, color: Color,
		shape: String, gravity: float, spin: float) -> Dictionary:
	var particle = {"pos": pos, "vel": vel, "life": life, "max_life": life, "size": size, "color": color,
		"shape": shape, "gravity": gravity, "rot": randf() * TAU, "spin": spin}
	particles.append(particle)
	return particle

static func _random_dir() -> Vector2:
	var angle = randf() * TAU
	return Vector2(cos(angle), sin(angle))

static func _rotated_rect(center: Vector2, size: Vector2, angle: float) -> PackedVector2Array:
	var half = size / 2.0
	var points = PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		points.append(center + corner.rotated(angle))
	return points

static func _star(center: Vector2, radius: float, angle: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(8):
		var r = radius if i % 2 == 0 else radius * 0.38
		var a = angle + TAU * i / 8.0
		points.append(center + Vector2(cos(a), sin(a)) * r)
	return points

static func _heart_points(center: Vector2, size: float, angle: float) -> PackedVector2Array:
	if _heart.is_empty():
		# Классическая кривая сердца, нормированная к размеру 1
		for i in range(20):
			var t = TAU * i / 20.0
			var x = 16.0 * pow(sin(t), 3)
			var y = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			_heart.append(Vector2(x, y) / 16.0)
	var points = PackedVector2Array()
	for point in _heart:
		points.append(center + (point * size).rotated(angle * 0.3))
	return points
