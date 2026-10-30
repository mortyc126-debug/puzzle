extends Node2D

const GRID_SIZE = 8
const CELL_SIZE = 80  # было 100, стало 80
const GRID_COLOR = Color(0.2, 0.2, 0.25)
const LINE_COLOR = Color(0.4, 0.4, 0.45)

# Ghost Preview
var ghost_active = false
var ghost_shape = []
var ghost_position = Vector2(-1, -1)
var ghost_valid = false  # Можно ли разместить

var grid_data = []
var block_colors = []  # Массив для хранения цветов блоков

signal lines_cleared(count)  # Сигнал для уведомления об очищенных линиях

func _ready():
	for y in range(GRID_SIZE):
		var row = []
		var color_row = []
		for x in range(GRID_SIZE):
			row.append(0)
			color_row.append(Color.TRANSPARENT)
		grid_data.append(row)
		block_colors.append(color_row)
	
	var total_grid_size = GRID_SIZE * CELL_SIZE
	var screen_center_x = 900 / 2.0
	var screen_center_y = 960 / 2.0
	
	position = Vector2(
		screen_center_x - total_grid_size / 2.0,
		screen_center_y - total_grid_size / 2.0
	)

func _draw():
	var grid_rect = Rect2(0, 0, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	draw_rect(grid_rect, GRID_COLOR)
	
	# Рисуем занятые клетки с их цветами
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if grid_data[y][x] == 1:
				var cell_rect = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
				draw_rect(cell_rect, block_colors[y][x])
				draw_rect(cell_rect, Color.WHITE, false, 3)
	
	# === РИСУЕМ GHOST PREVIEW ===
	if ghost_active and ghost_position.x >= 0:
		var ghost_color = Color(0, 1, 0, 0.3) if ghost_valid else Color(1, 0, 0, 0.3)  # Зелёный или красный
		
		for cell in ghost_shape:
			var draw_x = int(ghost_position.x + cell.x)
			var draw_y = int(ghost_position.y + cell.y)
			
			# Проверяем границы
			if draw_x >= 0 and draw_x < GRID_SIZE and draw_y >= 0 and draw_y < GRID_SIZE:
				var cell_rect = Rect2(draw_x * CELL_SIZE, draw_y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
				draw_rect(cell_rect, ghost_color)  # Полупрозрачный
				draw_rect(cell_rect, ghost_color.lightened(0.3), false, 3)  # Обводка
	
	# Рисуем линии сетки
	for i in range(GRID_SIZE + 1):
		var x = i * CELL_SIZE
		draw_line(Vector2(x, 0), Vector2(x, GRID_SIZE * CELL_SIZE), LINE_COLOR, 2)
		
		var y = i * CELL_SIZE
		draw_line(Vector2(0, y), Vector2(GRID_SIZE * CELL_SIZE, y), LINE_COLOR, 2)

# Проверяет, свободна ли клетка
func is_cell_empty(x: int, y: int) -> bool:
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE:
		return false
	return grid_data[y][x] == 0

# Размещает блок на сетке
func place_block(x: int, y: int, block_color: Color):
	if is_cell_empty(x, y):
		grid_data[y][x] = 1
		block_colors[y][x] = block_color  # Сохраняем цвет
		queue_redraw()

# Проверяет и очищает заполненные ряды и колонки.
# Возвращает количество найденных линий (сама очистка идёт с анимацией).
func check_and_clear_lines() -> int:
	var lines_to_clear = []
	
	# Проверяем все горизонтальные ряды
	for y in range(GRID_SIZE):
		var full = true
		for x in range(GRID_SIZE):
			if grid_data[y][x] == 0:
				full = false
				break
		if full:
			lines_to_clear.append({"type": "row", "index": y})
	
	# Проверяем все вертикальные колонки
	for x in range(GRID_SIZE):
		var full = true
		for y in range(GRID_SIZE):
			if grid_data[y][x] == 0:
				full = false
				break
		if full:
			lines_to_clear.append({"type": "col", "index": x})
	
	# Если есть линии для очистки — запускаем анимацию
	if lines_to_clear.size() > 0:
		animate_clear_lines(lines_to_clear)
	
	return lines_to_clear.size()

# Анимация очистки линий
func animate_clear_lines(lines_to_clear):
	# Создаём Tween для анимации
	var tween = create_tween()
	tween.set_parallel(true)  # Все анимации одновременно
	
	# Сначала "подсвечиваем" линии (делаем их белыми)
	for line in lines_to_clear:
		if line["type"] == "row":
			var y = line["index"]
			for x in range(GRID_SIZE):
				block_colors[y][x] = Color.WHITE
		else:
			var x = line["index"]
			for y in range(GRID_SIZE):
				block_colors[y][x] = Color.WHITE
	
	queue_redraw()
	
	# Ждём 0.15 секунды
	await get_tree().create_timer(0.15).timeout
	
	# Очищаем линии
	for line in lines_to_clear:
		if line["type"] == "row":
			clear_row(line["index"])
		else:
			clear_column(line["index"])
	
	# ЗАПУСКАЕМ PARTICLE EFFECTS
	spawn_clear_particles(lines_to_clear)
	
	queue_redraw()
	lines_cleared.emit(lines_to_clear.size())
	print("Очищено линий: ", lines_to_clear.size())

# Очищает горизонтальный ряд
func clear_row(y: int):
	for x in range(GRID_SIZE):
		grid_data[y][x] = 0
		block_colors[y][x] = Color.TRANSPARENT

# Очищает вертикальную колонку
func clear_column(x: int):
	for y in range(GRID_SIZE):
		grid_data[y][x] = 0
		block_colors[y][x] = Color.TRANSPARENT

# Проверяет, можно ли разместить блок с данной формой где-либо на сетке
func can_place_shape(shape: Array) -> bool:
	# Перебираем все возможные позиции на сетке
	for start_y in range(GRID_SIZE):
		for start_x in range(GRID_SIZE):
			# Проверяем, можно ли разместить блок начиная с этой позиции
			var can_place = true
			for cell in shape:
				var check_x = start_x + int(cell.x)
				var check_y = start_y + int(cell.y)
				
				if not is_cell_empty(check_x, check_y):
					can_place = false
					break
			
			# Если нашли хотя бы одну подходящую позицию — блок можно разместить
			if can_place:
				return true
	
	# Не нашли ни одной подходящей позиции
	return false

# Создаёт particle effects для очищенных линий
func spawn_clear_particles(lines_to_clear):
	for line in lines_to_clear:
		var particles = get_node_or_null("ClearParticles")
		if particles == null:
			return
		
		# Вычисляем центр линии
		var center_pos = Vector2.ZERO
		
		if line["type"] == "row":
			var y = line["index"]
			center_pos = Vector2(GRID_SIZE * CELL_SIZE / 2, y * CELL_SIZE + CELL_SIZE / 2)
		else:
			var x = line["index"]
			center_pos = Vector2(x * CELL_SIZE + CELL_SIZE / 2, GRID_SIZE * CELL_SIZE / 2)
		
		# Создаём копию частиц для каждой линии
		var new_particles = particles.duplicate()
		add_child(new_particles)
		new_particles.position = center_pos
		new_particles.emitting = true
		
		# Удаляем частицы через 1 секунду (после завершения анимации)
		await get_tree().create_timer(1.0).timeout
		new_particles.queue_free()

# Обработка кликов для Hammer
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Получаем ссылку на Game
			var game = get_parent()
			if game == null:
				return
			
			# Проверяем, есть ли переменная hammer_mode
			if not "hammer_mode" in game:
				return
			
			# Проверяем, активен ли режим молотка
			if game.hammer_mode and not game.is_input_blocked():
				# Вычисляем координаты клетки относительно сетки
				var mouse_global = get_global_mouse_position()
				var local_pos = mouse_global - global_position
				var grid_x = int(local_pos.x / CELL_SIZE)
				var grid_y = int(local_pos.y / CELL_SIZE)
				
				print("DEBUG: Клик по позиции сетки: ", grid_x, ", ", grid_y)
				
				# Проверяем границы
				if grid_x >= 0 and grid_x < GRID_SIZE and grid_y >= 0 and grid_y < GRID_SIZE:
					game.use_hammer_on_cell(grid_x, grid_y)
				else:
					print("DEBUG: Клик вне границ сетки")

# === GHOST PREVIEW ===

func show_ghost(shape: Array, grid_x: int, grid_y: int, is_valid: bool):
	ghost_active = true
	ghost_shape = shape
	ghost_position = Vector2(grid_x, grid_y)
	ghost_valid = is_valid
	queue_redraw()

func hide_ghost():
	ghost_active = false
	queue_redraw()
