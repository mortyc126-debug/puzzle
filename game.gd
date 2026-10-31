extends Node2D

## Главная сцена: ведёт партию.
## - Board (в Grid) хранит поле, Grid его рисует, Block — фигура в лотке.
## - PieceGenerator выдаёт наборы фигур, Scoring считает очки и серию.
## - Прогресс, темы, достижения, настройки — автозагрузки Progression, ThemeManager,
##   Achievements, GameSettings. О событиях партии игра сообщает через Events.

# === РАСКЛАДКА ЭКРАНА 900×1600 ===
const SCREEN_SIZE = Vector2(900, 1600)
const GRID_POSITION = Vector2(130, 280)
const TRAY_CENTER_Y = 1090.0
const TRAY_HEIGHT = 250.0
const SLOT_WIDTH = 300.0

# === ПРАВИЛА ===
const CLUTCH_FILL = 0.75  # «На краю»: очистка при заполнении поля от 75%
const PRICE_HAMMER = 10
const PRICE_SHUFFLE = 30
const PRICE_UNDO = 20
const PRICE_ROTATE = 15
const ZEN_COIN_RATE = 0.5    # В спокойном режиме монет за очки вдвое меньше: проиграть нельзя
const ZEN_REFRESH_SHARE = 0.4  # Какую долю занятых клеток убирает «освежение» поля
const RUN_SAVE_PATH = "user://run.save"
const CONTINUE_BASE_COST = 100
const PLAY_TIME_STEP = 10.0

var block_scene = preload("res://block.tscn")

@onready var grid = $Grid
@onready var background_sprite: Sprite2D = $Background
@onready var theme_background: Node2D = $ThemeBackground
@onready var sound_place: AudioStreamPlayer = $SoundPlace
@onready var sound_clear: AudioStreamPlayer = $SoundClear
@onready var sound_game_over: AudioStreamPlayer = $SoundGameOver

var progression = null
var generator := PieceGenerator.new()
var scoring := Scoring.new()

var score = 0
var active_blocks = []
var game_over = false
var dragging_block = null  # Фигура, которую сейчас тянут (одна за раз)

# Награды за партию
var record_bonus_given = false  # Бонус за рекорд уже выдан
var run_finished = false        # Партия уже записана в статистику
var best_score_at_start = 0     # Рекорд на момент начала партии
var used_powerups = false       # Были ли бонусы или продолжение (для «Без подсказок»)
var run_coins = 0               # Монеты за очки этой партии (для итогов)
var run_xp = 0                  # Опыт, накопленный за партию: начисляется в конце
var run_lines = 0               # Линий очищено за партию
var pieces_this_run = 0

# Итоги партии: пока идёт начисление наград в finish_run(), события уровня,
# предметов и достижений собираются сюда, а не показываются уведомлениями
var collecting_summary = false
var summary = {"levels": [], "level_coins": 0, "slots": 0, "ranks": [], "items": [], "item_refs": [], "achievements": [], "missions": []}
var tutorial_label: Label = null

# Continue
var continue_cost = CONTINUE_BASE_COST
var continue_used_count = 0

# Power-ups
var hammer_mode = false
var last_move = null  # Для Undo: ход без очистки линий

var game_timer = 0.0

# Режимы и статистика партии
var zen = false               # Спокойный режим: вместо проигрыша поле освежается
var rotate_mode = false       # Бонус «Поворот» ждёт нажатия на фигуру
var run_max_streak = 0
var run_max_combo = 0
var record_announced = false  # Баннер «Новый рекорд!» уже показан в этой партии

# HUD
const ICON_DIR = "res://assets/ui/icons/"
const GOLD = Color(1, 0.81, 0.29)
const NAVY = Color(0.04, 0.05, 0.15)

var score_label: Label
var best_score_label: Label
var coins_label: Label
var multiplier_label: Label
var multiplier_pill: Control
var level_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var next_reward_label: Label
var streak_pill: Control
var combo_label: Label
var streak_label: Label
var toast_offset = 0

# Звуки по умолчанию (тема может подменить)
var default_place_stream: AudioStream
var default_clear_stream: AudioStream

func _ready():
	progression = Progression
	progression.reset_multiplier()
	best_score_at_start = progression.best_score
	zen = GameSettings.zen_mode
	default_place_stream = sound_place.stream
	default_clear_stream = sound_clear.stream

	grid.position = GRID_POSITION
	grid.cell_tapped.connect(use_hammer_on_cell)

	build_hud()
	connect_buttons()

	progression.xp_gained.connect(_on_xp_gained)
	progression.level_up.connect(_on_level_up)
	progression.reward_unlocked.connect(_on_reward_unlocked)
	progression.coins_changed.connect(_on_coins_changed)
	progression.daily_reward_available.connect(_on_daily_available)
	progression.daily_reward_claimed.connect(_on_daily_claimed)
	Events.achievement_unlocked.connect(_on_achievement_unlocked)
	Events.item_unlocked.connect(_on_item_unlocked)
	Missions.mission_completed.connect(_on_mission_completed)
	Missions.all_missions_completed.connect(_on_all_missions_completed)
	ThemeManager.theme_changed.connect(apply_theme_visuals)

	apply_theme_visuals(ThemeManager.current)
	refresh_profile_button()
	update_daily_button()

	scoring.reset()
	if not load_run():
		spawn_blocks()
		save_run()
	update_zen_display()
	update_powerup_buttons()
	show_tutorial_if_needed()
	Events.game_started.emit()

	# Имя подгоняется под ширину после того, как шрифт посчитан
	await get_tree().process_frame
	update_profile_name_display()

# F12 в отладочной сборке сохраняет снимок экрана 900×1600 — для скриншотов в магазин
func _unhandled_input(event: InputEvent):
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var path = "user://screenshot_%d.png" % Time.get_unix_time_from_system()
		get_viewport().get_texture().get_image().save_png(path)
		show_toast("Снимок: " + ProjectSettings.globalize_path(path))

func _process(delta):
	if not game_over:
		game_timer += delta
		if game_timer >= PLAY_TIME_STEP:
			progression.add_play_time(int(PLAY_TIME_STEP))
			game_timer = 0.0

# === ИНТЕРФЕЙС ===

func make_label(text: String, font_size: int, color: Color, pos: Vector2, label_size: Vector2,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 0) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", NAVY)
		label.add_theme_constant_override("outline_size", outline)
	add_child(label)
	return label

func icon(icon_name: String) -> Texture2D:
	return load(ICON_DIR + icon_name + ".svg")

func icon_rect(icon_name: String, icon_size: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = icon(icon_name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# Небольшая панель-контейнер (вариации темы: HudPanel, Pill, ToastPanel)
func make_panel(variation: StringName, pos: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.theme_type_variation = variation
	panel.position = pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func styled_label(text: String, font_size: int, color: Color, variation: StringName = &"") -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# Шапка: счёт в панели по центру, монеты и множитель справа, уровень с полоской опыта ниже.
# Всё лежит на полупрозрачных панелях, чтобы читаться на любом фоне темы.
func build_hud():
	var score_panel = make_panel(&"HudPanel", Vector2(270, 20))
	score_panel.custom_minimum_size = Vector2(320, 128)
	var score_box = VBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_theme_constant_override("separation", -4)
	score_panel.add_child(score_box)
	var caption = styled_label("ОЧКИ", 18, Color(0.64, 0.67, 0.85), &"CaptionLabel")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(caption)
	score_label = styled_label("0", 66, Color.WHITE, &"DisplayLabel")
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(score_label)
	var best_row = HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	best_row.add_theme_constant_override("separation", 6)
	best_row.add_child(icon_rect("trophy", 22, GOLD))
	best_score_label = styled_label("%d" % progression.best_score, 22, GOLD)
	best_row.add_child(best_score_label)
	score_box.add_child(best_row)

	var coin_pill = make_panel(&"Pill", Vector2(606, 32))
	coin_pill.custom_minimum_size = Vector2(164, 0)
	var coin_row = HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 8)
	coin_row.add_child(icon_rect("coin", 34))
	coins_label = styled_label("%d" % progression.total_coins, 28, GOLD, &"DisplayLabel")
	coin_row.add_child(coins_label)
	coin_pill.add_child(coin_row)

	multiplier_pill = make_panel(&"Pill", Vector2(606, 96))
	multiplier_label = styled_label("×1.0", 22, Color(1, 0.62, 0.25), &"DisplayLabel")
	multiplier_pill.add_child(multiplier_label)
	multiplier_pill.visible = false

	var level_badge = make_panel(&"Pill", Vector2(34, 172))
	level_badge.custom_minimum_size = Vector2(68, 68)
	level_label = styled_label("1", 30, GOLD, &"DisplayLabel")
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_badge.add_child(level_label)

	xp_label = make_label("", 20, Color.WHITE, Vector2(118, 168), Vector2(560, 28), HORIZONTAL_ALIGNMENT_LEFT)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(118, 200)
	xp_bar.size = Vector2(742, 14)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_bar)
	next_reward_label = make_label("", 18, Color(0.72, 0.76, 0.95), Vector2(118, 220), Vector2(742, 26), HORIZONTAL_ALIGNMENT_LEFT)

	streak_pill = make_panel(&"Pill", Vector2(700, 160))
	var streak_row = HBoxContainer.new()
	streak_row.add_theme_constant_override("separation", 6)
	streak_row.add_child(icon_rect("flame", 24, Color(1, 0.6, 0.25)))
	streak_label = styled_label("×2", 22, Color(1, 0.7, 0.35), &"DisplayLabel")
	streak_row.add_child(streak_label)
	streak_pill.add_child(streak_row)
	streak_pill.visible = false

	update_xp_display()

	combo_label = make_label("", 72, Color.WHITE, Vector2(250, 480), Vector2(400, 150), HORIZONTAL_ALIGNMENT_CENTER, 10)
	combo_label.theme_type_variation = &"DisplayLabel"
	combo_label.pivot_offset = combo_label.size / 2.0
	combo_label.modulate = Color(1, 1, 1, 0)
	combo_label.z_index = 50

	setup_buttons_style()

# Иконки и ценники на кнопках
func setup_buttons_style():
	setup_tool_button($HammerButton, "hammer", PRICE_HAMMER)
	setup_tool_button($RotateButton, "rotate", PRICE_ROTATE)
	setup_tool_button($ShuffleButton, "shuffle", PRICE_SHUFFLE)
	setup_tool_button($UndoButton, "undo", PRICE_UNDO)

	var settings = $SettingsButton
	settings.text = ""
	settings.theme_type_variation = &"IconButton"
	settings.icon = icon("settings")
	settings.expand_icon = true
	settings.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_theme_constant_override("icon_max_width", 44)

	for pair in [[$RestartButton, "restart", "Заново"], [$DailyButton, "tasks", "Задания"]]:
		var button: Button = pair[0]
		button.icon = icon(pair[1])
		button.text = pair[2]
		button.add_theme_constant_override("icon_max_width", 34)
		button.add_theme_font_size_override("font_size", 26)

func setup_tool_button(button: Button, icon_name: String, price: int):
	button.text = ""
	button.icon = icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_constant_override("icon_max_width", 44)

	var pill = PanelContainer.new()
	pill.name = "PricePill"
	pill.theme_type_variation = &"Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin = icon_rect("coin", 20)
	coin.name = "Coin"
	row.add_child(coin)
	var label = styled_label(str(price), 20, GOLD, &"DisplayLabel")
	label.name = "PriceLabel"
	row.add_child(label)
	pill.add_child(row)
	button.add_child(pill)
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 8)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN

# Включённый бонус (молоток, поворот) подсвечивается золотом, вместо цены — «отмена»
func set_tool_active(button: Button, active: bool, price: int):
	button.theme_type_variation = &"GoldButton" if active else &""
	var pill = button.get_node_or_null("PricePill")
	if pill:
		pill.get_node("Row/Coin").visible = not active
		pill.get_node("Row/PriceLabel").text = "отмена" if active else str(price)

func update_multiplier_display():
	multiplier_label.text = "×" + str(progression.score_multiplier)
	multiplier_pill.visible = progression.score_multiplier > 1.0

func connect_buttons():
	$SettingsButton.pressed.connect(_on_settings_pressed)
	$RestartButton.pressed.connect(_on_restart_button_pressed)
	$HammerButton.pressed.connect(_on_hammer_pressed)
	$RotateButton.pressed.connect(_on_rotate_pressed)
	$ShuffleButton.pressed.connect(_on_shuffle_pressed)
	$UndoButton.pressed.connect(_on_undo_pressed)
	$DailyButton.pressed.connect(_on_daily_pressed)
	$ProfileButton.pressed.connect(_on_profile_pressed)

func update_score_display():
	score_label.text = str(score)
	if zen:
		return  # Рекорды ставятся только в обычном режиме
	if progression.update_best_score(score):
		best_score_label.text = "%d" % progression.best_score
	# Праздник в момент, когда рекорд побит (один раз за партию)
	if not record_announced and best_score_at_start > 0 and score > best_score_at_start:
		record_announced = true
		show_big_text("НОВЫЙ РЕКОРД!", Color(1, 0.84, 0), 8.0)
		GameSettings.vibrate(60)

func update_zen_display():
	if zen:
		best_score_label.text = "Спокойный режим"

# Ближайшая награда за уровень — то, ради чего хочется сыграть ещё партию
func update_next_reward_display():
	var label = next_reward_label
	if label == null:
		return
	var next = progression.get_next_special_reward()
	if next.is_empty():
		label.text = ""
		return
	var text = "🎁 Ур. %d: %s" % [next["level"], next["lines"][0]]
	if next["lines"].size() > 1:
		text += " и ещё %d" % (next["lines"].size() - 1)
	label.text = text

func update_xp_display():
	update_next_reward_display()
	if level_label:
		level_label.text = str(progression.current_level)
	if xp_bar:
		xp_bar.max_value = progression.get_xp_for_next_level()
		xp_bar.value = progression.current_xp
	if xp_label:
		var text = progression.get_rank()
		if progression.is_max_level():
			text += " · максимум"
		else:
			text += " · %d / %d XP" % [progression.current_xp, progression.get_xp_for_next_level()]
		if run_xp > 0 and not run_finished:
			text += "  (+%d за партию)" % run_xp
		xp_label.text = text

func update_streak_display(streak: int):
	streak_pill.visible = streak >= 2
	if streak >= 2:
		streak_label.text = "×%d" % streak

func is_input_blocked() -> bool:
	return game_over or not get_tree().get_nodes_in_group("modal").is_empty()

# === ТЕМА ===

func apply_theme_visuals(theme: BlockTheme):
	RenderingServer.set_default_clear_color(theme.background_color)

	if theme.background_texture:
		background_sprite.texture = theme.background_texture
		var texture_size = theme.background_texture.get_size()
		var cover = maxf(SCREEN_SIZE.x / texture_size.x, SCREEN_SIZE.y / texture_size.y)
		background_sprite.scale = Vector2(cover, cover)
		background_sprite.position = SCREEN_SIZE / 2.0
		background_sprite.visible = true
	else:
		background_sprite.visible = false

	for child in theme_background.get_children():
		child.queue_free()
	if theme.background_scene:
		theme_background.add_child(theme.background_scene.instantiate())

	sound_place.stream = theme.sound_place if theme.sound_place else default_place_stream
	sound_clear.stream = theme.sound_clear if theme.sound_clear else default_clear_stream

	grid.queue_redraw()
	for block in active_blocks:
		if is_instance_valid(block):
			block.queue_redraw()

# === ФИГУРЫ ===

func get_slot_center(slot: int) -> Vector2:
	return Vector2(SLOT_WIDTH * (slot + 0.5), TRAY_CENTER_Y)

func create_block(shape: Array, color_index: int, slot: int):
	var block = block_scene.instantiate()
	block.shape = shape
	block.color_index = color_index
	block.slot_index = slot
	block.slot_center = get_slot_center(slot)
	block.slot_size = Vector2(SLOT_WIDTH, TRAY_HEIGHT)
	add_child(block)
	active_blocks.append(block)
	return block

func spawn_blocks():
	for block in active_blocks:
		if is_instance_valid(block):
			block.queue_free()
	active_blocks.clear()
	dragging_block = null

	# Ход из прошлого набора отменить уже нельзя
	last_move = null

	# Первые партии легче: резкий рост сложности — частая причина бросить игру
	var ramp = clampf(0.4 + 0.15 * progression.total_games_played, 0.4, 1.0)
	var difficulty = PieceGenerator.difficulty_for_score(score) * ramp
	var shapes = generator.generate_set(grid.board, difficulty)
	var colors = ThemeManager.get_spawn_color_indices()
	for i in range(shapes.size()):
		create_block(shapes[i], colors[randi() % colors.size()], i)

	refresh_tray()
	update_powerup_buttons()

# Тусклыми рисуются фигуры, которым нет места на поле
func refresh_tray():
	for block in active_blocks:
		if is_instance_valid(block):
			block.set_placeable(grid.board.can_place_anywhere(block.shape))

# Вызывает Block, когда фигуру отпустили над полем. Возвращает false, если поставить нельзя.
func try_place_piece(block, grid_x: int, grid_y: int) -> bool:
	var board: Board = grid.board
	if game_over or not board.can_place(block.shape, grid_x, grid_y):
		return false

	var fill_before = board.fill_ratio()
	var undo_state = {"score": score, "scoring": scoring.get_state()}

	var placed = board.place(block.shape, grid_x, grid_y, block.color_index)
	var lines = board.find_full_lines()
	var line_count = Board.count_lines(lines)
	var cleared = []
	if line_count > 0:
		cleared = board.clear_lines(lines)
	var result = scoring.register_move(placed.size(), line_count, line_count > 0 and board.is_board_empty())

	active_blocks.erase(block)
	block.queue_free()

	score += result["points"]
	update_score_display()
	update_streak_display(result["streak"])
	show_points_popup(placed, result["points"])

	sound_place.pitch_scale = randf_range(0.94, 1.06)
	sound_place.play()
	GameSettings.vibrate(15)
	pieces_this_run += 1
	run_max_streak = maxi(run_max_streak, result["streak"])
	hide_tutorial()
	progression.record_piece_placed()
	Events.piece_placed.emit(placed.size())

	if line_count > 0:
		# Ход с очисткой линий отменить нельзя: очки и XP за линии уже начислены
		last_move = null
		grid.play_clear_effect(cleared, lines)
		on_lines_cleared(line_count, result, fill_before)
	else:
		last_move = {
			"cells": placed,
			"shape": block.shape,
			"color_index": block.color_index,
			"slot": block.slot_index,
			"state": undo_state,
		}

	grid.queue_redraw()
	if active_blocks.is_empty():
		spawn_blocks()
	else:
		refresh_tray()
	update_powerup_buttons()
	check_game_over()
	save_run()
	return true

func on_lines_cleared(count: int, result: Dictionary, fill_before: float):
	# Звук очистки становится выше с каждым шагом серии — отклик растёт вместе с успехом
	sound_clear.pitch_scale = minf(1.0 + 0.07 * (result["streak"] - 1), 1.5)
	sound_clear.play()
	run_max_combo = maxi(run_max_combo, count)
	GameSettings.vibrate(30 + 15 * count)

	progression.record_lines_cleared(count)
	progression.record_combo(count)
	progression.record_streak(result["streak"])
	if result["perfect"]:
		progression.record_perfect_clear()
	if fill_before >= CLUTCH_FILL:
		progression.record_clutch_clear()

	run_lines += count

	# Множитель монет растёт со счётом
	progression.score_multiplier = progression.calculate_multiplier(score)
	update_multiplier_display()

	# XP за линии копится и начисляется в конце партии. Множитель счёта на опыт не влияет:
	# иначе сильные игроки проходили бы 500 уровней в разы быстрее, чем новички.
	var base_xp = count * 5 + count * 2 * count
	if count >= 2:
		base_xp += 10
	base_xp += maxi(result["streak"] - 1, 0) * 3
	run_xp += base_xp
	update_xp_display()

	show_combo_text(count, result)
	Events.lines_cleared.emit(count, result["streak"], result["perfect"], fill_before)

func check_game_over():
	if game_over:
		return
	for block in active_blocks:
		if is_instance_valid(block) and grid.board.can_place_anywhere(block.shape):
			return
	if zen:
		refresh_board()
		return
	game_over = true
	show_game_over()

# Спокойный режим: вместо проигрыша убираем часть блоков и даём новые фигуры
func refresh_board():
	var filled = []
	for y in range(Board.SIZE):
		for x in range(Board.SIZE):
			if grid.board.get_cell(x, y) != Board.EMPTY:
				filled.append(Vector2i(x, y))
	filled.shuffle()
	var removed = []
	for i in range(int(ceil(filled.size() * ZEN_REFRESH_SHARE))):
		var pos: Vector2i = filled[i]
		removed.append({"pos": pos, "color": grid.board.remove_cell(pos.x, pos.y)})
	grid.play_clear_effect(removed, {"rows": [], "cols": []})
	sound_clear.pitch_scale = 0.8
	sound_clear.play()
	show_big_text("ПОЛЕ ОСВЕЖЕНО", Color(0.6, 1, 0.85), 0.0)
	last_move = null
	spawn_blocks()

# === POWER-UPS ===

func update_powerup_buttons():
	var coins = progression.total_coins
	$HammerButton.disabled = (coins < PRICE_HAMMER and not hammer_mode) or game_over
	$RotateButton.disabled = (coins < PRICE_ROTATE and not rotate_mode) or game_over
	$ShuffleButton.disabled = coins < PRICE_SHUFFLE or game_over
	$UndoButton.disabled = coins < PRICE_UNDO or last_move == null or game_over

func mark_powerup_used(powerup_id: String):
	used_powerups = true
	progression.record_powerup()
	Events.powerup_used.emit(powerup_id)

func _on_hammer_pressed():
	# Повторное нажатие — отмена, монеты возвращаются
	if hammer_mode:
		progression.add_coins(PRICE_HAMMER)
		reset_hammer_button()
		return
	if dragging_block != null or not progression.spend_coins(PRICE_HAMMER):
		return
	if rotate_mode:
		reset_rotate_button()
	hammer_mode = true
	set_tool_active($HammerButton, true, PRICE_HAMMER)

func use_hammer_on_cell(x: int, y: int):
	if not hammer_mode:
		return
	var color = grid.board.remove_cell(x, y)
	if color == Board.EMPTY:
		return
	grid.play_clear_effect([{"pos": Vector2i(x, y), "color": color}], {"rows": [], "cols": []})
	grid.queue_redraw()
	sound_place.pitch_scale = 0.85
	sound_place.play()
	GameSettings.vibrate(25)
	mark_powerup_used("hammer")

	# После молотка поле изменилось — старый ход не отменить
	last_move = null
	reset_hammer_button()
	refresh_tray()
	save_run()

func reset_hammer_button():
	hammer_mode = false
	set_tool_active($HammerButton, false, PRICE_HAMMER)
	update_powerup_buttons()

func _on_shuffle_pressed():
	if game_over or dragging_block != null or not progression.spend_coins(PRICE_SHUFFLE):
		return
	mark_powerup_used("shuffle")
	spawn_blocks()
	check_game_over()
	save_run()

# Поворот: кнопка включает режим, нажатие на фигуру в лотке поворачивает её на 90°.
# Монеты списываются за сам поворот; повторное нажатие на кнопку — отмена.
func _on_rotate_pressed():
	if rotate_mode:
		reset_rotate_button()
		return
	if game_over or dragging_block != null or progression.total_coins < PRICE_ROTATE:
		return
	if hammer_mode:
		progression.add_coins(PRICE_HAMMER)
		reset_hammer_button()
	rotate_mode = true
	set_tool_active($RotateButton, true, PRICE_ROTATE)

func rotate_block(block):
	if not rotate_mode or not progression.spend_coins(PRICE_ROTATE):
		reset_rotate_button()
		return
	block.shape = Shapes.rotate_cw(block.shape)
	block.return_to_tray()
	block.queue_redraw()
	sound_place.pitch_scale = 1.2
	sound_place.play()
	GameSettings.vibrate(15)
	mark_powerup_used("rotate")
	last_move = null
	reset_rotate_button()
	refresh_tray()
	check_game_over()
	save_run()

func reset_rotate_button():
	rotate_mode = false
	set_tool_active($RotateButton, false, PRICE_ROTATE)
	update_powerup_buttons()

func _on_undo_pressed():
	if last_move == null or game_over or dragging_block != null:
		return
	if not progression.spend_coins(PRICE_UNDO):
		return

	for cell in last_move["cells"]:
		grid.board.cells[cell.y][cell.x] = Board.EMPTY
	score = last_move["state"]["score"]
	scoring.set_state(last_move["state"]["scoring"])
	create_block(last_move["shape"], last_move["color_index"], last_move["slot"])
	last_move = null

	mark_powerup_used("undo")
	score_label.text = str(score)
	update_streak_display(scoring.streak)
	grid.queue_redraw()
	refresh_tray()
	update_powerup_buttons()
	save_run()

# === МОДАЛЬНЫЕ ОКНА ===

# Затемнение на весь экран и панель по центру. Возвращает VBox для содержимого.
# Закрыть: close_modal(box). Пока окно открыто, поле не реагирует (группа "modal").
func open_modal(min_width: float = 560.0) -> VBoxContainer:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.position = Vector2.ZERO
	overlay.size = SCREEN_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	overlay.add_to_group("modal")
	add_child(overlay)

	var center = CenterContainer.new()
	center.size = SCREEN_SIZE
	overlay.add_child(center)

	var panel = PanelContainer.new()
	center.add_child(panel)

	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(min_width, 0)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.set_meta("overlay", overlay)
	return box

func close_modal(box: Control):
	if box == null or not is_instance_valid(box):
		return
	var overlay = box.get_meta("overlay", null)
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()

func modal_title(box: Control, text: String, color: Color = Color(1, 0.84, 0), font_size: int = 44) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = &"TitleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return label

func modal_text(box: Control, text: String, font_size: int = 26, color: Color = Color(0.85, 0.88, 1)) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return label

func modal_buttons(box: Control, buttons: Array) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	# Последняя кнопка — главное действие (синяя), третий элемент задаёт стиль явно
	for i in range(buttons.size()):
		var item: Array = buttons[i]
		var button = Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(240, 84)
		button.add_theme_font_size_override("font_size", 26)
		if item.size() > 2:
			button.theme_type_variation = item[2]
		elif i == buttons.size() - 1:
			button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(item[1])
		row.add_child(button)

func open_scene_modal(path: String):
	var instance = load(path).instantiate()
	instance.add_to_group("modal")
	instance.z_index = 100
	add_child(instance)

func _on_settings_pressed():
	open_scene_modal("res://settings.tscn")

func _on_profile_pressed():
	open_scene_modal("res://profile.tscn")

# === TOASTS (уведомления сверху) ===

func show_toast(text: String, color: Color = Color.WHITE):
	var panel = PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.z_index = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(620, 0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	add_child(panel)

	var slot_y = 30.0 + toast_offset * 130.0
	toast_offset += 1
	panel.position = Vector2((SCREEN_SIZE.x - 680) / 2.0, -200)

	var tween = create_tween()
	tween.tween_property(panel, "position:y", slot_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.4)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		toast_offset = maxi(toast_offset - 1, 0)
		panel.queue_free())

func _on_achievement_unlocked(achievement_id: String, tier: int):
	var def = Achievements.get_definition(achievement_id)
	var text = "%s %s — %s (+%d 💰)" % [def.get("icon", "🏆"), def.get("title", achievement_id),
		Achievements.get_tier_label(def, tier), Achievements.get_reward_coins(def, tier)]
	update_achievements_indicator()
	if collecting_summary:
		summary["achievements"].append([text, Achievements.get_tier_color(tier)])
	else:
		show_toast(text, Achievements.get_tier_color(tier))

func _on_item_unlocked(item_type: String, item_id):
	var text = "🎁 Открыто: " + progression.get_item_label(item_type, item_id)
	update_achievements_indicator()
	if collecting_summary:
		summary["items"].append(text)
		summary["item_refs"].append({"type": item_type, "id": item_id})
	else:
		show_toast(text, Color(0.6, 1, 0.7))

# === ПРОГРЕСС ===

func _on_xp_gained(_amount: int):
	update_xp_display()

func _on_level_up(new_level: int):
	update_xp_display()
	refresh_profile_button()
	if collecting_summary:
		summary["levels"].append(new_level)
	else:
		show_toast("🎉 Уровень %d!" % new_level, Color(1, 0.84, 0))

func _on_mission_completed(text: String, coins: int, xp: int):
	var line = "📋 Задание: %s (+%d 💰, +%d XP)" % [text, coins, xp]
	if collecting_summary:
		summary["missions"].append(line)
	else:
		show_toast(line, Color(0.55, 0.9, 1))
	update_daily_button()

func _on_all_missions_completed(bonus: int):
	var line = "🏁 Все задания дня выполнены! +%d 💰" % bonus
	if collecting_summary:
		summary["missions"].append(line)
	else:
		show_toast(line, Color(0.55, 0.9, 1))

# Монеты, слоты и звания за уровень (предметы приходят через Events.item_unlocked)
func _on_reward_unlocked(reward_type: String, reward_data):
	if not collecting_summary:
		return
	match reward_type:
		"coins":
			summary["level_coins"] += int(reward_data)
		"slot":
			summary["slots"] += 1
		"rank":
			summary["ranks"].append(str(reward_data))

func _on_coins_changed(new_amount: int):
	coins_label.text = "%d" % new_amount
	update_powerup_buttons()

# === DAILY REWARDS ===

func update_daily_button():
	var daily_btn = $DailyButton
	var has_news = progression.can_claim_daily
	daily_btn.text = "Задания %d/3" % Missions.count_done()
	# Есть неполученная награда дня — кнопка золотая
	daily_btn.theme_type_variation = &"GoldButton" if has_news else &""

func _on_daily_available():
	update_daily_button()

func _on_daily_claimed(_day: int, _reward: Dictionary):
	update_daily_button()

func _on_daily_pressed():
	if is_input_blocked():
		return
	show_tasks_popup()

# Задания на сегодня + награда дня в одном окне
func show_tasks_popup():
	Missions.ensure_today()
	var box = open_modal(640)
	modal_title(box, "ЗАДАНИЯ НА СЕГОДНЯ", Color(0.55, 0.9, 1), 38)

	for mission in Missions.missions:
		var done: bool = mission["done"]
		var text = "%s %s" % ["✅" if done else "⬜", Missions.get_text(mission)]
		if not done:
			text += "  (%d/%d)" % [mission["progress"], mission["target"]]
		var line = modal_text(box, text, 26, Color(0.6, 1, 0.7) if done else Color.WHITE)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var reward = modal_text(box, "      " + Missions.get_reward_text(mission), 20, Color(1, 0.84, 0))
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	modal_text(box, "Все три — ещё +%d 💰. Прогресс засчитывается в конце партии." % Missions.ALL_DONE_BONUS, 20)

	box.add_child(HSeparator.new())
	modal_title(box, "НАГРАДА ДНЯ", Color(1, 0.84, 0), 34)
	if progression.can_claim_daily:
		var next_day = progression.daily_streak % 7 + 1
		var reward = progression.get_daily_reward_for_day(next_day)
		var reward_text = "День %d: +%d 💰" % [next_day, reward.get("coins", 0)]
		if reward.has("xp"):
			reward_text += " +%d XP" % reward["xp"]
		modal_text(box, reward_text, 28, Color.WHITE)
		modal_text(box, "Заходите каждый день: на 7-й день — 300 💰 и 200 XP.", 20)
		modal_buttons(box, [
			["ЗАКРЫТЬ", close_modal.bind(box)],
			["ЗАБРАТЬ", _on_claim_daily_reward.bind(box)],
		])
	else:
		modal_text(box, "Награда получена. Следующая — завтра.", 24)
		modal_buttons(box, [["ЗАКРЫТЬ", close_modal.bind(box)]])

func _on_claim_daily_reward(box):
	var reward = progression.claim_daily_reward()
	close_modal(box)
	if reward.is_empty():
		return
	var text = "🎁 День %d: +%d 💰" % [progression.daily_streak, reward.get("coins", 0)]
	if reward.has("xp"):
		text += " +%d XP" % reward["xp"]
	show_toast(text, Color(0.5, 1, 0.5))

# === ЗАКОНЧИТЬ ПАРТИЮ (кнопка «Заново») ===

func _on_restart_button_pressed():
	if is_input_blocked():
		return
	if score == 0:
		clear_saved_run()
		get_tree().reload_current_scene()
		return
	var box = open_modal(520)
	modal_title(box, "ЗАКОНЧИТЬ ПАРТИЮ?", Color.YELLOW, 40)
	modal_text(box, "Монеты и опыт за набранные очки вы получите.")
	modal_buttons(box, [
		["ОТМЕНА", close_modal.bind(box)],
		["ЗАКОНЧИТЬ", _on_restart_confirm.bind(box)],
	])

func _on_restart_confirm(box):
	close_modal(box)
	if hammer_mode:
		progression.add_coins(PRICE_HAMMER)
		reset_hammer_button()
	game_over = true
	update_powerup_buttons()
	show_final_game_over()

# === НАГРАДЫ ЗА ПАРТИЮ ===

# XP за партию с таким счётом
func get_game_xp_for_score(value: int) -> int:
	if value <= 0:
		return 0
	var xp = 10
	if value >= 1000:
		xp += 20
	if value >= 5000:
		xp += 50
	if value >= 10000:
		xp += 100
	return xp

# Начисляет монеты и опыт за партию. Вызывается только из finish_run(): на экране
# «Продолжить?» награды ещё не выданы, поэтому продолжение оплачивается монетами,
# накопленными до этой партии. Уровни и их награды тоже приходят здесь, в конце.
func award_game_over_rewards():
	var coin_rate = ZEN_COIN_RATE if zen else 1.0
	var final_coins = int(int(score / 10.0) * progression.score_multiplier * coin_rate)
	if final_coins > 0:
		progression.add_coins(final_coins)
		progression.record_coins_earned(final_coins)
		run_coins += final_coins

	# Бонус за побитие рекорда (без мультипликатора)
	if not zen and score > best_score_at_start and score > 0:
		record_bonus_given = true
		progression.add_coins(20)
		progression.record_coins_earned(20)
		run_coins += 20

	run_xp += get_game_xp_for_score(score)
	if run_xp > 0:
		progression.gain_xp(run_xp)

# Завершает партию: выдаёт награды, записывает статистику, проверяет достижения (один раз)
func finish_run():
	if run_finished:
		return
	run_finished = true

	collecting_summary = true
	award_game_over_rewards()
	if pieces_this_run > 0:
		Missions.record_run({
			"lines": run_lines, "pieces": pieces_this_run, "score": score,
			"streak": run_max_streak, "combo": run_max_combo,
			"used_powerups": used_powerups, "zen": zen,
		})
	if score > 0:
		# Спокойный режим не участвует в «Без подсказок»: проиграть в нём нельзя
		progression.record_game_finished(score, used_powerups or zen, ThemeManager.current.id, run_lines)
	Events.game_finished.emit(score, used_powerups)
	collecting_summary = false
	clear_saved_run()

	progression.reset_multiplier()
	progression.save_progress()
	update_xp_display()

# === GAME OVER И CONTINUE ===

func show_game_over():
	if hammer_mode:
		progression.add_coins(PRICE_HAMMER)
		reset_hammer_button()
	update_powerup_buttons()
	sound_game_over.play()
	GameSettings.vibrate(120)

	if progression.total_coins >= continue_cost:
		show_continue_screen()
	else:
		show_final_game_over()

func show_continue_screen():
	var box = open_modal(540)
	modal_title(box, "ПРОДОЛЖИТЬ?", Color.YELLOW, 52)
	modal_text(box, "Очки: %d" % score, 34, Color.WHITE)
	modal_text(box, "Три новые фигуры за %d монет" % continue_cost, 30, GOLD)
	modal_text(box, "У вас %d монет. Монеты и опыт за партию начислятся, когда она закончится." % progression.total_coins, 22)
	modal_buttons(box, [
		["СДАТЬСЯ", _on_give_up.bind(box)],
		["ПРОДОЛЖИТЬ", _on_continue_game.bind(box), &"GoldButton"],
	])

func _on_continue_game(box):
	if not progression.spend_coins(continue_cost):
		return
	continue_used_count += 1
	continue_cost *= 2
	used_powerups = true
	progression.record_continue()
	Events.continue_used.emit()
	close_modal(box)

	game_over = false
	spawn_blocks()
	check_game_over()
	save_run()

func _on_give_up(box):
	close_modal(box)
	show_final_game_over()

func show_final_game_over():
	finish_run()
	continue_cost = CONTINUE_BASE_COST
	continue_used_count = 0

	var box = open_modal(600)
	modal_title(box, "ИГРА ОКОНЧЕНА", Color(1, 0.35, 0.35), 52)
	modal_text(box, "Очки: %d" % score, 44, Color.WHITE)
	if record_bonus_given:
		modal_text(box, "Новый рекорд! +20 💰", 28, Color(1, 0.84, 0))
	else:
		modal_text(box, "Рекорд: %d" % progression.best_score, 28, Color(1, 0.84, 0))

	box.add_child(HSeparator.new())
	modal_text(box, "Итоги партии", 30, Color.WHITE)
	for line in get_summary_lines():
		modal_text(box, line[0], 24, line[1])
	add_reward_cards(box)

	if should_ask_for_rating():
		modal_text(box, "Нравится игра? Оценка в магазине очень поможет.", 22)
		modal_buttons(box, [["⭐ ОЦЕНИТЬ", GameSettings.open_store_page], ["НОВАЯ ПАРТИЯ", _on_restart_pressed]])
	else:
		modal_buttons(box, [["НОВАЯ ПАРТИЯ", _on_restart_pressed]])

# Новые предметы — картинками, с кнопкой «Надеть»: момент получения награды должен быть заметным
func add_reward_cards(box: Control):
	var refs: Array = summary["item_refs"]
	if refs.is_empty():
		return
	box.add_child(HSeparator.new())
	modal_text(box, "🎁 Новые награды", 30, Color(0.6, 1, 0.7))
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for i in range(mini(refs.size(), 3)):
		row.add_child(make_reward_card(refs[i]))
	if refs.size() > 3:
		modal_text(box, "И ещё %d — смотрите в профиле" % (refs.size() - 3), 20)

func make_reward_card(item: Dictionary) -> Control:
	var card = VBoxContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	card.add_theme_constant_override("separation", 6)

	var holder = CenterContainer.new()
	holder.custom_minimum_size = Vector2(180, 130)
	card.add_child(holder)
	var item_id = item["id"]
	match item["type"]:
		"avatar", "frame":
			var picture = TextureRect.new()
			picture.texture = ItemsDB.get_avatar_texture(item_id) if item["type"] == "avatar" else ItemsDB.get_frame_texture(item_id)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2(124, 124)
			holder.add_child(picture)
		"theme":
			var preview = ThemePreview.new()
			preview.custom_minimum_size = Vector2(170, 124)
			preview.set_theme_resource(ThemeManager.get_theme_by_id(str(item_id)), false)
			holder.add_child(preview)
		"effect":
			var effect = EffectPreview.new()
			effect.custom_minimum_size = Vector2(170, 124)
			effect.setup(ItemsDB.get_effect_data(item_id).get("kind", "sparks"), Color(0.4, 0.7, 1))
			holder.add_child(effect)
		"color":
			var swatch = ColorRect.new()
			swatch.color = ItemsDB.block_colors[int(item_id)]
			swatch.custom_minimum_size = Vector2(110, 110)
			holder.add_child(swatch)

	var title = Label.new()
	title.text = progression.get_item_label(item["type"], item_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(180, 0)
	title.add_theme_font_size_override("font_size", 18)
	card.add_child(title)

	var button = Button.new()
	button.text = "В СЛОТЫ" if item["type"] == "color" else "НАДЕТЬ"
	button.custom_minimum_size = Vector2(170, 60)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(equip_item.bind(item, button))
	card.add_child(button)
	return card

func equip_item(item: Dictionary, button: Button):
	var item_id = item["id"]
	match item["type"]:
		"avatar":
			progression.player_avatar = int(item_id)
		"frame":
			progression.player_frame = int(item_id)
		"theme":
			progression.select_theme(str(item_id))
		"effect":
			progression.player_effect = int(item_id)
		"color":
			if progression.active_colors.size() >= progression.max_color_slots:
				button.text = "СЛОТЫ ЗАНЯТЫ"
				button.disabled = true
				return
			if not progression.active_colors.has(int(item_id)):
				progression.active_colors.append(int(item_id))
	progression.request_save()
	refresh_profile_button()
	button.text = "✓ ГОТОВО"
	button.disabled = true

# Строки итогов: [текст, цвет]
func get_summary_lines() -> Array:
	var gold = Color(1, 0.84, 0)
	var lines = []
	var coins_text = "💰 За очки: +%d" % run_coins
	if zen:
		coins_text += " (спокойный режим: ×0.5)"
	lines.append([coins_text, gold])
	lines.append(["✨ Опыт: +%d XP" % run_xp, Color(0.6, 0.85, 1)])
	var levels: Array = summary["levels"]
	if not levels.is_empty():
		var level_text = "🎉 Уровень %d!" % levels[-1] if levels.size() == 1 else "🎉 Уровни %d → %d!" % [levels[0], levels[-1]]
		lines.append(["%s  +%d 💰" % [level_text, summary["level_coins"]], gold])
	for rank in summary["ranks"]:
		lines.append(["🏅 Новое звание: «%s»" % rank, Color(1, 0.7, 0.3)])
	if summary["slots"] > 0:
		lines.append(["🎨 +%d слот для цветов" % summary["slots"], Color(0.85, 0.88, 1)])
	# Новые предметы показываются карточками ниже (add_reward_cards)
	for mission_text in summary["missions"]:
		lines.append([mission_text, Color(0.55, 0.9, 1)])
	for achievement in summary["achievements"]:
		lines.append(achievement)
	lines.append(["📋 Задания на сегодня: %d из 3" % Missions.count_done(), Color(0.75, 0.78, 0.92)])
	if not progression.is_max_level():
		var next = progression.get_next_special_reward()
		if not next.is_empty():
			lines.append(["Дальше: уровень %d — %s" % [next["level"], ", ".join(next["lines"])], Color(0.75, 0.78, 0.92)])
	return lines

# Просим оценку после 5-й и 20-й партии, если игрок ещё не оценивал
func should_ask_for_rating() -> bool:
	if GameSettings.rated or not GameSettings.has_store_page():
		return false
	return progression.total_games_played in [5, 20]

func _on_restart_pressed():
	get_tree().reload_current_scene()

# === СОХРАНЕНИЕ НЕЗАКОНЧЕННОЙ ПАРТИИ ===
# Партию могут прервать звонком или свернуть — при следующем запуске она продолжится.

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()

func save_run():
	if run_finished or not is_inside_tree():
		return
	var tray = []
	for block in active_blocks:
		if is_instance_valid(block):
			var cells = []
			for cell in block.shape:
				cells.append([int(cell.x), int(cell.y)])
			tray.append({"shape": cells, "color": block.color_index, "slot": block.slot_index})
	var data = {
		"version": 1,
		"board": grid.board.to_array(),
		"tray": tray,
		"score": score,
		"scoring": scoring.get_state(),
		"run_xp": run_xp,
		"run_lines": run_lines,
		"pieces": pieces_this_run,
		"used_powerups": used_powerups,
		"continue_cost": continue_cost,
		"best_at_start": best_score_at_start,
		"zen": zen,
		"multiplier": progression.score_multiplier,
		"max_streak": run_max_streak,
		"max_combo": run_max_combo,
		"record_announced": record_announced,
	}
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

# Возвращает true, если партия восстановлена
func load_run() -> bool:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return false
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var()
	file.close()
	if not data is Dictionary or not data.get("board", null) is Array or data["board"].size() != Board.SIZE:
		return false

	grid.board.from_array(data["board"])
	score = data.get("score", 0)
	scoring.set_state(data.get("scoring", {}))
	run_xp = data.get("run_xp", 0)
	run_lines = data.get("run_lines", 0)
	pieces_this_run = data.get("pieces", 0)
	used_powerups = data.get("used_powerups", false)
	continue_cost = data.get("continue_cost", CONTINUE_BASE_COST)
	best_score_at_start = data.get("best_at_start", progression.best_score)
	zen = data.get("zen", false)
	progression.score_multiplier = data.get("multiplier", 1.0)
	run_max_streak = data.get("max_streak", 0)
	run_max_combo = data.get("max_combo", 0)
	record_announced = data.get("record_announced", false)

	for item in data.get("tray", []):
		var shape = []
		for cell in item["shape"]:
			shape.append(Vector2(cell[0], cell[1]))
		create_block(shape, item["color"], item["slot"])
	if active_blocks.is_empty():
		spawn_blocks()

	score_label.text = str(score)
	update_streak_display(scoring.streak)
	update_xp_display()
	update_multiplier_display()
	grid.queue_redraw()
	refresh_tray()
	check_game_over()
	return true

func clear_saved_run():
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))

# === ПОДСКАЗКА НОВИЧКУ ===

func show_tutorial_if_needed():
	if progression.total_pieces_placed > 0:
		return
	tutorial_label = make_label("Перетащите фигуру на поле.\nЗаполните ряд или столбец — он исчезнет.",
		28, Color.WHITE, Vector2(50, 550), Vector2(800, 100), HORIZONTAL_ALIGNMENT_CENTER, 5)
	tutorial_label.z_index = 30

func hide_tutorial():
	if tutorial_label and is_instance_valid(tutorial_label):
		tutorial_label.queue_free()
	tutorial_label = null

# === ЭФФЕКТЫ ===

func show_points_popup(cells: Array, points: int):
	if points <= 0 or cells.is_empty():
		return
	var center = Vector2.ZERO
	for cell in cells:
		center += grid.cell_rect(cell.x, cell.y).get_center()
	center = center / cells.size() + grid.position

	var label = make_label("+%d" % points, 34, Color.WHITE, center - Vector2(80, 25), Vector2(160, 50), HORIZONTAL_ALIGNMENT_CENTER, 6)
	label.theme_type_variation = &"DisplayLabel"
	label.z_index = 40
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func show_combo_text(lines_count: int, result: Dictionary):
	var combo_text = ""
	var combo_color = Color.WHITE
	var shake_strength = 0.0

	match lines_count:
		1:
			combo_text = ""
		2:
			combo_text = "ДВОЙНОЙ!"
			combo_color = Color.YELLOW
			shake_strength = 3.0
		3:
			combo_text = "ТРОЙНОЙ!"
			combo_color = Color.ORANGE
			shake_strength = 5.0
		4:
			combo_text = "МЕГА!"
			combo_color = Color.RED
			shake_strength = 7.0
		5:
			combo_text = "БЕЗУМИЕ!"
			combo_color = Color.MAGENTA
			shake_strength = 9.0
		6:
			combo_text = "ЛЕГЕНДА!"
			combo_color = Color(1, 0.84, 0)
			shake_strength = 11.0
		_:
			combo_text = "НЕВЕРОЯТНО!"
			combo_color = Color(0.5, 1, 1)
			shake_strength = 13.0

	if result["perfect"]:
		combo_text = "ЧИСТОЕ ПОЛЕ!"
		combo_color = Color(0.6, 1, 0.8)
		shake_strength = maxf(shake_strength, 9.0)
	elif combo_text == "" and result["streak"] >= 3:
		combo_text = "СЕРИЯ ×%d" % result["streak"]
		combo_color = Color(1, 0.6, 0.2)

	if combo_text == "":
		return

	show_big_text(combo_text, combo_color, shake_strength)

func show_big_text(text: String, color: Color, shake_strength: float):
	combo_label.text = text
	combo_label.add_theme_color_override("font_color", color)
	animate_combo_label()
	if shake_strength > 0:
		screen_shake(shake_strength)
	spawn_combo_particles(color)

func animate_combo_label():
	combo_label.position = Vector2(250, 480)
	combo_label.scale = Vector2(0.5, 0.5)
	combo_label.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.chain().tween_interval(0.8)
	tween.chain().tween_property(combo_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.parallel().tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(combo_label, "position:y", 430.0, 0.3)

func screen_shake(strength: float):
	var original_pos = Vector2.ZERO
	for i in range(10):
		position = original_pos + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().create_timer(0.02).timeout
	position = original_pos

func spawn_combo_particles(color: Color):
	var particles = GPUParticles2D.new()
	particles.position = GRID_POSITION + grid.get_pixel_size() / 2.0
	particles.amount = 50
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	particles.z_index = 45

	var process_material = ParticleProcessMaterial.new()
	process_material.particle_flag_disable_z = true
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 20.0
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 200.0
	process_material.initial_velocity_max = 400.0
	process_material.gravity = Vector3(0, 500, 0)
	process_material.scale_min = 4.0
	process_material.scale_max = 8.0
	process_material.color = color

	particles.process_material = process_material
	particles.emitting = true
	add_child(particles)
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)

# === ПРОФИЛЬ (кнопка в углу) ===

func refresh_profile_button():
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn == null:
		return
	profile_btn.ignore_texture_size = true
	profile_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	profile_btn.texture_normal = ItemsDB.get_avatar_texture(progression.player_avatar)

	var profile_frame = profile_btn.get_node_or_null("ProfileFrame")
	if profile_frame:
		profile_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		profile_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		profile_frame.texture = ItemsDB.get_frame_texture(progression.player_frame)

	var profile_level_label = profile_btn.get_node_or_null("ProfileLevelLabel")
	if profile_level_label:
		profile_level_label.text = str(progression.current_level)

	update_achievements_indicator()

func update_achievements_indicator():
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn == null:
		return
	var indicator = profile_btn.get_node_or_null("NewIndicator")
	if indicator:
		indicator.visible = progression.has_any_new_items()

func update_profile_name_display():
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn == null:
		return
	var name_label = profile_btn.get_node_or_null("PlayerNameLabel")
	if name_label == null:
		return
	name_label.text = progression.player_name
	adjust_name_text_size(name_label, 75)

# Уменьшает шрифт имени, пока оно не влезет в табличку
func adjust_name_text_size(label: Label, max_width: float):
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size = 18
	while font_size > 8:
		var text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		if text_width <= max_width:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
