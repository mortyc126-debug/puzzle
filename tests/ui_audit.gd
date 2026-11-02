extends SceneTree

## Аудит читаемости интерфейса: проходит игровой экран, все разделы профиля, настройки,
## «Как играть», «Конфиденциальность», задания и итоги; на каждом экране считает видимые надписи
## мельче 20 px (с учётом масштаба), обрезанные многоточием и налезающие друг на друга (надписи,
## кнопки и плашки одного слоя — окно поверх экрана считается отдельным слоем), сохраняет скриншоты и проверяет
## кнопку «Назад» и подсказку на бонусе без монет. Нужно окно (скриншоты), без --headless:
##   godot --path . --fixed-fps 60 -s tests/ui_audit.gd -- --out=/путь/к/папке [--zen] [--theme=space]
## В выводе — строки «AUDIT экран: надписей N, мельче 20: 0, обрезано: 0, вне экрана: 0, наложений: 0» и «CHECK …».
## Сохранения игрока не пострадают: убираются в user://bot_backup/ и возвращаются в конце
## (как в tests/bot_play.gd).

var out := ""
var zen := false
var theme_id := ""
var edge := false  # --edge: крайние значения — длинное имя и титул, 500-й уровень, огромные числа
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
			"edge": edge = true
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
		# Оформление, ради которого тратят монеты: титул, цвет и свечение имени, улучшенные аватарка и рамка
		prog.owned_titles.append("quiet")
		prog.player_title = "quiet"
		prog.owned_name_colors.append("gold")
		prog.name_color = "gold"
		prog.name_glow_owned = true
		prog.name_glow = true
		prog.item_tiers["avatar:%d" % prog.player_avatar] = 2
		prog.item_tiers["frame:%d" % prog.player_frame] = 1
		if edge:
			prog.player_name = "ЖЖЖЖЖЖЖЖЖЖ"
			prog.current_level = 500
			prog.current_xp = 0
			prog.total_coins = 2000000000
			prog.best_score = 9999999
			prog.total_games_played = 99999
			var longest = ""
			for def in prog.TITLES:
				if def["name"].length() > longest.length():
					longest = def["name"]
					prog.player_title = def["id"]
			if not prog.owned_titles.has(prog.player_title):
				prog.owned_titles.append(prog.player_title)
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
	# Коллекции ниже первого экрана: окраски (под кубиками) и фоны (под темами) + карточки закрытых
	steps.append_array([
		func(game):
			var profile = find_modal(game, "Profile")
			profile.get_node("CustomizeContainer").current_tab = 2
			scroll_to(profile, "ОКРАСКА"),
		func(_game): shot("profile_paints"),
		func(game): find_modal(game, "Profile").show_locked_card("paint", 5),
		func(_game): shot("paint_locked"),
		func(game): game.handle_back(),
		func(game):
			var profile = find_modal(game, "Profile")
			profile.get_node("CustomizeContainer").current_tab = 3
			scroll_to(profile, "ФОНЫ"),
		func(_game): shot("profile_backdrops"),
		func(game): find_modal(game, "Profile").show_locked_card("backdrop", 8),
		func(_game): shot("backdrop_locked"),
		func(game): game.handle_back(),
	])
	steps.append_array([
		func(game): find_modal(game, "Profile").show_item_card("frame", root.get_node("Progression").player_frame),
		func(_game): shot("item_card_upgrade"),
		func(game): game.handle_back(),
		func(game): find_modal(game, "Profile").show_title_popup(),
		func(_game): shot("title_popup"),
		func(game):
			game.handle_back()
			print("CHECK «Назад» закрыл окно титулов, профиль открыт: ", "да" if find_modal(game, "Profile") != null else "НЕТ"),
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
		# Испытание дня: поле с целью и ходами, затем итоги неудачной попытки
		func(_game):
			var challenge = root.get_node("Challenge")
			if not challenge.begin():
				print("CHECK испытание началось: НЕТ")
			reload_current_scene()
			return 40,
		func(game):
			if game.is_input_blocked():
				game.handle_back()
			print("CHECK поле испытания: ", "да" if not game.challenge.is_empty() and not game.get_node("HammerButton").visible else "НЕТ"),
		func(_game): shot("challenge"),
		func(game):
			game.finish_challenge(false)
			return 90,
		func(_game): shot("challenge_result"),
	])

# Прокручивает открытый раздел профиля до надписи, начинающейся с prefix
func scroll_to(profile: Node, prefix: String) -> void:
	for label in profile.find_children("*", "Label", true, false):
		if label.text.begins_with(prefix) and label.is_visible_in_tree():
			var parent = label.get_parent()
			while parent and not parent is ScrollContainer:
				parent = parent.get_parent()
			if parent:
				parent.scroll_vertical = int(label.global_position.y - parent.global_position.y + parent.scroll_vertical - 10)
			return
	print("CHECK раздел «%s» в профиле: НЕТ" % prefix)

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
	var offscreen: Array = []
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
		# Надпись за краем экрана или раздутая по высоте (так пряталась цель испытания) —
		# кроме содержимого прокрутки: оно законно уходит за край
		var rect = node.get_global_rect()
		if not in_scroll(node) and (rect.size.y > 700.0 or not root.get_visible_rect().intersects(rect)):
			offscreen.append(text.replace("\n", " ").left(30))
		if node is Label and node.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and not node.autowrap_mode:
			var font = node.get_theme_font("font")
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > node.size.x + 1:
				cut.append(text.left(40))
	var overlaps = find_overlaps()
	print("AUDIT %s: надписей %d, мельче 20: %d, обрезано: %d, вне экрана: %d, наложений: %d" % [screen, total, small.size(),
		cut.size(), offscreen.size(), overlaps.size()])
	if not overlaps.is_empty():
		print("  наложения: ", " | ".join(overlaps.slice(0, 8)))
	if not offscreen.is_empty():
		print("  вне экрана: ", " | ".join(offscreen))
	if not small.is_empty():
		print("  мелкие: ", ", ".join(small.slice(0, 14)))
	if not cut.is_empty():
		print("  обрезаны: ", " | ".join(cut))

# Надписи, кнопки и плашки, которые залезают друг на друга. Сравниваются элементы одного слоя
# (экран, окно поверх него, всплывающая подсказка); родитель и потомок не сравниваются.
# У однострочной надписи берётся сам текст, а не весь её прямоугольник: широкая надпись
# с текстом по центру не «налезает» на соседей пустыми краями.
func find_overlaps() -> Array:
	var items = []
	for node in all_nodes(root):
		var is_pill = node is PanelContainer and node.theme_type_variation == &"Pill"
		if not (node is Label or node is Button or is_pill):
			continue
		if not node.is_visible_in_tree() or node.modulate.a < 0.05:
			continue
		if node is Label and node.text.strip_edges() == "":
			continue
		if node is Button and node.text.strip_edges() == "" and node.icon == null:
			continue
		var rect = visible_rect(node, content_rect(node))
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			continue
		items.append([node, rect, layer_of(node)])
	var result = []
	for i in range(items.size()):
		for j in range(i + 1, items.size()):
			var a = items[i]
			var b = items[j]
			if a[2] != b[2] or a[0].is_ancestor_of(b[0]) or b[0].is_ancestor_of(a[0]):
				continue
			var inter: Rect2 = a[1].intersection(b[1])
			if inter.size.x > 3.0 and inter.size.y > 3.0:
				result.append("%s ↔ %s" % [describe(a[0]), describe(b[0])])
	return result

func content_rect(node: Control) -> Rect2:
	var rect = node.get_global_rect()
	if node is Label and not node.autowrap_mode and not node.text.contains("\n"):
		var font = node.get_theme_font("font")
		var font_size = node.get_theme_font_size("font_size")
		var scale = node.get_global_transform().get_scale().x
		var width = minf(font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * scale, rect.size.x)
		match node.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				rect.position.x += (rect.size.x - width) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				rect.position.x += rect.size.x - width
		rect.size.x = width
		# По высоте — строка текста без межстрочных полей (у крупного счёта они в треть высоты)
		var line_height = minf(font.get_height(font_size) * scale, rect.size.y)
		match node.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER:
				rect.position.y += (rect.size.y - line_height) / 2.0
			VERTICAL_ALIGNMENT_BOTTOM:
				rect.position.y += rect.size.y - line_height
		rect.position.y += line_height * 0.14
		rect.size.y = line_height * 0.72
	return rect

# Часть прямоугольника, видимая сквозь прокрутку
func visible_rect(node: Node, rect: Rect2) -> Rect2:
	var parent = node.get_parent()
	while parent:
		if parent is ScrollContainer:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

# Слой: ближайший предок во весь экран (затемнение окна, экран профиля или настроек) или подсказка
func layer_of(node: Node) -> int:
	var view = root.get_visible_rect().size
	var parent = node.get_parent()
	while parent:
		if parent is PanelContainer and parent.theme_type_variation == &"ToastPanel":
			return parent.get_instance_id()
		if parent is Control and parent.get_global_rect().size.x >= view.x * 0.9 and parent.get_global_rect().size.y >= view.y * 0.9 \
				and (parent is ColorRect or parent.has_node("Background")):
			return parent.get_instance_id()
		parent = parent.get_parent()
	return 0

func describe(node: Node) -> String:
	if node is Label or node is Button:
		var text: String = node.text.replace("\n", " ").left(24)
		return "«%s»" % text if text != "" else node.name
	for child in node.find_children("*", "Label", true, false):
		return "плашка «%s»" % child.text.left(20)
	return str(node.name)

func in_scroll(node: Node) -> bool:
	var parent = node.get_parent()
	while parent:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false

func all_nodes(node: Node) -> Array:
	var result = [node]
	for child in node.get_children():
		result.append_array(all_nodes(child))
	return result

# === СОХРАНЕНИЯ ИГРОКА (как в bot_play.gd) ===

const SAVE_FILES = ["progression.save", "achievements.save", "missions.save", "settings.save", "run.save", "best_score.save",
	"challenge.save", "challenge_run.save"]
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
