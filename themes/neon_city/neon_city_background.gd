extends Node2D

## Фон темы «Неоновый город»: ночное фиолетовое небо, два ряда небоскрёбов с окнами,
## неоновые вывески, мокрая улица с отражениями и дождь. Город — один раз; дождь и мигание
## вывесок — на отдельном слое 20 раз в секунду.

@export var top_color := Color(0.06, 0.02, 0.15)
@export var horizon_color := Color(0.38, 0.08, 0.42)
@export var street_color := Color(0.05, 0.02, 0.1)
@export var drop_count := 70

const SIGNS = [
	[0.12, 0.44, 0.2, 0.05, Color(1.0, 0.25, 0.75)],
	[0.66, 0.38, 0.14, 0.07, Color(0.2, 0.95, 1.0)],
	[0.4, 0.55, 0.16, 0.04, Color(0.75, 0.4, 1.0)],
	[0.8, 0.58, 0.12, 0.05, Color(1.0, 0.75, 0.2)],
]

var _area := Vector2(900, 1600)
var _drops: Array = []
var _fx: Node2D
var _since_redraw := 0.0
var _time := 0.0

func _ready() -> void:
	_area = get_viewport_rect().size
	var rng = RandomNumberGenerator.new()
	rng.seed = 92
	for i in range(drop_count):
		_drops.append({"pos": Vector2(rng.randf() * _area.x, rng.randf() * _area.y), "speed": rng.randf_range(700.0, 1000.0),
			"length": rng.randf_range(14.0, 30.0)})
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func _process(delta: float) -> void:
	_time += delta
	for drop in _drops:
		var pos: Vector2 = drop["pos"]
		pos += Vector2(-0.18, 1.0) * drop["speed"] * delta
		if pos.y > _area.y:
			pos.y = -30
			pos.x = fposmod(pos.x + 211.0, _area.x)
		if pos.x < -20:
			pos.x += _area.x + 40
		drop["pos"] = pos
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		_fx.queue_redraw()

func _draw() -> void:
	var w = _area.x
	var h = _area.y
	_gradient(0.0, h * 0.62, top_color, horizon_color)
	_gradient(h * 0.62, h, Color(0.12, 0.03, 0.2), street_color)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9
	# Дальний ряд: светлее, окна мельче
	_skyline(rng, h * 0.64, h * 0.32, 60.0, 120.0, Color(0.16, 0.06, 0.28), 0.35)
	# Ближний ряд: темнее, окна крупнее
	_skyline(rng, h * 0.7, h * 0.42, 90.0, 170.0, Color(0.07, 0.02, 0.13), 0.55)
	# Отражения вывесок на мокрой улице
	for neon_sign in SIGNS:
		var x = w * neon_sign[0]
		draw_rect(Rect2(x, h * 0.72, w * neon_sign[2], h * 0.26), Color(neon_sign[4], 0.07))
		for k in range(6):
			draw_rect(Rect2(x + w * neon_sign[2] * 0.1, h * (0.74 + k * 0.035), w * neon_sign[2] * 0.8, 3), Color(neon_sign[4], 0.22 - k * 0.03))

func _gradient(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w = _area.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

func _skyline(rng: RandomNumberGenerator, base_y: float, max_h: float, min_w: float, max_w: float, color: Color,
		window_alpha: float) -> void:
	var x = -20.0
	while x < _area.x + 20:
		var bw = rng.randf_range(min_w, max_w)
		var bh = rng.randf_range(max_h * 0.4, max_h)
		draw_rect(Rect2(x, base_y - bh, bw, bh + _area.y * 0.1), color)
		if rng.randf() < 0.4:
			draw_rect(Rect2(x + bw * 0.45, base_y - bh - 30, 4, 30), color)  # антенна
		var win = 7.0 + min_w * 0.03
		var y = base_y - bh + 14
		while y < base_y - 10:
			var wx = x + 8
			while wx < x + bw - 10:
				if rng.randf() < 0.42:
					var tint = Color(1, 0.85, 0.5) if rng.randf() < 0.6 else Color(0.5, 0.95, 1)
					draw_rect(Rect2(wx, y, win, win * 1.2), Color(tint, window_alpha * rng.randf_range(0.5, 1.0)))
				wx += win * 2.0
			y += win * 2.4
		x += bw + rng.randf_range(2.0, 12.0)

func _draw_fx() -> void:
	var w = _area.x
	var h = _area.y
	# Вывески: свечение и мигание (одна иногда гаснет, как у старой лампы)
	for i in range(SIGNS.size()):
		var neon_sign = SIGNS[i]
		var on = 1.0
		if i == 2 and fposmod(_time, 4.0) > 3.6:
			on = 0.25
		var rect = Rect2(w * neon_sign[0], h * neon_sign[1], w * neon_sign[2], h * neon_sign[3])
		var color: Color = neon_sign[4]
		_fx.draw_rect(rect.grow(10), Color(color, 0.1 * on))
		_fx.draw_rect(rect, Color(color, 0.85 * on), false, 4.0)
		_fx.draw_rect(rect.grow(-6), Color(color.lightened(0.6), 0.9 * on), false, 2.0)
		for k in range(3):
			var lx = rect.position.x + rect.size.x * (0.2 + k * 0.25)
			_fx.draw_line(Vector2(lx, rect.position.y + rect.size.y * 0.35), Vector2(lx + rect.size.x * 0.15, rect.position.y + rect.size.y * 0.35),
				Color(color.lightened(0.5), on), 3.0)
	for drop in _drops:
		var pos: Vector2 = drop["pos"]
		_fx.draw_line(pos, pos + Vector2(0.18, -1.0) * drop["length"], Color(0.75, 0.85, 1, 0.28), 1.6)
