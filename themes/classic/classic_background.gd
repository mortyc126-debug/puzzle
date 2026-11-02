extends Node2D

## Живой слой фона «Классики» поверх фирменной картинки: медленно всплывающие полупрозрачные
## блоки и два мягких пятна света. Классика — первая тема, которую видит игрок, и без движения
## она смотрелась скучнее остальных. Слой перерисовывается 20 раз в секунду, как у других тем.

@export var block_count := 18
@export var colors := PackedColorArray([
	Color(0.45, 0.6, 1.0), Color(1.0, 0.5, 0.75), Color(1.0, 0.85, 0.35),
	Color(0.45, 0.95, 0.7), Color(0.75, 0.55, 1.0),
])

var _area := Vector2(900, 1600)
var _blocks: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(block_count):
		_blocks.append({
			"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y),
			"speed": rng.randf_range(10.0, 26.0),
			"size": rng.randf_range(26.0, 74.0),
			"angle": rng.randf() * TAU,
			"spin": rng.randf_range(-0.25, 0.25),
			"phase": rng.randf() * TAU,
			"color": colors[i % colors.size()],
			"alpha": rng.randf_range(0.07, 0.15),
		})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_layer)

func _process(delta: float) -> void:
	_time += delta
	for block in _blocks:
		var pos: Vector2 = block["pos"]
		pos.y -= block["speed"] * delta
		pos.x += sin(_time * 0.35 + block["phase"]) * 6.0 * delta
		if pos.y < -90.0:
			pos.y = _area.y + 90.0
			pos.x = fposmod(pos.x + 263.0, _area.x)
		block["pos"] = pos
		block["angle"] += block["spin"] * delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw_layer() -> void:
	# Мягкие пятна света медленно плавают по экрану
	_glow(Vector2(_area.x * (0.3 + 0.12 * sin(_time * 0.11)), _area.y * (0.28 + 0.05 * cos(_time * 0.09))),
		_area.x * 0.42, Color(0.55, 0.6, 1.0))
	_glow(Vector2(_area.x * (0.72 + 0.1 * cos(_time * 0.08)), _area.y * (0.72 + 0.06 * sin(_time * 0.1))),
		_area.x * 0.38, Color(1.0, 0.5, 0.8))
	for block in _blocks:
		var size: float = block["size"]
		var color: Color = block["color"]
		var alpha: float = block["alpha"] * (0.75 + 0.25 * sin(_time * 0.6 + block["phase"]))
		_fx.draw_set_transform(block["pos"], block["angle"], Vector2.ONE)
		var rect = Rect2(-size / 2.0, -size / 2.0, size, size)
		_fx.draw_rect(rect, Color(color, alpha))
		# Блик сверху — как у блоков на поле
		_fx.draw_rect(Rect2(rect.position + Vector2(size * 0.12, size * 0.1), Vector2(size * 0.76, size * 0.16)),
			Color(1, 1, 1, alpha * 0.9))
		_fx.draw_rect(rect, Color(1, 1, 1, alpha * 1.2), false, 2.0)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _glow(center: Vector2, radius: float, color: Color) -> void:
	for k in range(6):
		var t = 1.0 - k / 6.0
		_fx.draw_circle(center, radius * t, Color(color, 0.022))
