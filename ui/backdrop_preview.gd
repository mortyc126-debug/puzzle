class_name BackdropPreview
extends Control

## Мини-превью фона из коллекции «Фоны»: сам живой фон в уменьшенном виде, а поверх — поле 4×4
## в текущей теме и кубиках, чтобы было видно, как фон смотрится с блоками.
## Фон строится в «полноэкранных» единицах (ширина 900) и уменьшается — пропорции как в игре.

var backdrop_id := 0
var locked := false
var board_share := 0.6  # поле поменьше, чем в превью тем: здесь главное — фон
var _backdrop: Node2D
var _board: ThemePreview

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(150, 150)
	resized.connect(_rebuild)

func setup(new_backdrop_id: int, is_locked: bool) -> void:
	backdrop_id = new_backdrop_id
	locked = is_locked
	_rebuild()

func _rebuild() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	if _backdrop:
		_backdrop.queue_free()
		_backdrop = null
	var scene = ThemeManager.get_backdrop_scene(backdrop_id)
	if scene:
		var unit = size.x / 900.0
		_backdrop = scene.instantiate()
		_backdrop.area_override = size / unit
		_backdrop.scale = Vector2(unit, unit)
		add_child(_backdrop)
		move_child(_backdrop, 0)
	if _board == null:
		_board = ThemePreview.new()
		_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_board)
	_board.show_background = _backdrop == null
	_board.board_share = board_share
	_board.paint = ThemeManager.paint_id
	_board.set_theme_resource(ThemeManager.blocks, locked)
	queue_redraw()

func _draw() -> void:
	if _backdrop == null:
		draw_rect(Rect2(Vector2.ZERO, size), ItemsDB.get_backdrop_data(backdrop_id).get("color", ThemeManager.current.background_color))
