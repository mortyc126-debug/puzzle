extends Area2D

## Фигура в лотке. Умеет только перетаскиваться: мышью на ПК и пальцем на телефоне.
## Можно ли поставить фигуру и что после этого происходит, решает Game.try_place_piece().

const TRAY_SCALE = 0.68  # В лотке фигура меньше клеток поля (поле может быть увеличено — Game.board_scale)
const TOUCH_LIFT = 1.0  # На сколько клеток фигура висит над пальцем, чтобы её было видно

var cell_size = 80
var color_index := 0
var shape: Array = []
var slot_index := 0
var slot_center := Vector2.ZERO  # Центр слота в лотке (координаты экрана)
var slot_size := Vector2(300, 250)  # Размер слота — за любое его место можно взять фигуру

var dragging := false
var drag_offset := Vector2.ZERO
var touch_index := -1  # Палец, который держит фигуру (-1 — мышь). Остальные касания не мешают
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

# slot_center — в координатах сцены Game (она сдвигается к центру длинного экрана)
func board_scale() -> float:
	return game.board_scale if game != null else 1.0

func return_to_tray() -> void:
	dragging = false
	var tray_scale = TRAY_SCALE * board_scale()
	scale = Vector2.ONE * tray_scale
	position = slot_center - get_pixel_size() * tray_scale / 2.0
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
		var index = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if game.rotate_mode:
				# Режим поворота: нажатие поворачивает фигуру, а не берёт её
				if is_point_inside(event.position):
					game.rotate_block(self)
			elif not dragging and game.dragging_block == null and is_point_inside(event.position):
				start_drag(event.position, index)
		elif dragging and index == touch_index:
			if event is InputEventScreenTouch and event.canceled:
				# Касание отменила система (шторка, жест) — фигура возвращается, а не ставится
				cancel_drag()
			else:
				finish_drag(event.position)

	elif dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var index = event.index if event is InputEventScreenDrag else -1
		if index == touch_index:
			global_position = event.position - drag_offset
			update_ghost(event.position)

func is_input_blocked() -> bool:
	return game == null or game.is_input_blocked() or game.hammer_mode

# Брать фигуру можно за любое место её слота — так удобнее пальцем
func is_point_inside(point: Vector2) -> bool:
	var half = slot_size / 2.0
	return Rect2(slot_center - half, half * 2.0).has_point(game.to_local(point))

func start_drag(pointer: Vector2, index: int) -> void:
	var is_touch = index >= 0
	dragging = true
	touch_index = index
	game.dragging_block = self
	# В руке фигура того же размера, что и клетки поля
	scale = Vector2.ONE * board_scale()
	z_index = 10
	var size_px = get_pixel_size() * board_scale()
	if is_touch:
		drag_offset = Vector2(size_px.x / 2.0, size_px.y + cell_size * board_scale() * TOUCH_LIFT)
	else:
		drag_offset = size_px / 2.0
	global_position = pointer - drag_offset
	update_ghost(pointer)
	queue_redraw()

func finish_drag(pointer: Vector2) -> void:
	dragging = false
	touch_index = -1
	game.dragging_block = null
	grid_reference.hide_ghost()
	var target = get_target_cell(pointer)
	if not game.try_place_piece(self, target.x, target.y):
		# Над полем, но места нет — тихий «бум»; брошенная мимо поля фигура просто возвращается
		if grid_reference.board.fits(shape, target.x, target.y):
			Sfx.play("invalid")
		return_to_tray()
		queue_redraw()

# Фигура возвращается в лоток без попытки поставить (сворачивание игры, «Назад»)
func cancel_drag() -> void:
	if not dragging:
		return
	touch_index = -1
	game.dragging_block = null
	grid_reference.hide_ghost()
	return_to_tray()
	queue_redraw()

# Клетка поля под левым верхним углом фигуры (ближайшая)
func get_target_cell(pointer: Vector2) -> Vector2i:
	var local_pos = pointer - drag_offset - grid_reference.global_position
	var cell_px = cell_size * board_scale()
	return Vector2i(roundi(local_pos.x / cell_px), roundi(local_pos.y / cell_px))

func update_ghost(pointer: Vector2) -> void:
	var target = get_target_cell(pointer)
	var board: Board = grid_reference.board
	if board.fits(shape, target.x, target.y):
		grid_reference.show_ghost(shape, target.x, target.y, board.can_place(shape, target.x, target.y), color_index)
	else:
		grid_reference.hide_ghost()
