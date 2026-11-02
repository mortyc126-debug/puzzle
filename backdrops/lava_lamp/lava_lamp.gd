extends BackdropBase

## «Лава-лампа»: тёплые капли медленно всплывают и опускаются, сливаясь друг с другом.

var drops: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 52
	var colors = [Color(1.0, 0.45, 0.2), Color(1.0, 0.3, 0.45), Color(1.0, 0.72, 0.25)]
	for i in range(8):
		drops.append({"x": rng.randf_range(0.1, 0.9), "speed": rng.randf_range(0.03, 0.06), "phase": rng.randf(),
			"size": rng.randf_range(0.12, 0.22), "color": colors[i % colors.size()]})

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.22, 0.04, 0.2), Color(0.45, 0.08, 0.18))

func _paint_fx() -> void:
	for drop in drops:
		# Капля ходит вверх-вниз по синусоиде и вытягивается на ходу, как воск в лампе
		var t = fposmod(time * drop["speed"] + drop["phase"], 1.0)
		var y = area.y * (0.5 + 0.42 * sin(t * TAU))
		var x = area.x * drop["x"] + sin(time * 0.3 + drop["phase"] * 9.0) * area.x * 0.04
		var r = area.x * drop["size"]
		var stretch = 1.0 + 0.35 * absf(cos(t * TAU))
		soft_blob(fx, Vector2(x, y), r * 1.6, Color(drop["color"], 0.3))
		fx.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0 / sqrt(stretch), stretch))
		fx.draw_circle(Vector2.ZERO, r * 0.75, Color(drop["color"], 0.95))
		fx.draw_circle(Vector2(0, r * 0.12), r * 0.6, Color(drop["color"].lightened(0.15), 0.9))
		fx.draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.2, Color(1, 0.92, 0.75, 0.4))
		fx.draw_set_transform_matrix(Transform2D.IDENTITY)
