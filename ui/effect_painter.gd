class_name EffectPainter
extends RefCounted

## Частицы эффектов очистки (коллекция «Эффекты»). Без узлов: частицы — словари в массиве,
## который хранит владелец (Grid или превью в профиле). Порядок: burst() → update() → draw().

const CONFETTI_COLORS = [Color(1, 0.45, 0.7), Color(1, 0.84, 0.3), Color(0.35, 0.85, 1), Color(0.4, 0.9, 0.55), Color(0.7, 0.5, 1)]
const BUTTERFLY_COLORS = [Color(1, 0.6, 0.85), Color(0.6, 0.85, 1), Color(1, 0.85, 0.4), Color(0.75, 0.6, 1), Color(0.6, 1, 0.75)]
const NOTE_COLORS = [Color(1, 0.5, 0.75), Color(0.5, 0.85, 1), Color(1, 0.85, 0.35), Color(0.7, 1, 0.6)]
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
		"petals":
			for i in range(count):
				_add(particles, center + _random_dir() * 10 * scale, Vector2(randf_range(-70, 70), randf_range(-120, -40)) * scale,
					1.3, randf_range(7, 11) * scale, Color(1, 0.7, 0.82) if randf() < 0.65 else Color(1, 0.92, 0.95), "petal",
					140 * scale, randf_range(-4, 4))
		"snow":
			for i in range(count):
				_add(particles, center + _random_dir() * 12 * scale, _random_dir() * randf_range(40, 110) * scale,
					1.2, randf_range(6, 10) * scale, Color(0.92, 0.97, 1), "flake", 60 * scale, randf_range(-2, 2))
		"embers":
			for i in range(count + 2):
				_add(particles, center + Vector2(randf_range(-22, 22), randf_range(-10, 10)) * scale,
					Vector2(randf_range(-60, 60), randf_range(-260, -120)) * scale, 0.9, randf_range(3, 6) * scale,
					Color(1, randf_range(0.45, 0.85), 0.15), "ember", -60 * scale, 0.0)
		"lightning":
			# Две-три ветвистые молнии из клетки и россыпь голубых искр
			for i in range(2 + randi() % 2):
				var bolt = _add(particles, center, Vector2.ZERO, 0.32, 3.0 * scale, Color(0.7, 0.9, 1), "bolt", 0.0, 0.0)
				bolt["points"] = _bolt_points(_random_dir() * randf_range(60, 110) * scale, 6)
			for i in range(count):
				_add(particles, center, _random_dir() * randf_range(120, 260) * scale, 0.4, randf_range(3, 5) * scale,
					Color(0.8, 0.95, 1), "square", 200 * scale, 0.0)
		"shockwave":
			# Кольцо разбегается от клетки, внутри вспышка цвета блока
			_add(particles, center, Vector2.ZERO, 0.5, 16.0 * scale, color.lightened(0.4), "ring", 0.0, 0.0)
			_add(particles, center, Vector2.ZERO, 0.35, 26.0 * scale, Color(1, 1, 1, 0.8), "ring", 0.0, 0.0)
			for i in range(maxi(count / 2, 2)):
				_add(particles, center, _random_dir() * randf_range(160, 300) * scale, 0.45, randf_range(3, 6) * scale,
					color.lightened(0.3), "square", 0.0, 0.0)
		"shards":
			# Блок раскалывается на треугольные осколки цвета блока, они кувыркаются и падают
			for i in range(count + 2):
				var shard = _add(particles, center + _random_dir() * 10 * scale,
					_random_dir() * randf_range(120, 280) * scale + Vector2(0, -200 * scale), 1.0, randf_range(9, 15) * scale,
					color.lightened(randf_range(0.0, 0.35)), "shard", 1100 * scale, randf_range(-10, 10))
				shard["points"] = PackedVector2Array([Vector2(randf_range(-1, -0.3), randf_range(-1, 0)),
					Vector2(randf_range(0.3, 1), randf_range(-1, 0.2)), Vector2(randf_range(-0.4, 0.4), randf_range(0.5, 1))])
		"coins":
			# Монетки подпрыгивают и крутятся
			for i in range(maxi(count / 2, 2)):
				_add(particles, center + _random_dir() * 8 * scale, Vector2(randf_range(-90, 90), randf_range(-380, -240)) * scale,
					1.1, randf_range(9, 12) * scale, Color(1, 0.82, 0.25), "coin", 950 * scale, randf_range(8, 14))
		"butterflies":
			for i in range(maxi(count / 2, 2)):
				var butterfly = _add(particles, center + _random_dir() * 10 * scale,
					Vector2(randf_range(-50, 50), randf_range(-120, -70)) * scale, 1.6, randf_range(14, 19) * scale,
					BUTTERFLY_COLORS.pick_random(), "butterfly", -10 * scale, 0.0)
				butterfly["phase"] = randf() * TAU
		"blackhole":
			# Чёрная дыра: тёмное ядро, искры закручиваются в воронку и исчезают
			_add(particles, center, Vector2.ZERO, 0.7, 22.0 * scale, Color(0.05, 0.02, 0.12), "hole", 0.0, 0.0)
			for i in range(count + 4):
				var spiral = _add(particles, center, Vector2.ZERO, 0.7, randf_range(3, 5) * scale,
					color.lightened(0.3) if randf() < 0.6 else Color(0.75, 0.55, 1), "streak", 0.0, 0.0)
				spiral["orbit"] = {"center": center, "angle": randf() * TAU, "radius": randf_range(30, 60) * scale, "speed": randf_range(7, 11)}
		"notes":
			for i in range(maxi(count / 2, 2)):
				var note = _add(particles, center + _random_dir() * 12 * scale, Vector2(randf_range(-40, 40), randf_range(-130, -80)) * scale,
					1.3, randf_range(13, 18) * scale, NOTE_COLORS.pick_random(), "note", -15 * scale, randf_range(-1.5, 1.5))
				note["phase"] = randf() * TAU
		"golddust":
			# Золотая пыль: мелкие блёстки и крестики бликов, медленно оседают
			for i in range(count + 4):
				_add(particles, center + _random_dir() * randf_range(4, 26) * scale,
					_random_dir() * randf_range(20, 90) * scale + Vector2(0, -40 * scale), randf_range(0.9, 1.4),
					randf_range(2, 4) * scale, Color(1, randf_range(0.75, 0.9), 0.35), "glitter", 40 * scale, 0.0)
			for i in range(3):
				_add(particles, center + _random_dir() * randf_range(6, 22) * scale, Vector2(0, -30 * scale), 0.9,
					randf_range(9, 14) * scale, Color(1, 0.95, 0.7), "glint", 0.0, randf_range(-2, 2))
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
		if p.has("orbit"):
			# Воронка: радиус тает, угол растёт — частица уходит в центр по спирали
			var orbit: Dictionary = p["orbit"]
			orbit["radius"] *= maxf(1.0 - 3.2 * delta, 0.0)
			orbit["angle"] += orbit["speed"] * delta
			p["pos"] = orbit["center"] + Vector2(cos(orbit["angle"]), sin(orbit["angle"])) * orbit["radius"]
			continue
		var velocity: Vector2 = p["vel"]
		velocity.y += p["gravity"] * delta
		if p["shape"] == "bubble":
			velocity.x = sin(p["life"] * 9.0) * 30.0
		elif p["shape"] == "butterfly" or p["shape"] == "note":
			velocity.x = sin(p["life"] * 4.0 + p["phase"]) * 45.0
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
			"petal":
				var squash = 0.45 + 0.35 * absf(sin(p["rot"] * 1.3))
				var points = PackedVector2Array()
				for k in range(8):
					var a = TAU * k / 8.0
					points.append(pos + Vector2(cos(a) * size, sin(a) * size * squash).rotated(p["rot"]))
				canvas.draw_colored_polygon(points, color)
			"flake":
				for k in range(3):
					var arm = Vector2(size, 0).rotated(p["rot"] + PI * k / 3.0)
					canvas.draw_line(pos - arm, pos + arm, color, maxf(1.0, size * 0.18))
				canvas.draw_circle(pos, size * 0.2, color)
			"ember":
				color.a *= 0.6 + 0.4 * sin(p["life"] * 30.0)
				canvas.draw_circle(pos, size * 1.8, Color(color, color.a * 0.25))
				canvas.draw_circle(pos, size, color)
			"trail":
				var velocity: Vector2 = p["vel"]
				canvas.draw_line(pos - velocity * 0.06, pos, color, size)
				canvas.draw_circle(pos, size * 0.8, Color(1, 1, 1, color.a))
			"bolt":
				var points = PackedVector2Array()
				for point in p["points"]:
					points.append(pos + point)
				canvas.draw_polyline(points, Color(color, color.a * 0.35), size * 3.0, true)
				canvas.draw_polyline(points, Color(1, 1, 1, color.a), maxf(1.0, size * 0.8), true)
			"ring":
				var grow = 1.0 - fade
				canvas.draw_arc(pos, size * (0.6 + grow * 2.8), 0.0, TAU, 32, color, maxf(1.0, size * 0.35 * fade), true)
			"shard":
				var points = PackedVector2Array()
				for point in p["points"]:
					points.append(pos + (point * size).rotated(p["rot"]))
				canvas.draw_colored_polygon(points, color)
				canvas.draw_line(points[0], points[1], Color(1, 1, 1, color.a * 0.7), maxf(1.0, size * 0.12))
			"coin":
				# Монетка вертится: ширина — модуль косинуса угла
				var width = maxf(absf(cos(p["rot"])), 0.15)
				var rim = PackedVector2Array()
				for k in range(16):
					var a = TAU * k / 16.0
					rim.append(pos + Vector2(cos(a) * size * width, sin(a) * size))
				canvas.draw_colored_polygon(rim, Color(0.8, 0.55, 0.1, color.a))
				var face = PackedVector2Array()
				for k in range(16):
					var a = TAU * k / 16.0
					face.append(pos + Vector2(cos(a) * size * width * 0.78, sin(a) * size * 0.78))
				canvas.draw_colored_polygon(face, color)
				canvas.draw_line(pos + Vector2(0, -size * 0.45), pos + Vector2(0, size * 0.45), Color(1, 0.95, 0.7, color.a * width), maxf(1.0, size * 0.18))
			"butterfly":
				var flap = 0.25 + 0.75 * absf(sin(p["life"] * 16.0 + p["phase"]))
				for side in [-1.0, 1.0]:
					var upper = PackedVector2Array()
					var lower = PackedVector2Array()
					for k in range(8):
						var a = TAU * k / 8.0
						upper.append(pos + Vector2(side * size * 0.55 * flap + cos(a) * size * 0.5 * flap, -size * 0.25 + sin(a) * size * 0.45))
						lower.append(pos + Vector2(side * size * 0.38 * flap + cos(a) * size * 0.32 * flap, size * 0.3 + sin(a) * size * 0.3))
					canvas.draw_colored_polygon(upper, color)
					canvas.draw_colored_polygon(lower, color.darkened(0.15))
				canvas.draw_line(pos + Vector2(0, -size * 0.45), pos + Vector2(0, size * 0.5), Color(0.25, 0.2, 0.3, color.a), maxf(1.0, size * 0.14))
			"hole":
				var pulse = sin((1.0 - fade) * PI)
				canvas.draw_circle(pos, size * (0.4 + pulse * 0.9), Color(0.55, 0.3, 1, 0.25 * color.a))
				canvas.draw_circle(pos, size * (0.25 + pulse * 0.6), color)
				canvas.draw_arc(pos, size * (0.27 + pulse * 0.6), 0.0, TAU, 24, Color(0.85, 0.65, 1, color.a * 0.8), maxf(1.0, size * 0.1), true)
			"streak":
				var orbit: Dictionary = p.get("orbit", {})
				var tail = Vector2.ZERO
				if not orbit.is_empty():
					tail = Vector2(-sin(orbit["angle"]), cos(orbit["angle"])) * -size * 2.5
				canvas.draw_line(pos + tail, pos, Color(color, color.a * 0.6), size * 0.8)
				canvas.draw_circle(pos, size * 0.6, color)
			"note":
				# Нота: овальная головка, штиль и флажок (рисуем фигурами — глифа ♪ в шрифтах игры нет)
				var head = PackedVector2Array()
				for k in range(10):
					var a = TAU * k / 10.0
					head.append(pos + Vector2(cos(a) * size * 0.5, sin(a) * size * 0.36).rotated(-0.4))
				canvas.draw_colored_polygon(head, color)
				var stem_top = pos + Vector2(size * 0.42, -size * 1.5)
				canvas.draw_line(pos + Vector2(size * 0.42, -size * 0.1), stem_top, color, maxf(1.0, size * 0.16))
				canvas.draw_line(stem_top, stem_top + Vector2(size * 0.55, size * 0.45), color, maxf(1.0, size * 0.2))
			"glitter":
				color.a *= 0.5 + 0.5 * absf(sin(p["life"] * 14.0 + p["max_life"] * 9.0))
				canvas.draw_circle(pos, size, color)
			"glint":
				var twinkle = absf(sin((1.0 - fade) * PI * 2.0))
				var arm = size * (0.4 + 0.6 * twinkle)
				canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -arm), pos + Vector2(arm * 0.18, 0),
					pos + Vector2(0, arm), pos + Vector2(-arm * 0.18, 0)]), color)
				canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(-arm, 0), pos + Vector2(0, arm * 0.18),
					pos + Vector2(arm, 0), pos + Vector2(0, -arm * 0.18)]), color)
			_:
				canvas.draw_rect(Rect2(pos - Vector2(size, size) / 2.0, Vector2(size, size)), color)

static func _add(particles: Array, pos: Vector2, vel: Vector2, life: float, size: float, color: Color,
		shape: String, gravity: float, spin: float) -> Dictionary:
	var particle = {"pos": pos, "vel": vel, "life": life, "max_life": life, "size": size, "color": color,
		"shape": shape, "gravity": gravity, "rot": randf() * TAU, "spin": spin}
	particles.append(particle)
	return particle

# Ломаная молнии: от нуля до конца с отклонениями поперёк
static func _bolt_points(to: Vector2, segments: int) -> PackedVector2Array:
	var points = PackedVector2Array([Vector2.ZERO])
	var normal = Vector2(-to.y, to.x).normalized()
	for i in range(1, segments):
		var t = float(i) / segments
		points.append(to * t + normal * randf_range(-0.18, 0.18) * to.length())
	points.append(to)
	return points

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
