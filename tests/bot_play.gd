extends SceneTree

## Бот-игрок: играет в настоящую игру (game.tscn) и проверяет всё вокруг партии:
## ходы мышью и настоящими касаниями (фигура должна встать ровно в выбранную клетку), бонусы,
## продолжение, итоги, профиль со всеми вкладками, настройки, задания, кнопку «Назад»,
## второй палец, сворачивание, восстановление партии; следит за утечками узлов и рывками.
##
## Запуск из корня проекта (после первого открытия в редакторе):
##   godot --headless --path . --fixed-fps 60 -s tests/bot_play.gd -- --games=20
##   --shots=ПАПКА — сохранить скриншоты экранов (запускать без --headless, нужно окно)
##   --touch=N     — каждый N-й ход делается касаниями (по умолчанию 3)
## В конце печатает сводку и «BOT RESULT: OK» или список проблем.
## Ваши сохранения не пострадают: перед игрой бот убирает их в user://bot_backup/ и возвращает в конце.

var games_target := 20
var shots_dir := ""
var touch_every := 3

var games_done := 0
var moves := 0
var touch_moves := 0
var wait_frames := 0
var problems: Array = []
var notes: Array = []
var pending: Dictionary = {}  # действие, растянутое на несколько кадров (касания)
var node_counts: Array = []
var scores: Array = []
var frame_index := 0
var checks_done := {}
var shot_index := 0
var game_moves := 0
var last_action := "старт"
var hitches: Array = []  # [мс, что было перед этим]
var last_frame_usec := 0
var frame_ms_list: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games_target = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--touch="):
			touch_every = maxi(int(arg.trim_prefix("--touch=")), 1)
	# Автозагрузки читают сохранения уже после _initialize — успеваем убрать сохранения игрока
	protect_player_saves()
	OS.low_processor_usage_mode = false
	seed(12345)
	change_scene_to_file("res://game.tscn")

# === СОХРАНЕНИЯ ИГРОКА ===

const SAVE_FILES = ["progression.save", "achievements.save", "missions.save", "settings.save", "run.save", "best_score.save"]
const BACKUP_DIR = "user://bot_backup/"

func save_variants() -> Array:
	var names = []
	for base in SAVE_FILES:
		for suffix in ["", ".bak", ".tmp"]:
			names.append(base + suffix)
	return names

func protect_player_saves() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	restore_player_saves(true)  # прошлый запуск бота прервался — сначала вернуть сохранения игрока
	for file_name in save_variants():
		if FileAccess.file_exists("user://" + file_name):
			DirAccess.rename_absolute(ProjectSettings.globalize_path("user://" + file_name),
				ProjectSettings.globalize_path(BACKUP_DIR + file_name))

# В начале (at_start) срабатывает, только если прошлый запуск бота прервался и копии остались.
# В конце — убирает сохранения бота и возвращает сохранения игрока.
func restore_player_saves(at_start: bool) -> void:
	var has_backup = false
	for file_name in save_variants():
		if FileAccess.file_exists(BACKUP_DIR + file_name):
			has_backup = true
	if at_start and not has_backup:
		return
	for file_name in save_variants():
		var live = ProjectSettings.globalize_path("user://" + file_name)
		if FileAccess.file_exists("user://" + file_name):
			DirAccess.remove_absolute(live)
		if FileAccess.file_exists(BACKUP_DIR + file_name):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_DIR + file_name), live)

func _process(_delta: float) -> bool:
	frame_index += 1
	# Полное время кадра (скрипты, раскладка интерфейса, отрисовка) между вызовами
	var now = Time.get_ticks_usec()
	var process_ms = 0.0 if last_frame_usec == 0 else (now - last_frame_usec) / 1000.0
	last_frame_usec = now
	if frame_index > 30:
		frame_ms_list.append(process_ms)
		if process_ms > 33.0:
			hitches.append([snappedf(process_ms, 0.1), last_action])
	if wait_frames > 0:
		wait_frames -= 1
		return false
	var game = current_scene
	if game == null or game.name != "Game" or not game.is_node_ready():
		return false
	if games_done >= games_target:
		return finish()
	step(game)
	return false

func problem(text: String) -> void:
	problems.append(text)
	if problems.size() <= 30:
		printerr("BOT PROBLEM: ", text)
	if problems.size() > 200:
		games_target = games_done  # что-то сломано по-крупному — заканчиваем

func step(game) -> void:
	if not pending.is_empty():
		continue_pending(game)
		return

	# Открытые окна
	var buttons = find_buttons(game.ui_layer)
	if game.is_input_blocked():
		handle_modal(game, buttons)
		return

	# Скриншоты игрового экрана: разные темы в разных партиях
	if games_done < 4 and game_moves == 2 and not checks_done.has("theme_%d" % games_done):
		checks_done["theme_%d" % games_done] = true
		var theme_ids = ["classic", "space", "candy", "ocean", "wood", "retro"]
		for theme_id in theme_ids.slice(games_done):
			if game.progression.select_theme(theme_id):
				break
	if games_done < 4 and game_moves == 14 and not checks_done.has("shot_game_%d" % games_done):
		checks_done["shot_game_%d" % games_done] = true
		screenshot("game_%d_%s" % [games_done, root.get_node("ThemeManager").current.id])

	# Разовые проверки в начале некоторых партий
	if game_moves == 3 and not checks_done.has("profile_%d" % games_done) and games_done % 4 == 0:
		checks_done["profile_%d" % games_done] = true
		start_profile_tour(game)
		return
	if game_moves == 5 and not checks_done.has("misc_%d" % games_done) and games_done % 3 == 1:
		checks_done["misc_%d" % games_done] = true
		run_misc_checks(game)
		return
	if game_moves == 8 and not checks_done.has("reload_%d" % games_done) and games_done % 5 == 2:
		checks_done["reload_%d" % games_done] = true
		check_save_and_reload(game)
		return
	if game_moves == 10 and not checks_done.has("multitouch_%d" % games_done) and games_done % 4 == 3:
		checks_done["multitouch_%d" % games_done] = true
		start_multitouch_check(game)
		return

	# Иногда — бонусы
	var coins = game.progression.total_coins
	if game_moves > 0 and game_moves % 17 == 0 and not checks_done.has("powerup_%d_%d" % [games_done, game_moves]):
		checks_done["powerup_%d_%d" % [games_done, game_moves]] = true
		try_powerup(game, coins)
		return

	var move = choose_move(game)
	if move.is_empty():
		wait_frames = 2
		return
	var preview = game.grid.board.duplicate_board()
	preview.place(move["block"].shape, move["x"], move["y"], 0)
	last_action = "ход (линий: %d)" % Board.count_lines(preview.find_full_lines())
	if touch_every > 0 and moves % touch_every == 0:
		start_touch_move(game, move)
	else:
		var placed = game.try_place_piece(move["block"], move["x"], move["y"])
		if not placed:
			problem("try_place_piece отказал на допустимом ходе")
		moves += 1
		game_moves += 1
		wait_frames = 1

# === ХОДЫ ===

func choose_move(game) -> Dictionary:
	var board: Board = game.grid.board
	var best = {}
	var best_value = -INF
	for block in game.active_blocks:
		if not is_instance_valid(block):
			continue
		for y in range(Board.SIZE):
			for x in range(Board.SIZE):
				if not board.can_place(block.shape, x, y):
					continue
				var preview = board.duplicate_board()
				preview.place(block.shape, x, y, 0)
				var full = preview.find_full_lines()
				var lines = Board.count_lines(full)
				if lines > 0:
					preview.clear_lines(full)
				var value = lines * 10.0 - holes(preview) * 1.2 + randf() * 1.0
				if value > best_value:
					best_value = value
					best = {"block": block, "x": x, "y": y}
	return best

# Пустые клетки, зажатые с трёх-четырёх сторон, — неудобные дырки
func holes(board: Board) -> int:
	var count = 0
	for y in range(Board.SIZE):
		for x in range(Board.SIZE):
			if board.get_cell(x, y) != Board.EMPTY:
				continue
			var blocked = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx = x + d.x
				var ny = y + d.y
				if not board.in_bounds(nx, ny) or board.get_cell(nx, ny) != Board.EMPTY:
					blocked += 1
			if blocked >= 3:
				count += blocked - 2
	return count

# Настоящие касания: нажать в слоте, протащить, отпустить над целевой клеткой
func start_touch_move(game, move: Dictionary) -> void:
	var block = move["block"]
	var press_at = game.to_global(block.slot_center)
	# Каким должно стать поле, если фигура встанет ровно в выбранную клетку
	var expected = game.grid.board.duplicate_board()
	expected.place(block.shape, move["x"], move["y"], block.color_index)
	var lines = expected.find_full_lines()
	if Board.count_lines(lines) > 0:
		expected.clear_lines(lines)
	send_touch(0, press_at, true)
	pending = {"kind": "touch_move", "stage": 0, "block": block, "x": move["x"], "y": move["y"],
		"expected": expected.to_array(), "score_before": game.score}
	wait_frames = 1

func continue_pending(game) -> void:
	match pending["kind"]:
		"touch_move":
			continue_touch_move(game)
		"multitouch":
			continue_multitouch(game)
		"seq":
			continue_sequence()
		_:
			pending = {}

func continue_touch_move(game) -> void:
	var block = pending["block"]
	match pending["stage"]:
		0:
			if not is_instance_valid(block) or not block.dragging:
				problem("касание в слоте не взяло фигуру (раскладка/координаты?)")
				moves += 1
				game_moves += 1
				pending = {}
				return
			var target = game.grid.global_position + Vector2(pending["x"], pending["y"]) * game.grid.CELL_SIZE + block.drag_offset
			pending["target"] = target
			send_drag(0, target)
			pending["stage"] = 1
			wait_frames = 1
		1:
			send_touch(0, pending["target"], false)
			pending["stage"] = 2
			wait_frames = 2
		2:
			if is_instance_valid(block) and not block.is_queued_for_deletion():
				problem("фигура не поставилась касанием в клетку %d,%d" % [pending["x"], pending["y"]])
			elif game.grid.board.to_array() != pending["expected"]:
				problem("касание поставило фигуру не в ту клетку (цель %d,%d)" % [pending["x"], pending["y"]])
			else:
				touch_moves += 1
			moves += 1
			game_moves += 1
			pending = {}

# Второй палец во время перетаскивания не должен ронять фигуру
func start_multitouch_check(game) -> void:
	var move = choose_move(game)
	if move.is_empty():
		return
	var block = move["block"]
	send_touch(0, game.to_global(block.slot_center), true)
	pending = {"kind": "multitouch", "stage": 0, "block": block}
	wait_frames = 1

func continue_multitouch(game) -> void:
	var block = pending["block"]
	match pending["stage"]:
		0:
			send_drag(0, game.grid.global_position + Vector2(300, 300))
			pending["stage"] = 1
			wait_frames = 1
		1:
			# второй палец: нажать и отпустить на поле
			send_touch(1, game.grid.global_position + Vector2(100, 100), true)
			pending["stage"] = 2
			wait_frames = 1
		2:
			send_touch(1, game.grid.global_position + Vector2(100, 100), false)
			pending["stage"] = 3
			wait_frames = 2
		3:
			if not is_instance_valid(block) or not block.dragging:
				problem("второй палец уронил или поставил фигуру")
			else:
				notes.append("второй палец не мешает перетаскиванию")
			# Сворачивание игры во время перетаскивания возвращает фигуру в лоток
			game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			pending["stage"] = 4
			wait_frames = 1
		4:
			if is_instance_valid(block) and block.dragging:
				problem("после сворачивания фигура осталась в руке")
			elif game.dragging_block != null:
				problem("после сворачивания dragging_block не сброшен")
			else:
				notes.append("сворачивание возвращает фигуру в лоток")
			# Отпускание первого пальца после этого ничего не ставит
			send_touch(0, game.grid.global_position + Vector2(300, 300), false)
			pending = {}
			wait_frames = 2

func send_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)

func send_drag(index: int, at: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = Vector2(1, 1)
	root.push_input(event, true)

# === БОНУСЫ ===

func try_powerup(game, coins: int) -> void:
	var choice = randi() % 4
	match choice:
		0:
			if coins >= game.PRICE_HAMMER and game.grid.board.filled_count() > 0:
				var before = coins
				game.get_node("HammerButton").pressed.emit()
				if not game.hammer_mode:
					problem("молоток не включился")
					return
				if game.progression.total_coins != before:
					problem("молоток списал монеты при включении")
				for y in range(Board.SIZE):
					for x in range(Board.SIZE):
						if game.grid.board.get_cell(x, y) != Board.EMPTY:
							game.use_hammer_on_cell(x, y)
							if game.progression.total_coins != before - game.PRICE_HAMMER:
								problem("молоток: списано %d вместо %d" % [before - game.progression.total_coins, game.PRICE_HAMMER])
							if game.grid.board.get_cell(x, y) != Board.EMPTY:
								problem("молоток не убрал клетку")
							notes.append("молоток")
							return
		1:
			if coins >= game.PRICE_ROTATE and not game.active_blocks.is_empty():
				game.get_node("RotateButton").pressed.emit()
				var block = game.active_blocks[0]
				var before_shape = block.shape.duplicate()
				game.rotate_block(block)
				if block.shape == before_shape and before_shape.size() > 1 and Shapes.get_size(before_shape) != Vector2i(2, 2):
					problem("поворот не изменил фигуру")
				notes.append("поворот")
		2:
			if coins >= game.PRICE_SHUFFLE:
				game.get_node("ShuffleButton").pressed.emit()
				notes.append("новые фигуры")
		3:
			if coins >= game.PRICE_UNDO and game.last_move != null:
				var state = game.last_move["state"]
				game.get_node("UndoButton").pressed.emit()
				if game.score != state["score"]:
					problem("отмена хода не вернула счёт")
				notes.append("отмена хода")

# === ОКНА ===

func find_buttons(parent: Node) -> Array:
	var result = []
	if parent == null:
		return result
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled:
			result.append(child)
		result.append_array(find_buttons(child))
	return result

func press(buttons: Array, text: String) -> bool:
	for button in buttons:
		if button.text == text:
			button.pressed.emit()
			return true
	return false

func handle_modal(game, buttons: Array) -> void:
	var texts = buttons.map(func(b): return b.text)
	if "НОВАЯ ПАРТИЯ" in texts:
		if games_done < 2:
			screenshot("final_game_%d" % games_done)
		scores.append(game.score)
		node_counts.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		games_done += 1
		game_moves = 0
		last_action = "новая партия (перезагрузка сцены)"
		print("партия %d: очки %d, ходов всего %d, монет %d, уровень %d" % [games_done, game.score, moves,
			game.progression.total_coins, game.progression.current_level])
		press(buttons, "НОВАЯ ПАРТИЯ")
		wait_frames = 4
	elif "ПРОДОЛЖИТЬ" in texts:
		last_action = "продолжение или сдаться"
		if games_done == 0:
			screenshot("continue")
		# Продолжаем через раз, чтобы проверить оба пути
		press(buttons, "ПРОДОЛЖИТЬ" if games_done % 2 == 0 else "СДАТЬСЯ")
		wait_frames = 3
	elif "ИГРАТЬ" in texts:
		press(buttons, "ИГРАТЬ")
		wait_frames = 2
	elif "ЗАБРАТЬ" in texts:
		press(buttons, "ЗАБРАТЬ")
		wait_frames = 2
	elif "ЗАКРЫТЬ" in texts:
		press(buttons, "ЗАКРЫТЬ")
		wait_frames = 2
	else:
		problem("окно без известных кнопок: %s" % [texts])
		game.handle_back()
		wait_frames = 3

# Последовательность шагов с паузой в несколько кадров между ними (чтобы окна успели отрисоваться)
func run_sequence(steps: Array, seq_name: String = "сценарий") -> void:
	pending = {"kind": "seq", "steps": steps, "frames": 0, "name": seq_name}

func continue_sequence() -> void:
	if pending["frames"] > 0:
		pending["frames"] -= 1
		return
	var steps: Array = pending["steps"]
	if steps.is_empty():
		pending = {}
		return
	var next_step: Callable = steps.pop_front()
	last_action = "%s, шаг %d" % [pending.get("name", "сценарий"), pending.get("index", 0)]
	pending["index"] = pending.get("index", 0) + 1
	next_step.call()
	if not pending.is_empty():
		pending["frames"] = 3

func modal_texts(game) -> Array:
	return find_buttons(game.ui_layer).map(func(b): return b.text)

func find_modal_scene(game, scene_name: String) -> Node:
	for child in game.ui_layer.get_children():
		if child.name == scene_name and not child.is_queued_for_deletion():
			return child
	return null

func run_misc_checks(game) -> void:
	run_sequence([
		func(): game.handle_back(),
		func():
			var texts = modal_texts(game)
			if not ("ВЫЙТИ" in texts and "ИГРАТЬ" in texts):
				problem("«Назад» на главном экране не показал вопрос о выходе: %s" % [texts])
			else:
				screenshot("exit_popup")
				notes.append("«Назад» → «Выйти из игры?»")
			press(find_buttons(game.ui_layer), "ИГРАТЬ"),
		func():
			if game.is_input_blocked():
				problem("«Играть» не закрыл вопрос о выходе")
			game.show_tasks_popup(),
		func():
			screenshot("tasks")
			game.handle_back(),
		func():
			if game.is_input_blocked():
				problem("«Назад» не закрыл окно заданий")
			game.get_node("SettingsButton").pressed.emit(),
		func():
			screenshot("settings")
			var settings = find_modal_scene(game, "Settings")
			if settings == null:
				problem("настройки не открылись")
				return
			if settings.get_node("OptionsContainer/MusicOption").visible:
				problem("переключатель музыки виден")
			game.handle_back(),
		func():
			if find_modal_scene(game, "Settings") != null:
				problem("«Назад» не закрыл настройки")
			else:
				notes.append("настройки и задания закрываются «Назад»"),
	], "окна и «Назад»")

# Профиль: все вкладки, карточка предмета, «Назад» сначала закрывает карточку, потом профиль
func start_profile_tour(game) -> void:
	var steps: Array = [func(): game.get_node("ProfileButton").pressed.emit()]
	for tab in range(8):
		steps.append(func():
			var profile = find_modal_scene(game, "Profile")
			if profile == null:
				problem("профиль не открылся")
				pending = {}
				return
			profile.get_node("CustomizeContainer").current_tab = tab)
		steps.append(func():
			if games_done == 0:
				screenshot("profile_tab_%d" % tab))
	steps.append_array([
		func():
			var profile = find_modal_scene(game, "Profile")
			if profile:
				profile.show_item_card("avatar", 2),
		func():
			screenshot("profile_card")
			game.handle_back(),
		func():
			if find_modal_scene(game, "Profile") == null:
				problem("«Назад» закрыл профиль вместо карточки")
			game.handle_back(),
		func():
			if find_modal_scene(game, "Profile") != null:
				problem("«Назад» не закрыл профиль")
			else:
				notes.append("профиль: 8 вкладок, «Назад» закрывает карточку, потом профиль"),
	])
	run_sequence(steps, "профиль")

# Сохранение и восстановление партии: перезапуск сцены = новый запуск игры
func check_save_and_reload(game) -> void:
	var board_before = game.grid.board.to_array()
	var score_before = game.score
	var tray_before = game.active_blocks.size()
	run_sequence([
		func():
			game.save_run()
			reload_current_scene(),
		func():
			var restored = current_scene
			if restored == null or restored.grid.board.to_array() != board_before or restored.score != score_before \
					or restored.active_blocks.size() != tray_before:
				problem("партия не восстановилась после перезапуска")
			else:
				notes.append("партия восстанавливается после перезапуска"),
	], "перезапуск")

func screenshot(shot_name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	var image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return
	shot_index += 1
	image.save_png("%s/%02d_%s.png" % [shots_dir, shot_index, shot_name])

func finish() -> bool:
	print("")
	print("=== БОТ: партий %d, ходов %d (касаниями %d) ===" % [games_done, moves, touch_moves])
	if not scores.is_empty():
		var sorted_scores = scores.duplicate()
		sorted_scores.sort()
		print("очки: медиана %d, макс %d" % [sorted_scores[sorted_scores.size() / 2], sorted_scores[-1]])
	print("узлов в начале партий: ", node_counts)
	if node_counts.size() >= 4:
		var early = node_counts[1]
		var late = node_counts[-1]
		if late > early + 40:
			problem("число узлов растёт от партии к партии: %d → %d (утечка?)" % [early, late])
	print("сирот (узлы вне дерева): ", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	Node.print_orphan_nodes()
	var by_action = {}
	for hitch in hitches:
		var key = str(hitch[1]).split(" (")[0] if str(hitch[1]).begins_with("ход") else str(hitch[1])
		if not by_action.has(key) or by_action[key] < hitch[0]:
			by_action[key] = hitch[0]
	print("кадры дольше 33 мс: %d; худшие по действию: %s" % [hitches.size(), by_action])
	frame_ms_list.sort()
	if not frame_ms_list.is_empty():
		print("время кадра: медиана %.1f мс, 99%% кадров быстрее %.1f мс, макс %.1f мс" % [
			frame_ms_list[frame_ms_list.size() / 2], frame_ms_list[int(frame_ms_list.size() * 0.99)], frame_ms_list[-1]])
	print("память: %.1f МБ" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var unique_notes = {}
	for note in notes:
		unique_notes[note] = unique_notes.get(note, 0) + 1
	print("проверено: ", unique_notes)
	if problems.is_empty():
		print("BOT RESULT: OK")
	else:
		print("BOT RESULT: %d проблем" % problems.size())
		for p in problems:
			print("  - ", p)
	restore_player_saves(false)
	print("сохранения игрока возвращены")
	return true
