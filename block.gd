extends Area2D

## Фигура в лотке. Умеет только перетаскиваться: мышью на ПК и пальцем на телефоне.
## Можно ли поставить фигуру и что после этого происходит, решает Game.try_place_piece().

const TRAY_SCALE = 0.6
const TOUCH_LIFT = 1.0  # На сколько клеток фигура висит над пальцем, чтобы её было видно

var cell_size = 80
var color_index := 0
var shape: Array = []
var slot_index := 0
var slot_center := Vector2.ZERO  # Центр слота в лотке (координаты экрана)
var slot_size := Vector2(300, 250)  # Размер слота — за любое его место можно взять фигуру

var dragging := false
var drag_offset := Vector2.ZERO
var placeable := true  # Есть ли для фигуры место на поле (иначе рисуется тусклой)

var game = null
var grid_reference = null

func _ready() -> void:
	game = get_node("/root/Game")
	grid_reference = game.get_node("Grid")
	if shape.is_empty():
		shape = [Vector2(0, 0)]
	ThemeManager.theme_changed.connect(_on_theme_changed)
	return_to_tray()

func _on_theme_changed(_theme: BlockTheme) -> void:
	queue_redraw()

func get_pixel_size() -> Vector2:
	return Vector2(Shapes.get_size(shape)) * cell_size

func return_to_tray() -> void:
	dragging = false
	scale = Vector2.ONE * TRAY_SCALE
	global_position = slot_center - get_pixel_size() * TRAY_SCALE / 2.0
	z_index = 0

func set_placeable(value: bool) -> void:
	if placeable != value:
		placeable = value
		queue_redraw()

func _draw() -> void:
	var theme: BlockTheme = ThemeManager.current
	var color = ThemeManager.get_block_color(color_index)
	var alpha = 1.0 if (placeable or dragging) else 0.35
	for cell in shape:
		var rect = Rect2(cell * cell_size, Vector2(cell_size, cell_size))
		BlockRenderer.draw_block(self, rect, color, theme, alpha)

func _input(event: InputEvent) -> void:
	# Пока открыто окно или игра окончена — новые перетаскивания не начинаем
	if not dragging and is_input_blocked():
		return

	# На телефоне касание приходит ещё и как эмулированная мышь — пропускаем дубль
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	var is_press_event = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if is_press_event:
		if event.pressed:
			if not dragging and game.dragging_block == null and is_point_inside(event.position):
				start_drag(event.position, event is InputEventScreenTouch)
		elif dragging:
			finish_drag(event.position)

	elif dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		global_position = event.position - drag_offset
		update_ghost(event.position)

func is_input_blocked() -> bool:
	return game == null or game.is_input_blocked() or game.hammer_mode

# Брать фигуру можно за любое место её слота — так удобнее пальцем
func is_point_inside(point: Vector2) -> bool:
	var half = slot_size / 2.0
	return Rect2(slot_center - half, half * 2.0).has_point(point)

func start_drag(pointer: Vector2, is_touch: bool) -> void:
	dragging = true
	game.dragging_block = self
	scale = Vector2.ONE
	z_index = 10
	var size_px = get_pixel_size()
	if is_touch:
		drag_offset = Vector2(size_px.x / 2.0, size_px.y + cell_size * TOUCH_LIFT)
	else:
		drag_offset = size_px / 2.0
	global_position = pointer - drag_offset
	update_ghost(pointer)
	queue_redraw()

func finish_drag(pointer: Vector2) -> void:
	dragging = false
	game.dragging_block = null
	grid_reference.hide_ghost()
	var target = get_target_cell(pointer)
	if not game.try_place_piece(self, target.x, target.y):
		return_to_tray()
		queue_redraw()

# Клетка поля под левым верхним углом фигуры (ближайшая)
func get_target_cell(pointer: Vector2) -> Vector2i:
	var local_pos = pointer - drag_offset - grid_reference.global_position
	return Vector2i(roundi(local_pos.x / cell_size), roundi(local_pos.y / cell_size))

func update_ghost(pointer: Vector2) -> void:
	var target = get_target_cell(pointer)
	var board: Board = grid_reference.board
	if board.fits(shape, target.x, target.y):
		grid_reference.show_ghost(shape, target.x, target.y, board.can_place(shape, target.x, target.y), color_index)
	else:
		grid_reference.hide_ghost()
