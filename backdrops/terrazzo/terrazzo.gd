extends BackdropBase

## «Терраццо» (статичный): модный узор итальянского пола — тёмный камень и разноцветная
## каменная крошка. Все ~350 осколков — одним вызовом отрисовки.

const CHIP_COLORS = [Color(0.93, 0.55, 0.45), Color(0.95, 0.8, 0.55), Color(0.5, 0.75, 0.7),
	Color(0.85, 0.85, 0.82), Color(0.4, 0.5, 0.75), Color(0.75, 0.45, 0.6)]
var chips: Array = []

func is_animated() -> bool:
	return false

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 929
	for i in range(int(area.x * area.y / 4200.0)):
		var center = Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var size = area.x * (rng.randf_range(0.006, 0.016) if rng.randf() < 0.85 else rng.randf_range(0.02, 0.035))
		var polygon = PackedVector2Array()
		var corners = rng.randi_range(4, 6)
		var turn = rng.randf() * TAU
		for k in range(corners):
			var a = turn + TAU * k / corners + rng.randf_range(-0.3, 0.3)
			polygon.append(center + Vector2(cos(a), sin(a)) * size * rng.randf_range(0.7, 1.2))
		var color: Color = CHIP_COLORS[rng.randi() % CHIP_COLORS.size()]
		chips.append([polygon, Color(color, rng.randf_range(0.55, 0.9))])

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.17, 0.18, 0.22), Color(0.11, 0.12, 0.15))
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for chip in chips:
		add_polygon(points, colors, chip[0], chip[1])
	fill_triangles(self, points, colors)
