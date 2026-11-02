extends SceneTree

## Сквозная проверка испытания дня в настоящей игре:
## обычная партия → «Начать» в окне заданий → поле испытания (стартовые клетки, без бонусов) →
## «звонок» посреди попытки (партия испытания восстанавливается) → игра до конца →
## итоги → «К партии» (обычная партия на месте, до клетки) → повтор стоит 100 монет.
##   godot --headless --path . --fixed-fps 60 -s tests/challenge_flow.gd
## Сохранения игрока не трогает: убирает их в user://bot_backup/ и возвращает в конце.
## В конце печатает «CHALLENGE FLOW: OK» или список проблем.

const SAVE_FILES = ["progression.save", "achievements.save", "missions.save", "settings.save", "run.save",
	"best_score.save", "challenge.save", "challenge_run.save"]
const BACKUP_DIR = "user://bot_backup/"

var step := 0
var wait := 0
var problems: Array = []
var notes: Array = []
var endless_board: Array = []
var endless_score := 0
var challenge_board: Array = []
var moves := 0
var result_seen := false

func _initialize() -> void:
	protect_player_saves()
	OS.low_processor_usage_mode = false
	change_scene_to_file("res://game.tscn")

func _process(_delta: float) -> bool:
	if wait > 0:
		wait -= 1
		return false
	var game = current_scene
	if game == null or game.name != "Game" or not game.is_node_ready():
		return false
	var challenge = root.get_node("Challenge")
	match step:
		0:
			# Ждём задачу дня (строится в фоне) и закрываем подсказки/окна
			if not challenge.is_ready():
				return false
			while game.is_input_blocked() and not game.game_over:
				game.handle_back()
			# Пара ходов обычной партии — её потом нужно найти на месте
			for i in range(2):
				var move = best_move(game)
				if not move.is_empty():
					game.try_place_piece(move["block"], move["x"], move["y"])
			endless_board = game.grid.board.to_array()
			endless_score = game.score
			game.show_tasks_popup()
			step = 1
			wait = 3
		1:
			var start_button = find_button(game.ui_layer, "НАЧАТЬ · БЕСПЛАТНО")
			if start_button == null:
				problems.append("в окне заданий нет кнопки «Начать · бесплатно»")
				return finish()
			start_button.pressed.emit()
			step = 2
			wait = 5
		2:
			if game.challenge.is_empty():
				problems.append("после «Начать» игра не перешла в испытание")
				return finish()
			var start_cells = game.challenge["start"].size()
			if game.grid.board.filled_count() != start_cells:
				problems.append("стартовое поле: %d клеток вместо %d" % [game.grid.board.filled_count(), start_cells])
			if game.get_node("HammerButton").visible:
				problems.append("в испытании видны бонусы")
			if game.score_caption.text != "ИСПЫТАНИЕ ДНЯ":
				problems.append("подпись счёта: «%s»" % game.score_caption.text)
			notes.append("испытание: %s, стартовых клеток %d" % [root.get_node("Challenge").puzzle["goal"], start_cells])
			step = 3
		3:
			# Играем, на 7-м ходу — «звонок»: партия испытания должна восстановиться
			if game.is_input_blocked():
				step = 5
				return false
			if moves == 7 and challenge_board.is_empty():
				game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
				challenge_board = game.grid.board.to_array()
				reload_current_scene()
				step = 4
				wait = 4
				return false
			var move = best_move(game)
			if move.is_empty():
				wait = 2
				return false
			game.try_place_piece(move["block"], move["x"], move["y"])
			moves += 1
			wait = 1
		4:
			if game.challenge.is_empty() or game.grid.board.to_array() != challenge_board:
				problems.append("испытание не восстановилось после перезапуска")
			else:
				notes.append("попытка испытания пережила перезапуск")
			step = 3
		5:
			# Итоги появляются с задержкой (анимация «Пройдено!»)
			var exit_button = find_button(game.ui_layer, "К ПАРТИИ")
			if exit_button == null:
				wait = 10
				if moves > 200:
					problems.append("итоги испытания не появились")
					return finish()
				moves += 1
				return false
			notes.append("итог: %s, ходов %d, прогресс %d из %d" % ["пройдено" if challenge.done_today else "не хватило",
				game.challenge_moves, game.challenge_progress(), int(game.challenge["target"])])
			if not challenge.done_today and challenge.retry_price() != 100:
				problems.append("повтор после первой попытки стоит %d, а не 100" % challenge.retry_price())
			exit_button.pressed.emit()
			step = 6
			wait = 5
		6:
			if not game.challenge.is_empty():
				problems.append("«К партии» не вернул обычную партию")
			elif game.grid.board.to_array() != endless_board or game.score != endless_score:
				problems.append("обычная партия не восстановилась после испытания")
			else:
				notes.append("обычная партия на месте после испытания (очки %d)" % endless_score)
			if challenge.active:
				problems.append("испытание осталось активным")
			return finish()
	return false

func best_move(game) -> Dictionary:
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
				var value = Board.count_lines(preview.find_full_lines()) * 10.0 + randf()
				if value > best_value:
					best_value = value
					best = {"block": block, "x": x, "y": y}
	return best

func find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
		var found = find_button(child, text)
		if found:
			return found
	return null

func finish() -> bool:
	for note in notes:
		print("  ✓ ", note)
	if problems.is_empty():
		print("CHALLENGE FLOW: OK")
	else:
		for problem in problems:
			print("  ✗ ", problem)
		print("CHALLENGE FLOW: %d проблем" % problems.size())
	restore_player_saves(false)
	return true

func save_variants() -> Array:
	var names = []
	for base in SAVE_FILES:
		for suffix in ["", ".bak", ".tmp"]:
			names.append(base + suffix)
	return names

func protect_player_saves() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	restore_player_saves(true)
	for file_name in save_variants():
		if FileAccess.file_exists("user://" + file_name):
			DirAccess.rename_absolute(ProjectSettings.globalize_path("user://" + file_name),
				ProjectSettings.globalize_path(BACKUP_DIR + file_name))

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
