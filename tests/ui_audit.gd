extends SceneTree

## Аудит читаемости интерфейса: проходит игровой экран, все разделы профиля, настройки,
## «Как играть», «Конфиденциальность», задания и итоги; на каждом экране считает видимые надписи
## мельче 20 px (с учётом масштаба) и обрезанные многоточием, сохраняет скриншоты и проверяет
## кнопку «Назад» и подсказку на бонусе без монет. Нужно окно (скриншоты), без --headless:
##   godot --path . --fixed-fps 60 -s tests/ui_audit.gd -- --out=/путь/к/папке [--zen] [--theme=space]
## В выводе — строки «AUDIT экран: надписей N, мельче 20: 0, обрезано: 0» и «CHECK …».
## Сохранения игрока не пострадают: убираются в user://bot_backup/ и возвращаются в конце
## (как в tests/bot_play.gd).

var out := ""
var zen := false
var theme_id := ""
var steps: Array = []
var step_i := 0
var wait := 0
var shot_index := 0
var prepared := false
var saved_coins := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts = arg.trim_prefix("--").split("=")
		match parts[0]:
			"out": out = parts[1]
			"zen": zen = true
			"theme": theme_id = parts[1]
	DirAccess.make_dir_recursive_absolute(out)
	protect_player_saves()
	SafeFile.save_var("user://settings.save", {"sound": false, "music": false, "vibration": false, "rated": false, "zen_mode": zen})
	change_scene_to_file("res://game.tscn")

func _process(_delta: float) -> bool:
	if wait > 0:
		wait -= 1
		return false
	var game = current_scene
	if game == null or game.name != "Game" or not game.is_node_ready():
		return false
	if not prepared:
		prepared = true
		var prog = root.get_node("Progression")
		prog.current_level = 47
		prog.current_xp = 230
		prog.total_games_played = 30
		prog.best_score = 8420
		prog.total_coins = 1840
		for i in range(1, 37):
			if int(prog.get_item_unlock("avatar", i).get("level", 999)) <= 47:
				prog.unlock_item("avatar", i, false)
		if theme_id != "":
			root.get_node("ThemeManager").apply_theme(theme_id)
		prog.save_progress()
		game.clear_saved_run()
		reload_current_scene()
		wait = 10
		return false
	if steps.is_empty():
		build_steps()
	if step_i >= steps.size():
		restore_player_saves(false)
		print("сохранения игрока возвращены")
		return true
	var extra = steps[step_i].call(current_scene)
	step_i += 1
	wait = extra if extra is int else 25
	return false

func build_steps() -> void:
	steps = [
		func(game):
			if game.is_input_blocked():
				game.handle_back(),
		func(game):
			# Несколько ходов, серия и множитель — чтобы показались плашки у счёта
			game.score = 960
			game.run_xp = 140
			game.update_score_display()
			game.update_streak_display(3)
			root.get_node("Progression").score_multiplier = 2.0
			game.update_multiplier_display()
			game.update_xp_display(),
		func(_game): shot("game_tips"),
		func(_game): return 400,
		func(_game): shot("game"),
		# Бонус без монет: кнопка выключена, касание объясняет, откуда монеты
		func(game):
			var prog = root.get_node("Progression")
			saved_coins = prog.total_coins
			prog.total_coins = 5
			game.update_powerup_buttons()
			var button: Button = game.get_node("ShuffleButton")
			var screen_pos = button.get_global_rect().get_center()
			for pressed in [true, false]:
				var ev = InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = screen_pos
				ev.global_position = screen_pos
				root.push_input(ev, true),
		func(game):
			var toasts = 0
			for child in game.ui_layer.get_children():
				if child is PanelContainer and child.theme_type_variation == &"ToastPanel":
					for label in child.get_children():
						if label is Label and label.text.begins_with("Нужно 30 монет"):
							toasts += 1
			print("CHECK подсказка о монетах на выключенной кнопке: ", "есть" if toasts == 1 else "НЕТ (%d)" % toasts)
			shot("no_coins_hint")
			root.get_node("Progression").total_coins = saved_coins
			game.update_powerup_buttons()
			return 300,
		func(game): game.get_node("ProfileButton").pressed.emit(),
	]
	for tab in range(8):
		steps.append(func(game):
			var profile = find_modal(game, "Profile")
			if profile:
				profile.get_node("CustomizeContainer").current_tab = tab)
		steps.append(func(_game): shot("profile_tab_%d" % tab))
	steps.append_array([
		func(game):
			game.handle_back(),
		func(game): game.get_node("SettingsButton").pressed.emit(),
		func(_game): shot("settings"),
		func(game):
			var settings = find_modal(game, "Settings")
			for button in settings.find_children("*", "Button", true, false):
				if button.text == "Как играть":
					button.pressed.emit(),
		func(_game): shot("rules"),
		func(game):
			var settings = find_modal(game, "Settings")
			var scroll = settings.rules_overlay.find_children("*", "ScrollContainer", true, false)[0]
			scroll.scroll_vertical = 100000,
		func(_game): shot("rules_end"),
		func(game): game.handle_back(),
		func(game):
			var settings = find_modal(game, "Settings")
			for button in settings.find_children("*", "Button", true, false):
				if button.text == "Конфиденциальность":
					button.pressed.emit(),
		func(_game): shot("privacy"),
		func(game): game.handle_back(),
		func(game):
			var settings = find_modal(game, "Settings")
			print("CHECK «Назад» закрыл правила, настройки открыты: ", "да" if settings != null and settings.rules_overlay == null else "НЕТ"),
		func(game): game.handle_back(),
		func(game):
			print("CHECK «Назад» закрыл настройки: ", "да" if find_modal(game, "Settings") == null else "НЕТ"),
		func(game): game.show_tasks_popup(),
		func(_game): shot("tasks"),
		func(game): game.handle_back(),
		func(game):
			game.score = 1530
			game.game_over = true
			game.show_final_game_over(),
		func(_game): shot("game_over"),
	])

func find_modal(game, scene_name: String) -> Node:
	for child in game.ui_layer.get_children():
		if child.name == scene_name and not child.is_queued_for_deletion():
			return child
	return null

func shot(shot_name: String) -> void:
	audit(shot_name)
	var image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return
	shot_index += 1
	image.save_png("%s/%02d_%s.png" % [out, shot_index, shot_name])
	print("SHOT ", shot_name)

# Видимые надписи: размер шрифта с учётом масштаба родителей; обрезанные многоточием
func audit(screen: String) -> void:
	var small: Array = []
	var cut: Array = []
	var total = 0
	var sizes = {}
	for node in all_nodes(root):
		if not (node is Label or node is Button or node is LineEdit):
			continue
		if not node.is_visible_in_tree():
			continue
		var text: String = node.text
		if text.strip_edges() == "":
			continue
		if node.get_global_rect().size.x <= 1:
			continue
		var blocked = false
		var parent = node.get_parent()
		while parent:
			if parent is CanvasItem and parent.has_meta("dim"):
				blocked = true
			parent = parent.get_parent()
		var font_size = node.get_theme_font_size("font_size")
		var effective = font_size * node.get_global_transform().get_scale().y
		total += 1
		sizes[int(round(effective))] = sizes.get(int(round(effective)), 0) + 1
		if effective < 19.5:
			small.append("%s(%d)" % [text.replace("\n", " ").left(28), int(round(effective))])
		if node is Label and node.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and not node.autowrap_mode:
			var font = node.get_theme_font("font")
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > node.size.x + 1:
				cut.append(text.left(40))
	print("AUDIT %s: надписей %d, мельче 20: %d, обрезано: %d" % [screen, total, small.size(), cut.size()])
	if not small.is_empty():
		print("  мелкие: ", ", ".join(small.slice(0, 14)))
	if not cut.is_empty():
		print("  обрезаны: ", " | ".join(cut))

func all_nodes(node: Node) -> Array:
	var result = [node]
	for child in node.get_children():
		result.append_array(all_nodes(child))
	return result

# === СОХРАНЕНИЯ ИГРОКА (как в bot_play.gd) ===

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
