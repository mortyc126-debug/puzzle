extends BackdropBase

## «Тёплый градиент»: модный меш-градиент — коралловое, персиковое, золотое и голубое пятна
## медленно плывут друг сквозь друга (палитра заката #FF6B6B, #FF9F68, #FFD56B, #5AA9FF),
## снизу закат темнеет до сливового — белые надписи читаются.

var blobs := [
	[Color(1.0, 0.42, 0.42, 0.9), 0.55, 0.2, 0.3, 0.0],
	[Color(1.0, 0.62, 0.41, 0.9), 0.5, 0.75, 0.55, 1.6],
	[Color(1.0, 0.84, 0.42, 0.85), 0.45, 0.3, 0.75, 3.1],
	[Color(0.35, 0.66, 1.0, 0.7), 0.4, 0.8, 0.15, 4.4],
]

func _paint_static() -> void:
	vertical_gradient(0, area.y * 0.55, Color(0.95, 0.5, 0.45), Color(0.85, 0.36, 0.5))
	vertical_gradient(area.y * 0.55, area.y, Color(0.85, 0.36, 0.5), Color(0.42, 0.16, 0.42))

func _paint_fx() -> void:
	for blob in blobs:
		var phase: float = blob[4]
		var center = Vector2(area.x * (blob[2] + 0.2 * sin(time * 0.3 + phase)), area.y * (blob[3] + 0.14 * cos(time * 0.24 + phase)))
		soft_blob(fx, center, area.x * blob[1], blob[0])
