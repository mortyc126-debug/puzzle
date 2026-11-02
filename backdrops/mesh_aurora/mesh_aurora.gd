extends BackdropBase

## «Аврора»: тёмно-синий фон и три светящихся пятна — бирюза, индиго, маджента
## (палитра «авроровых» градиентов: #06B6D4, #6366F1, #EC4899 на #1B1F3A). Пятна дрейфуют.

var blobs := [
	[Color(0.02, 0.71, 0.83, 0.75), 0.55, 0.25, 0.25, 0.0],
	[Color(0.39, 0.4, 0.95, 0.8), 0.6, 0.7, 0.5, 2.1],
	[Color(0.93, 0.28, 0.6, 0.7), 0.5, 0.35, 0.8, 4.0],
]
var stars: Array = []

func _setup(rng: RandomNumberGenerator) -> void:
	rng.seed = 24
	for i in range(50):
		stars.append([Vector2(rng.randf() * area.x, rng.randf() * area.y), rng.randf_range(0.6, 1.6)])

func _paint_static() -> void:
	vertical_gradient(0, area.y, Color(0.06, 0.07, 0.17), Color(0.1, 0.06, 0.2))
	for star in stars:
		draw_circle(star[0], star[1], Color(1, 1, 1, 0.45))

func _paint_fx() -> void:
	for blob in blobs:
		var phase: float = blob[4]
		var center = Vector2(area.x * (blob[2] + 0.2 * sin(time * 0.1 + phase)), area.y * (blob[3] + 0.1 * cos(time * 0.09 + phase)))
		soft_blob(fx, center, area.x * blob[1], blob[0])
