extends BackdropBase

## «Королевский бархат»: глубокий пурпур, золотая решётка-дамаск с жемчужинами в узлах,
## корона и золотые блёстки, которые медленно оседают и мерцают.

const GOLD = Color(0.83, 0.69, 0.22)
var sparkles: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 88
	for i in range(44):
		sparkles.append({"pos": Vector2(rng.randf() * area.x, rng.randf() * area.y), "speed": rng.randf_range(18, 45),
			"phase": rng.randf() * TAU, "size": rng.randf_range(7, 15), "drift": rng.randf_range(-8, 8)})

func _step(delta: float) -> void:
	for sparkle in sparkles:
		var pos: Vector2 = sparkle["pos"]
		pos.y += sparkle["speed"] * delta
		pos.x += sin(time * 0.8 + sparkle["phase"]) * sparkle["drift"] * delta
		if pos.y > area.y + 10:
			pos.y = -10
		sparkle["pos"] = pos

func _paint_static() -> void:
	vertical_gradient(0, area.y * 0.5, Color(0.2, 0.04, 0.33), Color(0.29, 0.05, 0.42))
	vertical_gradient(area.y * 0.5, area.y, Color(0.29, 0.05, 0.42), Color(0.12, 0.02, 0.2))
	# Ромбическая решётка-дамаск
	var step = area.x / 6.0
	var lines = PackedVector2Array()  # все линии решётки — одним вызовом отрисовки
	var k = -area.y
	while k < area.x + area.y:
		lines.append_array([Vector2(k, 0), Vector2(k + area.y, area.y), Vector2(k + area.y, 0), Vector2(k, area.y)])
		k += step
	draw_multiline(lines, Color(GOLD, 0.16), 2.0, true)
	var y = 0.0
	var row = 0
	while y < area.y + step:
		var x = (step / 2.0) * (row % 2)
		while x < area.x + step:
			draw_circle(Vector2(x, y), 3.5, Color(1, 0.95, 0.85, 0.35))
			x += step
		y += step / 2.0
		row += 1
	# Корона вверху
	var c = Vector2(area.x * 0.5, area.y * 0.07)
	var w = area.x * 0.16
	var crown = PackedVector2Array([c + Vector2(-w, w * 0.5), c + Vector2(-w * 1.1, -w * 0.3), c + Vector2(-w * 0.55, w * 0.05),
		c + Vector2(0, -w * 0.55), c + Vector2(w * 0.55, w * 0.05), c + Vector2(w * 1.1, -w * 0.3), c + Vector2(w, w * 0.5)])
	draw_colored_polygon(crown, Color(GOLD, 0.22))
	for tip in [crown[1], crown[3], crown[5]]:
		draw_circle(tip, w * 0.09, Color(1, 0.95, 0.75, 0.3))
	# Виньетка
	for i in range(6):
		var inset = i * area.x * 0.025
		draw_rect(Rect2(Vector2(inset, inset), area - Vector2(inset, inset) * 2.0), Color(0.05, 0, 0.1, 0.07), false, area.x * 0.025)

func _paint_fx() -> void:
	# Блик скользит по бархату раз в 7 секунд
	var t = fposmod(time / 7.0, 1.0)
	var x = -area.x * 0.6 + t * area.x * 2.4
	fx.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + area.x * 0.22, 0),
		Vector2(x - area.x * 0.28, area.y), Vector2(x - area.x * 0.5, area.y)]), Color(1, 0.85, 1, 0.06))
	# Корона «дышит» светом, камни на зубцах мерцают по очереди
	var c = Vector2(area.x * 0.5, area.y * 0.07)
	var w = area.x * 0.16
	soft_blob(fx, c, w * 2.2, Color(1, 0.8, 0.4, 0.12 + 0.08 * sin(time * 1.5)))
	var tips = [c + Vector2(-w * 1.1, -w * 0.3), c + Vector2(0, -w * 0.55), c + Vector2(w * 1.1, -w * 0.3)]
	for i in range(tips.size()):
		var twinkle = maxf(sin(time * 2.0 - i * 2.1), 0.0)
		glint(fx, tips[i], w * 0.35 * twinkle, Color(1, 0.95, 0.75, 0.9 * twinkle))
	for sparkle in sparkles:
		var shine = 0.5 + 0.5 * sin(time * 3.0 + sparkle["phase"])
		glint(fx, sparkle["pos"], sparkle["size"] * (0.45 + 0.55 * shine), Color(1, 0.88, 0.45, 0.35 + 0.6 * shine))
