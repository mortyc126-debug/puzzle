extends Area2D

var cell_size = 80
var color = Color.ROYAL_BLUE
var dragging = false
var drag_offset = Vector2.ZERO
var original_position = Vector2.ZERO
var grid_reference = null
var slot_index = 0  # Номер слота внизу экрана (0-2)

# Форма блока
var shape = []

func _ready():
	original_position = global_position
	grid_reference = get_node("/root/Game/Grid")
	
	if shape.is_empty():
		shape = [Vector2(0, 0)]

func _draw():
	for cell in shape:
		var cell_pos = cell * cell_size
		var rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
		
		# Тень
		var shadow_rect = rect.grow(-2)
		shadow_rect.position += Vector2(2, 2)
		draw_rect(shadow_rect, color.darkened(0.3))
		
		# Основной блок
		draw_rect(rect, color)
		
		# Блик
		var highlight_rect = Rect2(rect.position, Vector2(rect.size.x, rect.size.y / 2))
		draw_rect(highlight_rect, color.lightened(0.2))
		
		# Белая обводка
		draw_rect(rect, Color.WHITE, false, 3)

func _input(event):
	# Пока открыто окно или игра окончена — новые перетаскивания не начинаем
	if not dragging and is_input_blocked():
		return
	
	# На телефоне касание приходит ещё и как эмулированная мышь — пропускаем дубль
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	
	# === НАЖАТИЕ / ОТПУСКАНИЕ (мышь на ПК, палец на телефоне) ===
	var is_press_event = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if is_press_event:
		if event.pressed:
			if not dragging and is_point_inside(event.position):
				dragging = true
				# Запоминаем, за какую точку взяли блок
				drag_offset = event.position - global_position
				z_index = 10  # Поверх остальных блоков
		elif dragging:
			dragging = false
			z_index = 0
			
			# Скрываем Ghost
			if grid_reference != null:
				grid_reference.hide_ghost()
			
			# Пытаемся разместить блок
			try_place_on_grid(event.position)
	
	# === ПЕРЕТАСКИВАНИЕ ===
	elif dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		# Блок следует за пальцем, сохраняя точку захвата
		global_position = event.position - drag_offset
		update_ghost(event.position)

# Клетка сетки, куда встанет левый верхний угол блока (ближайшая к его текущей позиции)
func get_target_cell(pointer_pos: Vector2) -> Vector2i:
	var local_pos = pointer_pos - drag_offset - grid_reference.global_position
	return Vector2i(roundi(local_pos.x / cell_size), roundi(local_pos.y / cell_size))

# Помещается ли блок в сетку целиком (без учёта занятых клеток)
func fits_in_grid(target: Vector2i) -> bool:
	for cell in shape:
		var check_x = target.x + int(cell.x)
		var check_y = target.y + int(cell.y)
		if check_x < 0 or check_x >= grid_reference.GRID_SIZE or check_y < 0 or check_y >= grid_reference.GRID_SIZE:
			return false
	return true

# Можно ли поставить блок в эту позицию
func can_place_at(target: Vector2i) -> bool:
	for cell in shape:
		if not grid_reference.is_cell_empty(target.x + int(cell.x), target.y + int(cell.y)):
			return false
	return true

# Показывает Ghost, если блок над сеткой
func update_ghost(pointer_pos: Vector2):
	if grid_reference == null:
		return
	
	var target = get_target_cell(pointer_pos)
	if fits_in_grid(target):
		grid_reference.show_ghost(shape, target.x, target.y, can_place_at(target))
	else:
		grid_reference.hide_ghost()

func is_input_blocked() -> bool:
	var game = get_node_or_null("/root/Game")
	return game != null and game.is_input_blocked()

func is_point_inside(point: Vector2) -> bool:
	for cell in shape:
		var cell_global_pos = global_position + cell * cell_size
		var rect = Rect2(cell_global_pos, Vector2(cell_size, cell_size))
		if rect.has_point(point):
			return true
	return false

func try_place_on_grid(pointer_pos: Vector2):
	if grid_reference == null:
		return
	
	var grid_pos = grid_reference.global_position
	var target = get_target_cell(pointer_pos)
	var grid_x = target.x
	var grid_y = target.y
	
	# Проверяем, можем ли разместить
	var can_place = can_place_at(target)
	
	if can_place:
		# Блок поставлен — больше не реагирует на касания и не участвует в проверке Game Over
		set_process_input(false)
		var game = get_node("/root/Game")
		game.active_blocks.erase(self)
		
		var placed_cells = []
		for cell in shape:
			var place_x = grid_x + int(cell.x)
			var place_y = grid_y + int(cell.y)
			placed_cells.append(Vector2(place_x, place_y))
		
		# Размещаем блок
		for cell in placed_cells:
			grid_reference.place_block(int(cell.x), int(cell.y), color)
		
		global_position = grid_pos + Vector2(grid_x * cell_size, grid_y * cell_size)
		print("Блок размещён!")
		
		# Звук
		var sound_place = get_node("/root/Game/SoundPlace")
		if sound_place:
			sound_place.play()
		
		# Очистка линий
		var lines_found = grid_reference.check_and_clear_lines()
		
		# Сохраняем ход для Undo. Ход с очисткой линий отменить нельзя:
		# очки и XP за линии уже начислены
		if lines_found == 0:
			game.last_move = {
				"cells": placed_cells,
				"color": color,
				"slot": slot_index
			}
		else:
			game.last_move = null
		
		game.update_powerup_buttons()
		
		await get_tree().create_timer(0.2).timeout
		
		queue_free()
	else:
		# Возвращаем блок
		global_position = original_position
		print("Не могу разместить блок")
