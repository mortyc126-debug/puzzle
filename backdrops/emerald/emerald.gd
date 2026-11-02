extends BackdropBase

## «Изумрудный зал»: тёмный изумруд (#0E3B2E, #1F6F5B) с золотыми веерами ар-деко (#D4AF37)
## и медленным бликом света, проходящим по стене.

const GOLD = Color(0.83, 0.69, 0.22)

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.12, 0.43, 0.36), Color(0.03, 0.17, 0.13))
	# Веера ар-деко: все дуги и лучи собираются в три пакета отрезков — три вызова отрисовки
	# вместо девяти на каждый веер (раньше выходило ~700 вызовов на кадр со статичным фоном)
	var outer = PackedVector2Array()
	var inner = PackedVector2Array()
	var rays = PackedVector2Array()
	var size = area.x / 4.0
	var row = 0
	var y = size * 0.5
	while y < area.y + size:
		var x = (size / 2.0) * (row % 2)
		while x < area.x + size:
			_fan(Vector2(x, y), size * 0.5, outer, inner, rays)
			x += size
		y += size * 0.5
		row += 1
	draw_multiline(outer, Color(GOLD, 0.28), 2.0)
	draw_multiline(inner, Color(GOLD, 0.2), 1.6)
	draw_multiline(rays, Color(GOLD, 0.16), 1.4)

# Веер: полукруг с лучами — отрезки дописываются в общие пакеты
func _fan(center: Vector2, radius: float, outer: PackedVector2Array, inner: PackedVector2Array, rays: PackedVector2Array) -> void:
	for k in range(18):
		var a0 = PI + PI * k / 18.0
		var a1 = PI + PI * (k + 1) / 18.0
		outer.append_array([center + Vector2(cos(a0), sin(a0)) * radius, center + Vector2(cos(a1), sin(a1)) * radius])
		inner.append_array([center + Vector2(cos(a0), sin(a0)) * radius * 0.6, center + Vector2(cos(a1), sin(a1)) * radius * 0.6])
	for k in range(7):
		var a = PI + PI * k / 6.0
		rays.append_array([center, center + Vector2(cos(a), sin(a)) * radius])

func _paint_fx() -> void:
	# Диагональный блик проходит по стене раз в 9 секунд
	var t = fposmod(time / 9.0, 1.0)
	var x = -area.x * 0.5 + t * area.x * 2.2
	fx.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + area.x * 0.18, 0),
		Vector2(x - area.x * 0.32, area.y), Vector2(x - area.x * 0.5, area.y)]), Color(1, 0.95, 0.75, 0.07))
	for k in range(4):
		var twinkle = 0.5 + 0.5 * sin(time * 1.7 + k * 1.9)
		glint(fx, Vector2(area.x * (0.15 + k * 0.24), area.y * (0.2 + 0.18 * (k % 3))), 7.0 * twinkle + 2.0,
			Color(1, 0.9, 0.55, 0.6 * twinkle))
