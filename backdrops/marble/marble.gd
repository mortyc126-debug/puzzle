extends BackdropBase

## «Чёрный мрамор»: тёмный камень с белыми и золотыми прожилками; по поверхности изредка проходит блик.
## Тёмный, а не светлый: на светлом камне терялись белые надписи и полупрозрачные поля тем.

var veins: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 325
	for i in range(13):
		var points = PackedVector2Array()
		var p = Vector2(rng.randf() * area.x, -20)
		var direction = Vector2(rng.randf_range(-0.6, 0.6), 1).normalized()
		for k in range(16):
			points.append(p)
			direction = direction.rotated(rng.randf_range(-0.45, 0.45))
			p += direction * area.y * 0.08
		veins.append({"points": points, "gold": i % 3 == 0, "width": rng.randf_range(1.0, 3.2)})

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.09, 0.09, 0.1), Color(0.04, 0.04, 0.05))
	for vein in veins:
		var color = Color(0.86, 0.69, 0.3, 0.8) if vein["gold"] else Color(0.85, 0.85, 0.9, 0.3)
		draw_polyline(vein["points"], Color(color, color.a * 0.25), vein["width"] * 4.0, true)
		draw_polyline(vein["points"], color, vein["width"], true)

func _paint_fx() -> void:
	var t = fposmod(time / 9.0, 1.0)
	var y = -area.y * 0.3 + t * area.y * 1.6
	fx.draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(area.x, y - area.x * 0.4),
		Vector2(area.x, y - area.x * 0.4 + 110), Vector2(0, y + 110)]), Color(1, 1, 1, 0.08))
	# Искры бегут по золотым прожилкам
	for i in range(veins.size()):
		var vein = veins[i]
		if not vein["gold"]:
			continue
		var points: PackedVector2Array = vein["points"]
		var along = fposmod(time * 0.12 + i * 0.37, 1.0) * (points.size() - 1)
		var k = int(along)
		var pos = points[k].lerp(points[mini(k + 1, points.size() - 1)], along - k)
		soft_blob(fx, pos, area.x * 0.05, Color(1, 0.8, 0.35, 0.5))
		glint(fx, pos, area.x * 0.018, Color(1, 0.95, 0.75, 0.9))
