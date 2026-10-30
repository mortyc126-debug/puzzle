extends Node2D

## Вид поля: рисует Board в текущей теме, Ghost (куда встанет фигура), подсветку линий,
## которые очистятся, и вспышки очистки. Логики игры здесь нет — её ведёт Game.

signal cell_tapped(x: int, y: int)

const GRID_SIZE = Board.SIZE
const CELL_SIZE = 80
const FLASH_TIME = 0.28

var board := Board.new()

# Ghost Preview
var ghost_active = false
var ghost_shape = []
var ghost_position = Vector2i(-1, -1)
var ghost_valid = false
var ghost_color_index = 0
var ghost_lines = {"rows": [], "cols": []}

# Вспышки очищенных клеток: [{"pos": Vector2i, "color": int, "time": float}]
var flashes: Array = []

func _ready() -> void:
	ThemeManager.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(_theme: BlockTheme) -> void:
	queue_redraw()

func get_pixel_size() -> Vector2:
	return Vector2(GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)

func cell_rect(x: int, y: int) -> Rect2:
	return Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)

func _process(delta: float) -> void:
	if flashes.is_empty():
		return
	for flash in flashes:
		flash["time"] += delta
	flashes = flashes.filter(func(flash): return flash["time"] < FLASH_TIME)
	queue_redraw()

func _draw() -> void:
	var theme: BlockTheme = ThemeManager.current
	BlockRenderer.draw_board(self, Rect2(Vector2.ZERO, get_pixel_size()), theme)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var value = board.get_cell(x, y)
			if value == Board.EMPTY:
				BlockRenderer.draw_empty_cell(self, cell_rect(x, y), theme)
			else:
				BlockRenderer.draw_block(self, cell_rect(x, y), ThemeManager.get_block_color(value), theme)

	if ghost_active:
		# Линии, которые очистятся после постановки
		for row in ghost_lines["rows"]:
			draw_rect(Rect2(0, row * CELL_SIZE, GRID_SIZE * CELL_SIZE, CELL_SIZE), theme.line_highlight_color)
		for col in ghost_lines["cols"]:
			draw_rect(Rect2(col * CELL_SIZE, 0, CELL_SIZE, GRID_SIZE * CELL_SIZE), theme.line_highlight_color)

		for cell in ghost_shape:
			var x = ghost_position.x + int(cell.x)
			var y = ghost_position.y + int(cell.y)
			if not board.in_bounds(x, y):
				continue
			if ghost_valid:
				BlockRenderer.draw_block(self, cell_rect(x, y), ThemeManager.get_block_color(ghost_color_index), theme, 0.4)
			else:
				draw_rect(cell_rect(x, y).grow(-4), theme.ghost_invalid_color)

	for flash in flashes:
		var t = flash["time"] / FLASH_TIME
		var pos: Vector2i = flash["pos"]
		BlockRenderer.draw_flash(self, cell_rect(pos.x, pos.y), ThemeManager.get_block_color(flash["color"]), theme, t)

# === GHOST PREVIEW ===

func show_ghost(shape: Array, grid_x: int, grid_y: int, is_valid: bool, color_index: int) -> void:
	var position_changed = not ghost_active or ghost_position != Vector2i(grid_x, grid_y) or ghost_valid != is_valid
	ghost_active = true
	ghost_shape = shape
	ghost_position = Vector2i(grid_x, grid_y)
	ghost_valid = is_valid
	ghost_color_index = color_index
	if position_changed:
		ghost_lines = {"rows": [], "cols": []}
		if is_valid:
			var preview = board.duplicate_board()
			preview.place(shape, grid_x, grid_y, color_index)
			ghost_lines = preview.find_full_lines()
		queue_redraw()

func hide_ghost() -> void:
	if ghost_active:
		ghost_active = false
		ghost_lines = {"rows": [], "cols": []}
		queue_redraw()

# === ЭФФЕКТЫ ОЧИСТКИ ===

# cleared — результат Board.clear_lines(), lines — результат Board.find_full_lines()
func play_clear_effect(cleared: Array, lines: Dictionary) -> void:
	for item in cleared:
		flashes.append({"pos": item["pos"], "color": item["color"], "time": 0.0})
	spawn_clear_particles(lines)
	queue_redraw()

func spawn_clear_particles(lines: Dictionary) -> void:
	var particles = get_node_or_null("ClearParticles")
	if particles == null:
		return

	var centers = []
	for row in lines["rows"]:
		centers.append(Vector2(GRID_SIZE * CELL_SIZE / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0))
	for col in lines["cols"]:
		centers.append(Vector2(col * CELL_SIZE + CELL_SIZE / 2.0, GRID_SIZE * CELL_SIZE / 2.0))

	for center in centers:
		var new_particles = particles.duplicate()
		add_child(new_particles)
		new_particles.position = center
		new_particles.modulate = ThemeManager.current.particle_color
		new_particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(new_particles.queue_free)

# === МОЛОТОК: нажатие по клетке ===

func _input(event: InputEvent) -> void:
	var game = get_parent()
	if game == null or not game.hammer_mode or game.is_input_blocked():
		return
	if (event is InputEventMouseButton) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	var pressed = false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return

	var local_pos = to_local(event.position)
	var grid_x = int(floor(local_pos.x / CELL_SIZE))
	var grid_y = int(floor(local_pos.y / CELL_SIZE))
	if board.in_bounds(grid_x, grid_y):
		cell_tapped.emit(grid_x, grid_y)
