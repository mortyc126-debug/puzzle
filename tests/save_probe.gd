extends SceneTree

## Проба запуска для tests/save_stress.sh: запускает игру на подложенных сохранениях, ждёт,
## пока поле готово, делает несколько ходов и печатает «PROBE {…}» — уровень, монеты, поле,
## испытание. Ошибки скриптов скрипт стресс-теста ищет в выводе Godot.

var frames := 0
var moves := 0

func _initialize() -> void:
	# Сохранения, которые проще собрать здесь, чем в shell (автозагрузки читают их уже после _initialize)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prepare="):
			prepare(arg.trim_prefix("--prepare="))
	change_scene_to_file("res://game.tscn")

func today() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func prepare(kind: String) -> void:
	match kind:
		"challenge_no_puzzle":
			# Попытка «идёт», а задачи в сохранении нет
			SafeFile.save_var("user://challenge.save", {"date": today(), "active": true, "attempts": 1, "puzzle": {}})
		"challenge_yesterday":
			var puzzle = ChallengePuzzle.build("2026-01-05")
			SafeFile.save_var("user://challenge.save", {"date": "2026-01-05", "active": true, "attempts": 2, "puzzle": puzzle})
		"challenge_broken_run":
			# Попытка идёт, задача на месте, а файл самой попытки испорчен
			var puzzle = ChallengePuzzle.build(today())
			SafeFile.save_var("user://challenge.save", {"date": today(), "active": true, "attempts": 1, "puzzle": puzzle})
			var f = FileAccess.open("user://challenge_run.save", FileAccess.WRITE)
			f.store_string("не сохранение")
		"maxed":
			# Крайние значения: 500-й уровень, два миллиарда монет, все улучшения и титулы
			var tiers = {}
			for i in range(1, 39):
				tiers["avatar:%d" % i] = 2
			for i in range(1, 27):
				tiers["frame:%d" % i] = 2
			SafeFile.save_var("user://progression.save", {"save_version": 3, "current_level": 500, "current_xp": 0,
				"total_coins": 2000000000, "best_score": 999999, "item_tiers": tiers, "player_avatar": 37, "player_frame": 25,
				"owned_titles": ["infinite", "living"], "player_title": "infinite", "owned_name_colors": ["white", "rainbow"],
				"name_color": "rainbow", "name_glow_owned": true, "name_glow": true, "player_name": "ОченьДлинн",
				"player_skin": 10, "player_paint": 5, "player_backdrop": 8, "player_effect": 18})
		"broken_inner":
			# Внутренности файлов испорчены: задания без полей, задача испытания без наборов, тип в слотах цветов
			SafeFile.save_var("user://missions.save", {"date": today(), "missions": [{"kind": 3}, "x", 5], "bonus_given": false})
			SafeFile.save_var("user://challenge.save", {"date": today(), "active": true, "attempts": 1,
				"puzzle": {"date": today(), "goal": "lines", "target": 9, "sets": [[["a"]]]}})
			SafeFile.save_var("user://progression.save", {"save_version": 3, "current_level": 0, "active_colors": ["red", 99, -1],
				"max_color_slots": 999, "player_skin": 55, "player_paint": 77, "player_backdrop": 99,
				"unlocked_paints": [77, "x"], "unlocked_backdrops": [99, -3]})
			SafeFile.save_var("user://run.save", {"board": [[1, 2], "x"], "tray": [{"shape": [["a", "b"]]}], "score": "много"})
		"wrong_types":
			# Поля не того типа (как после ручной правки или сбоя)
			SafeFile.save_var("user://progression.save", {"save_version": 3, "current_level": "десять", "total_coins": -500,
				"unlocked_avatars": "все", "item_tiers": [], "owned_titles": {}, "active_colors": [],
				"unlocked_backdrops": "все", "player_backdrop": "королевский", "unlocked_paints": {}, "player_paint": [1]})

func _process(_delta: float) -> bool:
	frames += 1
	var game = current_scene
	if game == null or game.name != "Game" or not game.is_node_ready():
		return frames > 600
	if frames < 30:
		return false
	# Несколько ходов: игра должна быть живой, а не просто открыться
	if moves < 5 and not game.is_input_blocked():
		for block in game.active_blocks:
			if not is_instance_valid(block):
				continue
			var placed = false
			for y in range(Board.SIZE):
				for x in range(Board.SIZE):
					if not placed and game.grid.board.can_place(block.shape, x, y):
						placed = game.try_place_piece(block, x, y)
			if placed:
				moves += 1
				break
		if moves < 5 and frames < 300:
			return false
	var prog = root.get_node("Progression")
	var challenge = root.get_node("Challenge")
	print("PROBE ", JSON.stringify({
		"level": prog.current_level, "coins": prog.total_coins, "best": prog.best_score,
		"avatars": prog.unlocked_avatars.size(), "board": game.grid.board.filled_count(),
		"tray": game.active_blocks.size(), "moves": moves, "in_challenge": not game.challenge.is_empty(),
		"challenge_active": challenge.active, "challenge_ready": challenge.is_ready(),
		"achievement_tiers": root.get_node("Achievements").get_total_progress()["unlocked"],
		"missions": root.get_node("Missions").missions.size(), "blocked": game.is_input_blocked(),
		"look": "%d/%d/%d" % [prog.player_skin, prog.player_paint, prog.player_backdrop],
	}))
	return true
