extends Area2D

var cell_size = 80
var color = Color.ROYAL_BLUE
var dragging = false
var drag_offset = Vector2.ZERO
var original_position = Vector2.ZERO
var grid_reference = null

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
	# === МЫШЬ (ПК) ===
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				if is_point_inside(mouse_pos):
					dragging = true
					drag_offset = get_global_mouse_position() - global_position
					
					# Скрываем Ghost при начале перетаскивания
					if grid_reference != null:
						grid_reference.hide_ghost()
			else:
				if dragging:
					dragging = false
					
					# Скрываем Ghost
					if grid_reference != null:
						grid_reference.hide_ghost()
					
					# Пытаемся разместить блок
					try_place_on_grid()
	
	elif event is InputEventMouseMotion and dragging:
		# СНЭП К СЕТКЕ
		if grid_reference != null:
			var mouse_pos = get_global_mouse_position()
			var local_pos = mouse_pos - grid_reference.global_position
			var grid_x = int(local_pos.x / cell_size)
			var grid_y = int(local_pos.y / cell_size)
			
			# Привязываем блок к сетке
			global_position = grid_reference.global_position + Vector2(grid_x * cell_size, grid_y * cell_size)
			
			# Проверяем, можно ли разместить
			var can_place = true
			for cell in shape:
				var check_x = grid_x + int(cell.x)
				var check_y = grid_y + int(cell.y)
				
				if check_x < 0 or check_x >= 8 or check_y < 0 or check_y >= 8:
					can_place = false
					break
				
				if grid_reference.grid_data[check_y][check_x] != 0:
					can_place = false
					break
			
			# Показываем Ghost
			grid_reference.show_ghost(shape, grid_x, grid_y, can_place)
		else:
			global_position = get_global_mouse_position() - drag_offset
	
	# === ТАЧСКРИН (МОБИЛКА) ===
	elif event is InputEventScreenTouch:
		if event.pressed:
			var touch_pos = event.position
			if is_point_inside(touch_pos):
				dragging = true
				drag_offset = touch_pos - global_position
				
				# Скрываем Ghost
				if grid_reference != null:
					grid_reference.hide_ghost()
		else:
			if dragging:
				dragging = false
				
				# Скрываем Ghost
				if grid_reference != null:
					grid_reference.hide_ghost()
				
				try_place_on_grid()
	
	elif event is InputEventScreenDrag and dragging:
		# СНЭП К СЕТКЕ
		if grid_reference != null:
			var touch_pos = event.position
			var local_pos = touch_pos - grid_reference.global_position
			var grid_x = int(local_pos.x / cell_size)
			var grid_y = int(local_pos.y / cell_size)
			
			# Привязываем блок к сетке
			global_position = grid_reference.global_position + Vector2(grid_x * cell_size, grid_y * cell_size)
			
			# Проверяем, можно ли разместить
			var can_place = true
			for cell in shape:
				var check_x = grid_x + int(cell.x)
				var check_y = grid_y + int(cell.y)
				
				if check_x < 0 or check_x >= 8 or check_y < 0 or check_y >= 8:
					can_place = false
					break
				
				if grid_reference.grid_data[check_y][check_x] != 0:
					can_place = false
					break
			
			# Показываем Ghost
			grid_reference.show_ghost(shape, grid_x, grid_y, can_place)
		else:
			global_position = event.position - drag_offset

func is_point_inside(point: Vector2) -> bool:
	for cell in shape:
		var cell_global_pos = global_position + cell * cell_size
		var rect = Rect2(cell_global_pos, Vector2(cell_size, cell_size))
		if rect.has_point(point):
			return true
	return false

func try_place_on_grid():
	if grid_reference == null:
		return
	
	var grid_pos = grid_reference.global_position
	var mouse_pos = get_global_mouse_position()
	
	var relative_pos = mouse_pos - grid_pos
	var grid_x = int(relative_pos.x / cell_size)
	var grid_y = int(relative_pos.y / cell_size)
	
	# Проверяем, можем ли разместить
	var can_place = true
	for cell in shape:
		var check_x = grid_x + int(cell.x)
		var check_y = grid_y + int(cell.y)
		
		if not grid_reference.is_cell_empty(check_x, check_y):
			can_place = false
			break
	
	if can_place:
		# Сохраняем ход для Undo
		var game = get_node("/root/Game")
		var placed_cells = []
		for cell in shape:
			var place_x = grid_x + int(cell.x)
			var place_y = grid_y + int(cell.y)
			placed_cells.append(Vector2(place_x, place_y))
		
		game.last_move = {
			"cells": placed_cells,
			"color": color
		}
		
		game.update_powerup_buttons()
		
		# Размещаем блок
		for cell in shape:
			var place_x = grid_x + int(cell.x)
			var place_y = grid_y + int(cell.y)
			grid_reference.place_block(place_x, place_y, color)
		
		global_position = grid_pos + Vector2(grid_x * cell_size, grid_y * cell_size)
		print("Блок размещён!")
		
		# Звук
		var sound_place = get_node("/root/Game/SoundPlace")
		if sound_place:
			sound_place.play()
		
		# Очистка линий
		grid_reference.check_and_clear_lines()
		
		await get_tree().create_timer(0.2).timeout
		
		queue_free()
	else:
		# Возвращаем блок
		global_position = original_position
		print("Не могу разместить блок")
