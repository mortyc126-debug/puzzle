class_name BackdropBase
extends Node2D

## Основа фонов из коллекции «Фоны» (ItemsDB.backdrops_data): неподвижное рисуется один раз в
## _paint_static(), живое — в _paint_fx() на отдельном слое 20 раз в секунду (как у фонов тем).
## Размер берётся из вьюпорта: тот же фон работает и на экране игры, и в маленьком превью профиля.
## Сверху всегда лёгкое затемнение под шапкой: имя и монеты белые и должны читаться на любом фоне.

var area := Vector2(900, 1600)
var area_override := Vector2.ZERO  # задаёт превью: размер в «экранных» единицах до уменьшения
var time := 0.0
var fx: Node2D
var _since_redraw := 0.0

func _ready() -> void:
	area = area_override if area_override != Vector2.ZERO else get_viewport_rect().size
	_setup(RandomNumberGenerator.new())
	fx = Node2D.new()
	add_child(fx)
	fx.draw.connect(_paint_fx)
	var scrim = Node2D.new()
	add_child(scrim)
	scrim.draw.connect(func(): vertical_gradient(0, area.y * 0.11, Color(0, 0, 0, 0.38), Color(0, 0, 0, 0), scrim))

func _process(delta: float) -> void:
	time += delta
	_step(delta)
	_since_redraw += delta
	if _since_redraw >= 1.0 / 20.0:
		_since_redraw = 0.0
		fx.queue_redraw()

func _draw() -> void:
	_paint_static()

# Переопределяются в фонах
func _setup(_rng: RandomNumberGenerator) -> void:
	pass

func _step(_delta: float) -> void:
	pass

func _paint_static() -> void:
	pass

func _paint_fx() -> void:
	pass

# === Помощники ===

func vertical_gradient(y0: float, y1: float, c0: Color, c1: Color, canvas: CanvasItem = null) -> void:
	var target = canvas if canvas else self
	target.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(area.x, y0), Vector2(area.x, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

# Мягкое пятно — основа «меш-градиента»: одна запечённая радиальная картинка, растянутая
# и окрашенная. Дешевле десятка полупрозрачных кругов на весь экран (так было у первых фонов тем).
static var _blob_texture: Texture2D

func soft_blob(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if _blob_texture == null:
		_blob_texture = _make_blob_texture()
	canvas.draw_texture_rect(_blob_texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)

static func _make_blob_texture() -> Texture2D:
	var side = 64
	var image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for y in range(side):
		for x in range(side):
			var distance = Vector2(x + 0.5 - side / 2.0, y + 0.5 - side / 2.0).length() / (side / 2.0)
			var falloff = clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, falloff * falloff * (3.0 - 2.0 * falloff)))
	return ImageTexture.create_from_image(image)

func glint(canvas: CanvasItem, at: Vector2, arm: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -arm), at + Vector2(arm * 0.2, 0),
		at + Vector2(0, arm), at + Vector2(-arm * 0.2, 0)]), color)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-arm, 0), at + Vector2(0, arm * 0.2),
		at + Vector2(arm, 0), at + Vector2(0, -arm * 0.2)]), color)
