extends SceneTree

## Игрок-персона для симуляции плейтеста (docs/PLAYTEST.md): играет в настоящую игру со своим стилем
## и в конце печатает PERSONA_RESULT {…} — статистику по каждой партии.
##   godot --headless --path . --fixed-fps 60 -s tests/persona_bot.gd -- --persona=имя --games=8 --skill=0.5
##     --powerups=0.05 --continue=half|always|never|free --zen [--zen-moves=160] --interrupt=40
##     --shop=300 --level=30
## skill 0..1 — насколько аккуратно игрок ставит фигуры; powerups — вероятность бонуса на ходу;
## continue=free — продолжает, только когда это бесплатно (подарок новичку);
## interrupt — каждые N ходов «звонок»: партия сохраняется, игра перезапускается, бот сверяет поле;
## shop=N — после партии покупает в профиле самые ценные доступные предметы, оставляя N монет;
## level=N — начать с уровня N (задания дня пересоздаются под него).
## ВНИМАНИЕ: бот играет на обычных сохранениях игры. Запускайте его на копии проекта с другим
## config/name в project.godot — иначе он продолжит ваш прогресс.

var persona := "player"
var games_target := 6
var skill := 0.5
var powerup_rate := 0.03
var continue_policy := "half"
var zen := false
var interrupt_every := 0
var shop_reserve := -1  # --shop=N: после партии покупает самый ценный доступный предмет, оставляя N монет
var bought: Array = []
var start_level := 0  # --level=N: начать с этого уровня (задания дня пересоздаются под него)
var level_applied := false
var zen_moves := 160  # в спокойном режиме проиграть нельзя — игрок сам заканчивает партию «Заново»

var games: Array = []
var current := {}
var moves := 0
var wait_frames := 0
var frame_ms: Array = []
var place_ms: Array = []
var last_usec := 0
var frame_index := 0
var first_clear_move := -1
var tutorial_seen := false
var problems: Array = []
var resumes_ok := 0
var resumes_bad := 0
var pending_resume = null
var start_time := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts = arg.trim_prefix("--").split("=")
		var key = parts[0]
		var value = parts[1] if parts.size() > 1 else ""
		match key:
			"persona": persona = value
			"games": games_target = int(value)
			"skill": skill = float(value)
			"powerups": powerup_rate = float(value)
			"continue": continue_policy = value
			"zen": zen = true
			"interrupt": interrupt_every = int(value)
			"zen-moves": zen_moves = int(value)
			"level": start_level = int(value)
			"shop": shop_reserve = int(value)
	OS.low_processor_usage_mode = false
	if zen:
		SafeFile.save_var("user://settings.save", {"sound": true, "music": true, "vibration": true, "rated": false, "zen_mode": true})
	start_time = Time.get_ticks_msec()
	change_scene_to_file("res://game.tscn")

func _process(_delta: float) -> bool:
	frame_index += 1
	var now = Time.get_ticks_usec()
	if last_usec > 0 and frame_index > 30:
		frame_ms.append((now - last_usec) / 1000.0)
	last_usec = now
	if wait_frames > 0:
		wait_frames -= 1
		return false
	var game = current_scene
	if game == null or game.name != "Game" or not game.is_node_ready():
		return false
	if pending_resume != null:
		check_resume(game)
		return false
	if games.size() >= games_target:
		return finish()
	step(game)
	return false

func progression():
	return root.get_node("Progression")

func step(game) -> void:
	if start_level > 0 and not level_applied:
		level_applied = true
		var prog_node = progression()
		prog_node.current_level = start_level
		prog_node.total_games_played = 10  # не новичок: без помощи генератора
		var missions = root.get_node("Missions")
		missions.date = ""
		missions.ensure_today()
	if current.is_empty():
		var prog = progression()
		current = {"level_start": prog.current_level, "moves": 0, "powerups": 0, "continues": 0, "first_lines_at": -1}
		if frame_index < 200 and game.tutorial_label != null and is_instance_valid(game.tutorial_label):
			tutorial_seen = true
	if game.is_input_blocked():
		handle_modal(game)
		return
	# Прерывание (звонок/сворачивание): партия сохраняется, игра перезапускается
	if interrupt_every > 0 and current["moves"] > 0 and current["moves"] % interrupt_every == 0 and not current.has("int_%d" % current["moves"]):
		current["int_%d" % current["moves"]] = true
		game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		pending_resume = {"board": game.grid.board.to_array(), "score": game.score}
		reload_current_scene()
		wait_frames = 3
		return
	if game.zen and current["moves"] >= zen_moves:
		game.get_node("RestartButton").pressed.emit()
		var list = buttons(game.ui_layer)
		press(list, "ЗАКОНЧИТЬ")
		wait_frames = 3
		return
	var coins = game.progression.total_coins
	if powerup_rate > 0 and randf() < powerup_rate:
		use_powerup(game, coins)
		return
	var move = choose_move(game)
	if move.is_empty():
		wait_frames = 2
		return
	var lines_before = game.run_lines
	var t0 = Time.get_ticks_usec()
	if not game.try_place_piece(move["block"], move["x"], move["y"]):
		problems.append("ход отклонён")
	place_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	moves += 1
	current["moves"] += 1
	if game.run_lines > lines_before and current["first_lines_at"] < 0:
		current["first_lines_at"] = current["moves"]
	wait_frames = 1

func check_resume(game) -> void:
	if game.grid.board.to_array() == pending_resume["board"] and game.score == pending_resume["score"]:
		resumes_ok += 1
	else:
		resumes_bad += 1
		problems.append("партия не восстановилась после прерывания")
	pending_resume = null

# Чем ниже навык, тем больше случайности и тем меньше игрок думает о «дырках»
func choose_move(game) -> Dictionary:
	var board: Board = game.grid.board
	var best = {}
	var best_value = -INF
	var noise = 1.0 + 14.0 * (1.0 - skill)
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
				var value = lines * 10.0 - holes(preview) * 1.5 * skill + randf() * noise
				if value > best_value:
					best_value = value
					best = {"block": block, "x": x, "y": y}
	return best

func holes(board: Board) -> int:
	var count = 0
	for y in range(Board.SIZE):
		for x in range(Board.SIZE):
			if board.get_cell(x, y) != Board.EMPTY:
				continue
			var blocked = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not board.in_bounds(x + d.x, y + d.y) or board.get_cell(x + d.x, y + d.y) != Board.EMPTY:
					blocked += 1
			if blocked >= 3:
				count += blocked - 2
	return count

func use_powerup(game, coins: int) -> void:
	match randi() % 4:
		0:
			if coins >= game.PRICE_HAMMER and game.grid.board.filled_count() > 0:
				game.get_node("HammerButton").pressed.emit()
				for y in range(Board.SIZE):
					for x in range(Board.SIZE):
						if game.hammer_mode and game.grid.board.get_cell(x, y) != Board.EMPTY:
							game.use_hammer_on_cell(x, y)
							current["powerups"] += 1
							return
				if game.hammer_mode:
					game.reset_hammer_button()
		1:
			if coins >= game.PRICE_ROTATE and not game.active_blocks.is_empty():
				game.get_node("RotateButton").pressed.emit()
				game.rotate_block(game.active_blocks[0])
				current["powerups"] += 1
		2:
			if coins >= game.PRICE_SHUFFLE:
				game.get_node("ShuffleButton").pressed.emit()
				current["powerups"] += 1
		3:
			if coins >= game.PRICE_UNDO and game.last_move != null:
				game.get_node("UndoButton").pressed.emit()
				current["powerups"] += 1

func buttons(parent: Node) -> Array:
	var result = []
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled:
			result.append(child)
		result.append_array(buttons(child))
	return result

func press(list: Array, text: String) -> bool:
	for button in list:
		if button.text == text:
			button.pressed.emit()
			return true
	return false

func handle_modal(game) -> void:
	var list = buttons(game.ui_layer)
	var texts = list.map(func(b): return b.text)
	if "НОВАЯ ПАРТИЯ" in texts:
		var prog = progression()
		current["score"] = game.score
		current["record"] = game.record_bonus_given
		current["lines"] = game.run_lines
		current["streak"] = game.run_max_streak
		current["combo"] = game.run_max_combo
		current["coins"] = game.run_coins
		current["xp"] = game.run_xp
		current["level_end"] = prog.current_level
		current["items"] = game.summary["item_refs"].size()
		current["achievements"] = game.summary["achievements"].size()
		current["missions"] = game.summary["missions"].size()
		current["missions_done_total"] = root.get_node("Missions").count_done()
		current["near_miss"] = (not game.record_bonus_given) and game.score >= prog.best_score * 0.75 and game.score < prog.best_score
		current["bought"] = shop_after_game(prog)
		current["coins_after"] = prog.total_coins
		games.append(current)
		current = {}
		press(list, "НОВАЯ ПАРТИЯ")
		wait_frames = 4
	elif "ПРОДОЛЖИТЬ" in texts:
		var free = game.has_method("is_free_continue") and game.is_free_continue()
		var go_on = continue_policy == "always" or (continue_policy == "half" and games.size() % 2 == 0) \
			or (continue_policy == "free" and free)
		if go_on:
			current["continues"] += 1
		press(list, "ПРОДОЛЖИТЬ" if go_on else "СДАТЬСЯ")
		wait_frames = 3
	elif "ЗАБРАТЬ" in texts:
		press(list, "ЗАБРАТЬ")
		wait_frames = 2
	elif "ИГРАТЬ" in texts:
		press(list, "ИГРАТЬ")
	elif "ЗАКРЫТЬ" in texts:
		press(list, "ЗАКРЫТЬ")
	else:
		game.handle_back()
		wait_frames = 2

# Покупки в профиле: игрок, которому некуда тратить монеты, берёт закрытый предмет раньше уровня
func shop_after_game(prog) -> int:
	if shop_reserve < 0:
		return 0
	var count = 0
	while true:
		var best = prog.best_affordable_item()
		if best.is_empty() or prog.total_coins - int(best["price"]) < shop_reserve:
			break
		if not prog.buy_item(best["type"], best["id"]):
			break
		bought.append("%s:%s" % [best["type"], best["id"]])
		count += 1
	return count

func finish() -> bool:
	var prog = progression()
	var ach = root.get_node("Achievements")
	frame_ms.sort()
	place_ms.sort()
	var result = {
		"persona": persona, "skill": skill, "zen": zen, "games": games,
		"level": prog.current_level, "rank": prog.get_rank(), "coins": prog.total_coins,
		"best": prog.best_score,
		"avatars": prog.unlocked_avatars.size(), "frames": prog.unlocked_frames.size(),
		"themes": prog.unlocked_themes.size(), "effects": prog.unlocked_effects.size(), "colors": prog.unlocked_colors.size(),
		"achievement_tiers": ach.get_total_progress()["unlocked"],
		"next_reward": prog.get_next_special_reward(),
		"daily_missions_done": root.get_node("Missions").count_done(),
		"tutorial_seen": tutorial_seen, "resumes_ok": resumes_ok, "resumes_bad": resumes_bad,
		"frame_median": frame_ms[frame_ms.size() / 2] if not frame_ms.is_empty() else 0.0,
		"frame_p99": frame_ms[int(frame_ms.size() * 0.99)] if not frame_ms.is_empty() else 0.0,
		"place_median": place_ms[place_ms.size() / 2] if not place_ms.is_empty() else 0.0,
		"place_max": place_ms[-1] if not place_ms.is_empty() else 0.0,
		"problems": problems, "seconds": (Time.get_ticks_msec() - start_time) / 1000.0,
		"bought": bought, "coins_spent": prog.coins_spent, "best_zen": prog.best_zen_score,
	}
	print("PERSONA_RESULT " + JSON.stringify(result))
	return true
