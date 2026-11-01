extends Control

## Профиль игрока: аватарка, рамка, имя, статистика и вкладки кастомизации.
## Вкладки: Статистика, Цвета, Темы, Музыка, Аватарки, Рамки, Достижения.

const TAB_STATS = 0
const TAB_REWARDS = 1
const TAB_COLORS = 2
const TAB_THEMES = 3
const TAB_EFFECTS = 4
const TAB_AVATARS = 5
const TAB_FRAMES = 6
const TAB_ACHIEVEMENTS = 7

const PATH_TABS = "CustomizeContainer"
const PATH_STATS = "CustomizeContainer/📊 Statistics/StatsContent"
const PATH_COLORS = "CustomizeContainer/🎨 Colors/ColorsContent"
const PATH_THEMES = "CustomizeContainer/🌌 Themes/ThemesList"
const PATH_EFFECTS = "CustomizeContainer/✨ Effects/EffectsList"
const PATH_REWARDS = "CustomizeContainer/🎁 Rewards/RewardsList"
const PATH_AVATARS = "CustomizeContainer/👤 Avatars/AvatarsList"
const PATH_FRAMES = "CustomizeContainer/🖼️ Frames/FramesList"
const PATH_ACHIEVEMENTS = "CustomizeContainer/🏆 Achievements/AchievementsContent"

const GOLD = Color(1, 0.84, 0)

var progression = null
var all_colors = ItemsDB.block_colors
var best_value_label: Label
var coins_value_label: Label
var built_tabs = {}  # Вкладки строятся при первом открытии — профиль открывается быстрее
var popups: Array = []  # Открытые окна поверх профиля (закрываются кнопкой «Назад» по очереди)

func _ready():
	progression = Progression

	$BackButton.pressed.connect(_on_back_pressed)
	style_header()
	var edit_name_btn = get_node_or_null("EditNameButton")
	if edit_name_btn:
		edit_name_btn.pressed.connect(show_name_edit_popup)

	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)

	ScreenStyle.fit_to_screen(self, 0.25, get_node_or_null(PATH_TABS))
	update_profile()
	update_tab_titles()
	auto_open_new_items_tab()
	if tabs:
		ensure_tab_built(tabs.current_tab)

func ensure_tab_built(tab: int):
	if built_tabs.has(tab):
		return
	built_tabs[tab] = true
	match tab:
		TAB_STATS:
			create_stats_list()
		TAB_REWARDS:
			create_rewards_list()
		TAB_COLORS:
			create_colors_list()
		TAB_THEMES:
			create_themes_list()
		TAB_EFFECTS:
			create_effects_list()
		TAB_AVATARS:
			create_avatars_list()
		TAB_FRAMES:
			create_frames_list()
		TAB_ACHIEVEMENTS:
			create_achievements_list()

# === ШАПКА ===

# Фон, кнопка «Назад», значок правки на аватарке, плашки «рекорд» и «монеты»
func style_header():
	ScreenStyle.apply_background(get_node_or_null("Background"))
	ScreenStyle.style_back_button($BackButton)

	var edit_name_btn = get_node_or_null("EditNameButton")
	if edit_name_btn:
		edit_name_btn.theme_type_variation = &"IconButton"
		edit_name_btn.icon = load("res://assets/ui/icons/edit.svg")
		edit_name_btn.expand_icon = true
		edit_name_btn.add_theme_constant_override("icon_max_width", 28)

	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.theme_type_variation = &"DisplayLabel"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var row = HBoxContainer.new()
	row.position = Vector2(150, 346)
	row.size = Vector2(600, 64)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	best_value_label = add_stat_pill(row, "trophy", GOLD)
	coins_value_label = add_stat_pill(row, "coin", Color.WHITE)

func add_stat_pill(parent: Control, icon_name: String, tint: Color) -> Label:
	var pill = PanelContainer.new()
	pill.theme_type_variation = &"Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var picture = TextureRect.new()
	picture.texture = load("res://assets/ui/icons/%s.svg" % icon_name)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(30, 30)
	picture.modulate = tint
	line.add_child(picture)
	var label = Label.new()
	label.theme_type_variation = &"DisplayLabel"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", GOLD)
	line.add_child(label)
	pill.add_child(line)
	parent.add_child(pill)
	return label

func update_profile():
	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.text = progression.player_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		adjust_text_size(name_label, 520)

	var avatar_display = get_node_or_null("AvatarDisplay")
	if avatar_display:
		avatar_display.texture = ItemsDB.get_avatar_texture(progression.player_avatar)

	var frame_display = get_node_or_null("FrameDisplay")
	if frame_display:
		frame_display.texture = ItemsDB.get_frame_texture(progression.player_frame)

	var level_label = get_node_or_null("AvatarLevelLabel")
	if level_label:
		level_label.text = str(progression.current_level)

	if best_value_label:
		best_value_label.text = "%d" % progression.best_score
	if coins_value_label:
		coins_value_label.text = "%d" % progression.total_coins

	update_stats_labels()

# Шрифт имени уменьшается, пока имя не влезет в табличку
func adjust_text_size(label: Label, max_width: float):
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size = 44
	while font_size > 22:
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x <= max_width:
			break
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)

func update_game_profile_button():
	var game = get_node_or_null("/root/Game")
	if game:
		game.refresh_profile_button()
		game.update_profile_name_display()

# === ВКЛАДКИ И ИНДИКАТОРЫ NEW ===

func update_tab_titles():
	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs == null:
		return
	# Восемь подписей не помещаются в ширину: подпись есть только у открытой вкладки,
	# у остальных — иконка и точка, если внутри есть новое
	var flags = progression.has_new_items
	# [вкладка, название, иконка, флаг «новое»]
	var titles = [
		[TAB_STATS, "Статистика", "chart", ""],
		[TAB_REWARDS, "Путь наград", "gift", ""],
		[TAB_COLORS, "Цвета", "palette", "colors"],
		[TAB_THEMES, "Темы", "layers", "themes"],
		[TAB_EFFECTS, "Эффекты", "sparkle", "effects"],
		[TAB_AVATARS, "Аватарки", "user", "avatars"],
		[TAB_FRAMES, "Рамки", "frame", "frames"],
		[TAB_ACHIEVEMENTS, "Достижения", "trophy", "achievements"],
	]
	tabs.add_theme_constant_override("icon_max_width", 26)
	for entry in titles:
		var has_new = entry[3] != "" and flags.get(entry[3], false)
		var title = entry[1] if entry[0] == tabs.current_tab else ""
		if has_new:
			title += " •" if title != "" else "•"
		tabs.set_tab_title(entry[0], title)
		tabs.set_tab_icon(entry[0], icon_texture(entry[2]))

# Открытая вкладка считается просмотренной
func _on_tab_changed(tab: int):
	ensure_tab_built(tab)
	var category = ""
	match tab:
		TAB_THEMES:
			category = "themes"
		TAB_EFFECTS:
			category = "effects"
		TAB_COLORS:
			category = "colors"
		TAB_AVATARS:
			category = "avatars"
		TAB_FRAMES:
			category = "frames"
		TAB_ACHIEVEMENTS:
			category = "achievements"
	if category != "":
		progression.mark_items_as_seen(category)
		var game = get_node_or_null("/root/Game")
		if game:
			game.update_achievements_indicator()
	update_tab_titles()

func auto_open_new_items_tab():
	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs == null:
		return
	var order = [
		["achievements", TAB_ACHIEVEMENTS],
		["themes", TAB_THEMES],
		["avatars", TAB_AVATARS],
		["frames", TAB_FRAMES],
		["effects", TAB_EFFECTS],
		["colors", TAB_COLORS],
	]
	for pair in order:
		if progression.has_new_items.get(pair[0], false):
			tabs.current_tab = pair[1]
			_on_tab_changed(pair[1])
			return

func icon_texture(icon_name: String) -> Texture2D:
	return load("res://assets/ui/icons/%s.svg" % icon_name)

# === СТАТИСТИКА ===

# Статистика — карточками: сверху уровень с полосой опыта, ниже цифры в две колонки
var stat_values = {}  # ключ -> Label со значением
var level_card = {}   # части карточки уровня

const STAT_CARDS = [
	["games", "Сыграно партий"], ["best", "Рекорд"],
	["average", "Средний счёт"], ["lines", "Очищено линий"],
	["pieces", "Поставлено фигур"], ["streak", "Лучшая серия"],
	["combo", "Линий за один ход"], ["perfect", "Чистых полей"],
	["time", "Время в игре"], ["coins", "Заработано монет"],
]

func create_stats_list():
	var stats_content = get_node_or_null(PATH_STATS)
	if stats_content == null:
		return
	for child in stats_content.get_children():
		child.queue_free()
	stats_content.add_theme_constant_override("separation", 16)
	# Без флага EXPAND содержимое ScrollContainer остаётся шириной по минимуму, а не на всю вкладку
	stats_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card = PanelContainer.new()
	card.theme_type_variation = &"HudPanel"
	stats_content.add_child(card)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	level_card["rank"] = make_label("", 30, GOLD, HORIZONTAL_ALIGNMENT_LEFT, false)
	level_card["rank"].theme_type_variation = &"DisplayLabel"
	box.add_child(level_card["rank"])
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	level_card["bar"] = bar
	level_card["xp"] = make_label("", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	box.add_child(level_card["xp"])
	level_card["next"] = make_label("", 20, Color(0.8, 0.84, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(level_card["next"])
	level_card["collection"] = make_label("", 20, Color(0.8, 0.84, 0.98), HORIZONTAL_ALIGNMENT_LEFT, false)
	box.add_child(level_card["collection"])

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	stats_content.add_child(grid)
	for entry in STAT_CARDS:
		var stat_card = PanelContainer.new()
		stat_card.theme_type_variation = &"HudPanel"
		stat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(stat_card)
		var stat_box = VBoxContainer.new()
		stat_box.add_theme_constant_override("separation", 0)
		stat_card.add_child(stat_box)
		var value = make_label("0", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
		value.theme_type_variation = &"DisplayLabel"
		stat_box.add_child(value)
		var caption = make_label(entry[1], 18, Color(0.7, 0.74, 0.92), HORIZONTAL_ALIGNMENT_LEFT, false)
		stat_box.add_child(caption)
		stat_values[entry[0]] = value
	update_stats_labels()

func update_stats_labels():
	if stat_values.is_empty():
		return
	var values = {
		"games": str(progression.total_games_played),
		"best": str(progression.best_score),
		"average": str(progression.get_average_score()),
		"lines": str(progression.total_lines_cleared),
		"pieces": str(progression.total_pieces_placed),
		"streak": "×%d" % progression.max_streak,
		"combo": str(progression.max_combo_achieved),
		"perfect": str(progression.perfect_clears),
		"time": progression.format_play_time(),
		"coins": str(progression.total_coins_earned),
	}
	for key in values.keys():
		stat_values[key].text = values[key]

	level_card["rank"].text = "Уровень %d · %s" % [progression.current_level, progression.get_rank()]
	var bar: ProgressBar = level_card["bar"]
	if progression.is_max_level():
		bar.max_value = 1
		bar.value = 1
		level_card["xp"].text = "Максимальный уровень — вы прошли всю игру!"
		level_card["next"].text = ""
	else:
		bar.max_value = progression.get_xp_for_next_level()
		bar.value = progression.current_xp
		level_card["xp"].text = "Опыт: %d / %d" % [progression.current_xp, progression.get_xp_for_next_level()]
		var next = progression.get_next_special_reward()
		level_card["next"].text = "" if next.is_empty() else \
			"На уровне %d: %s" % [next["level"], ", ".join(next["lines"])]
	var collection = progression.get_collection_progress()
	level_card["collection"].text = "Коллекция: %d из %d предметов" % [collection["have"], collection["total"]]

# === ЦВЕТА БЛОКОВ (тема «Классика») ===

func create_colors_list():
	var content = get_node_or_null(PATH_COLORS)
	if content == null:
		return
	var slots_label = content.get_node_or_null("SlotsLabel")
	var active_container = content.get_node_or_null("ActiveSlots")
	var all_colors_container = content.get_node_or_null("AllColors")
	if slots_label == null or active_container == null or all_colors_container == null:
		return

	var active_count = progression.active_colors.size()
	var max_slots = progression.max_color_slots
	slots_label.text = "Слоты: %d/%d" % [active_count, max_slots]
	if not ThemeManager.current.use_player_colors:
		slots_label.text += "  (цвета действуют в теме «Классика»)"

	for child in active_container.get_children():
		child.queue_free()

	for i in range(Progression.MAX_COLOR_SLOTS):
		var slot_container = Control.new()
		slot_container.custom_minimum_size = Vector2(80, 80)

		var slot = ColorRect.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.size = Vector2(80, 80)
		slot_container.add_child(slot)

		var overlay_label = Label.new()
		overlay_label.size = Vector2(80, 80)
		overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overlay_label.add_theme_font_size_override("font_size", 30)
		overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if i < active_count:
			overlay_label.free()  # подпись нужна только пустым и закрытым слотам
			slot.color = all_colors[progression.active_colors[i]]
			var remove_btn = Button.new()
			remove_btn.text = "×"
			remove_btn.size = Vector2(80, 80)
			remove_btn.flat = true
			remove_btn.add_theme_font_size_override("font_size", 28)
			remove_btn.pressed.connect(_on_remove_color.bind(i))
			slot_container.add_child(remove_btn)
		elif i < max_slots:
			slot.color = Color(0.3, 0.3, 0.3)
			overlay_label.text = "+"
			slot_container.add_child(overlay_label)
		else:
			slot.color = Color(0.15, 0.15, 0.15)
			overlay_label.free()
			var lock = TextureRect.new()
			lock.texture = icon_texture("lock")
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.position = Vector2(22, 22)
			lock.size = Vector2(36, 36)
			lock.modulate = Color(0.6, 0.62, 0.75)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_container.add_child(lock)

		active_container.add_child(slot_container)

	for child in all_colors_container.get_children():
		child.queue_free()

	for i in range(all_colors.size()):
		var color_container = Control.new()
		color_container.custom_minimum_size = Vector2(80, 80)

		var color_rect = ColorRect.new()
		color_rect.size = Vector2(80, 80)
		color_rect.color = all_colors[i]
		color_container.add_child(color_rect)

		if not progression.is_unlocked("color", i):
			color_rect.color = Color(all_colors[i], 0.25)
			var lock_label = Label.new()
			lock_label.text = "ур. %d" % ItemsDB.get_color_unlock(i).get("level", 0)
			lock_label.size = Vector2(80, 80)
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_label.add_theme_font_size_override("font_size", 20)
			lock_label.tooltip_text = ItemsDB.color_names[i]
			color_container.add_child(lock_label)
			all_colors_container.add_child(color_container)
			continue

		var select_btn = Button.new()
		select_btn.size = Vector2(80, 80)
		select_btn.flat = true
		if i in progression.active_colors:
			select_btn.icon = icon_texture("check")
			select_btn.expand_icon = true
			select_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			select_btn.add_theme_constant_override("icon_max_width", 44)
			select_btn.add_theme_color_override("icon_normal_color", Color.WHITE)
		select_btn.pressed.connect(_on_select_color.bind(i))
		color_container.add_child(select_btn)

		all_colors_container.add_child(color_container)

func _on_select_color(color_index: int):
	if color_index in progression.active_colors or not progression.is_unlocked("color", color_index):
		return
	if progression.active_colors.size() >= progression.max_color_slots:
		return
	progression.active_colors.append(color_index)
	progression.request_save()
	create_colors_list()

func _on_remove_color(slot_index: int):
	if slot_index < progression.active_colors.size():
		progression.active_colors.remove_at(slot_index)
		progression.request_save()
		create_colors_list()

# === ТЕМЫ ===

func create_themes_list():
	var container: GridContainer = get_node_or_null(PATH_THEMES)
	if container == null:
		return
	container.columns = 2
	for child in container.get_children():
		child.queue_free()

	for block_theme in ThemeManager.themes:
		var unlocked = progression.is_unlocked("theme", block_theme.id)
		var selected = block_theme == ThemeManager.current

		var card = Button.new()
		card.custom_minimum_size = Vector2(395, 340)
		card.pressed.connect(_on_theme_clicked.bind(block_theme.id))
		if selected:
			card.add_theme_stylebox_override("normal", make_highlight_box(block_theme.accent_color))

		var box = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.position = Vector2(18, 14)
		box.size = Vector2(359, 312)
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)

		var preview = ThemePreview.new()
		preview.custom_minimum_size = Vector2(359, 210)
		preview.set_theme_resource(block_theme, not unlocked)
		box.add_child(preview)

		box.add_child(make_label(block_theme.display_name, 30, ItemsDB.get_rarity_color(block_theme.rarity)))
		var status = "Выбрана" if selected else ("Нажмите, чтобы выбрать" if unlocked else ItemsDB.get_unlock_text(block_theme.unlock))
		box.add_child(make_label(status, 20, GOLD if selected else Color(0.8, 0.82, 0.95)))

		container.add_child(card)

func _on_theme_clicked(theme_id: String):
	var block_theme = ThemeManager.get_theme_by_id(theme_id)
	if block_theme == null:
		return
	if not progression.is_unlocked("theme", theme_id):
		show_info_popup(block_theme.display_name, block_theme.description + "\n\n" + ItemsDB.get_unlock_text(block_theme.unlock))
		return
	progression.select_theme(theme_id)
	create_themes_list()
	if built_tabs.has(TAB_COLORS):
		create_colors_list()

# === ЭФФЕКТЫ ОЧИСТКИ ===

func create_effects_list():
	var container: GridContainer = get_node_or_null(PATH_EFFECTS)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

	for effect_id in ItemsDB.get_effect_ids():
		var data = ItemsDB.get_effect_data(effect_id)
		var unlocked = progression.is_unlocked("effect", effect_id)
		var selected = effect_id == progression.player_effect

		var card = Button.new()
		card.custom_minimum_size = Vector2(262, 270)
		card.pressed.connect(_on_effect_clicked.bind(effect_id))
		if selected:
			card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))

		var preview = EffectPreview.new()
		preview.position = Vector2(16, 14)
		preview.size = Vector2(230, 150)
		preview.setup(data.get("kind", "sparks"), ThemeManager.get_block_color(effect_id))
		if not unlocked:
			preview.modulate = Color(0.35, 0.35, 0.4)
		card.add_child(preview)

		var title = make_label(data.get("name", "?"), 24, ItemsDB.get_rarity_color(data.get("rarity", "COMMON")))
		title.position = Vector2(8, 170)
		title.size = Vector2(246, 34)
		card.add_child(title)

		var status = "Выбран" if selected else ("Нажмите, чтобы выбрать" if unlocked else ItemsDB.get_unlock_text(data.get("unlock", {})))
		var status_label = make_label(status, 17, GOLD if selected else Color(0.8, 0.82, 0.95))
		status_label.position = Vector2(8, 206)
		status_label.size = Vector2(246, 56)
		card.add_child(status_label)

		container.add_child(card)

func _on_effect_clicked(effect_id: int):
	var data = ItemsDB.get_effect_data(effect_id)
	if not progression.is_unlocked("effect", effect_id):
		show_info_popup(data.get("name", "?"), data.get("description", "") + "\n\n" + ItemsDB.get_unlock_text(data.get("unlock", {})))
		return
	progression.player_effect = effect_id
	progression.request_save()
	create_effects_list()

# === ПУТЬ НАГРАД ===
# Все уровни, где есть что-то кроме монет. Пройденные — отмечены, ближайший — подсвечен.

func create_rewards_list():
	var container = get_node_or_null(PATH_REWARDS)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

	var collection = progression.get_collection_progress()
	container.add_child(make_label("Вы на уровне %d · %s" % [progression.current_level, progression.get_rank()], 30, GOLD))
	container.add_child(make_label("Собрано %d из %d предметов" % [collection["have"], collection["total"]], 22, Color(0.8, 0.84, 0.98)))

	var next_row = null
	for level in range(2, Progression.MAX_LEVEL + 1):
		var lines = progression.get_level_reward_lines(level, false)
		if lines.is_empty():
			continue
		var reached = level <= progression.current_level
		var is_next = next_row == null and not reached

		var panel = PanelContainer.new()
		var accent = GOLD if is_next else (Color(0.45, 0.85, 0.55) if reached else Color(0.35, 0.38, 0.6))
		panel.add_theme_stylebox_override("panel", make_highlight_box(accent, 0.25 if is_next else 0.12))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)

		var level_label = make_label(str(level), 34, accent, HORIZONTAL_ALIGNMENT_CENTER, false)
		level_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(level_label)

		var text = make_label("\n".join(lines), 22, Color.WHITE if reached or is_next else Color(0.75, 0.77, 0.9), HORIZONTAL_ALIGNMENT_LEFT, false)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		var status = make_label("Получено" if reached else ("Следующая" if is_next else "—"), 22, accent, HORIZONTAL_ALIGNMENT_CENTER, false)
		status.custom_minimum_size = Vector2(130, 0)
		row.add_child(status)

		container.add_child(panel)
		if is_next:
			next_row = panel

	# Прокручиваем к ближайшей награде
	if next_row:
		await get_tree().process_frame
		await get_tree().process_frame
		var scroll = get_node_or_null("CustomizeContainer/🎁 Rewards")
		if scroll and is_instance_valid(next_row):
			scroll.scroll_vertical = maxi(0, int(next_row.position.y) - 140)

# === АВАТАРКИ И РАМКИ ===

func create_avatars_list():
	fill_items_grid(get_node_or_null(PATH_AVATARS), "avatar", ItemsDB.get_avatar_ids(), progression.player_avatar)

func create_frames_list():
	fill_items_grid(get_node_or_null(PATH_FRAMES), "frame", ItemsDB.get_frame_ids(), progression.player_frame)

func fill_items_grid(container: GridContainer, item_type: String, ids: Array, selected_id: int):
	if container == null:
		return
	container.columns = 5
	for child in container.get_children():
		child.queue_free()

	for item_id in ids:
		var data = ItemsDB.get_avatar_data(item_id) if item_type == "avatar" else ItemsDB.get_frame_data(item_id)
		var texture = ItemsDB.get_avatar_texture(item_id) if item_type == "avatar" else ItemsDB.get_frame_texture(item_id)
		var unlocked = progression.is_unlocked(item_type, item_id)

		var card = Button.new()
		card.custom_minimum_size = Vector2(156, 190)
		card.pressed.connect(show_item_card.bind(item_type, item_id))
		if item_id == selected_id:
			card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))

		var picture = TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(13, 12)
		picture.size = Vector2(130, 130)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			picture.modulate = Color(0.25, 0.25, 0.3)
		card.add_child(picture)

		var caption = make_label(data.get("name", "?") if unlocked else "Закрыто", 18,
			ItemsDB.get_rarity_color(data.get("rarity", "COMMON")))
		caption.position = Vector2(4, 146)
		caption.size = Vector2(148, 36)
		card.add_child(caption)

		container.add_child(card)

func show_item_card(item_type: String, item_id: int):
	var data = ItemsDB.get_avatar_data(item_id) if item_type == "avatar" else ItemsDB.get_frame_data(item_id)
	if data.is_empty():
		return
	var unlocked = progression.is_unlocked(item_type, item_id)
	var box = open_popup(580)

	var preview_holder = CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(540, 230)
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(220, 220)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = ItemsDB.get_avatar_texture(item_id) if item_type == "avatar" else ItemsDB.get_frame_texture(item_id)
	if not unlocked:
		preview.modulate = Color(0.35, 0.35, 0.4)
	preview_holder.add_child(preview)
	box.add_child(preview_holder)

	var rarity = data.get("rarity", "COMMON")
	box.add_child(make_label(data.get("name", "?"), 36, Color.WHITE))
	box.add_child(make_label(ItemsDB.get_rarity_name(rarity), 22, ItemsDB.get_rarity_color(rarity)))
	box.add_child(HSeparator.new())
	box.add_child(make_label(data.get("description", ""), 22, Color(0.88, 0.9, 1)))
	if not unlocked:
		box.add_child(make_label(ItemsDB.get_unlock_text(data.get("unlock", {})), 22, GOLD))

	var selected = (item_type == "avatar" and item_id == progression.player_avatar) \
		or (item_type == "frame" and item_id == progression.player_frame)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var select_btn = Button.new()
	select_btn.custom_minimum_size = Vector2(240, 76)
	select_btn.add_theme_font_size_override("font_size", 28)
	if selected:
		select_btn.text = "ВЫБРАНО"
		select_btn.disabled = true
	elif not unlocked:
		select_btn.text = "ЗАКРЫТО"
		select_btn.disabled = true
	else:
		select_btn.text = "ВЫБРАТЬ"
		select_btn.pressed.connect(_on_select_item.bind(item_type, item_id, box))
	row.add_child(select_btn)

	var close_btn = Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.custom_minimum_size = Vector2(240, 76)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(close_popup.bind(box))
	row.add_child(close_btn)

func _on_select_item(item_type: String, item_id: int, box):
	if not progression.is_unlocked(item_type, item_id):
		return
	match item_type:
		"avatar":
			progression.player_avatar = item_id
			create_avatars_list()
		"frame":
			progression.player_frame = item_id
			create_frames_list()
	progression.request_save()
	update_profile()
	update_game_profile_button()
	close_popup(box)

# === ДОСТИЖЕНИЯ ===

func create_achievements_list():
	var content = get_node_or_null(PATH_ACHIEVEMENTS)
	if content == null:
		return
	var total = Achievements.get_total_progress()
	var progress_label = content.get_node_or_null("ProgressLabel")
	if progress_label:
		progress_label.text = "Получено ступеней: %d из %d (%.0f%%)" % [total["unlocked"], total["total"], total["percent"]]
	var progress_bar = content.get_node_or_null("TotalProgressBar")
	if progress_bar:
		progress_bar.value = total["percent"]

	var categories = content.get_node_or_null("CategoriesContainer")
	if categories == null:
		return
	for child in categories.get_children():
		child.queue_free()
	for def in Achievements.LIST:
		categories.add_child(create_achievement_card(def))

func create_achievement_card(def: Dictionary) -> Button:
	var info = Achievements.get_info(def)
	var tier: int = info["tier"]

	var card = Button.new()
	card.custom_minimum_size = Vector2(790, 132)
	card.pressed.connect(show_achievement_popup.bind(def))
	if tier > 0:
		card.add_theme_stylebox_override("normal", make_highlight_box(Achievements.get_tier_color(tier), 0.35))

	# Кубок цвета ступени (серый — ещё не получено)
	var medal = TextureRect.new()
	medal.texture = icon_texture("trophy")
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.position = Vector2(22, 34)
	medal.size = Vector2(60, 60)
	medal.modulate = Achievements.get_tier_color(tier) if tier > 0 else Color(0.42, 0.45, 0.6)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(medal)

	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(104, 12)
	box.size = Vector2(666, 108)
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var title: String = def["title"]
	if tier > 0:
		title += " — " + Achievements.get_tier_label(def, tier)
	box.add_child(make_label(title, 28, Achievements.get_tier_color(tier) if tier > 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))

	if info["completed"]:
		box.add_child(make_label("Выполнено: " + Achievements.get_description(def, info["max_tier"]), 20, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var next_text = "%s  (%s / %s)" % [Achievements.get_description(def, tier + 1),
			Achievements.format_value(def, info["value"]), Achievements.format_value(def, info["next_target"])]
		box.add_child(make_label(next_text, 20, Color(0.82, 0.85, 0.98), HORIZONTAL_ALIGNMENT_LEFT))

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(656, 16)
	bar.show_percentage = false
	bar.value = info["percent"]
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	return card

func show_achievement_popup(def: Dictionary):
	var info = Achievements.get_info(def)
	var box = open_popup(640)
	box.add_child(make_label(def["title"], 38, GOLD))
	box.add_child(make_label("Текущее значение: %s" % Achievements.format_value(def, info["value"]), 22, Color(0.85, 0.88, 1)))

	var tiers: Array = def["tiers"]
	for tier in range(1, tiers.size() + 1):
		var done = info["tier"] >= tier
		var panel = PanelContainer.new()
		if done:
			panel.add_theme_stylebox_override("panel", make_highlight_box(Achievements.get_tier_color(tier), 0.3))
		var tier_box = VBoxContainer.new()
		panel.add_child(tier_box)

		var header = Achievements.get_tier_label(def, tier) + (" — получено" if done else "")
		tier_box.add_child(make_label(header, 24, Achievements.get_tier_color(tier), HORIZONTAL_ALIGNMENT_LEFT))
		tier_box.add_child(make_label(Achievements.get_description(def, tier), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))

		var rewards = ["%d монет" % Achievements.get_reward_coins(def, tier)]
		for item in progression.find_items("achievement", [def["id"], tier]):
			rewards.append(progression.get_item_label(item["type"], item["id"]))
		tier_box.add_child(make_label("Награда: " + ", ".join(rewards), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		box.add_child(panel)

	var close_btn = Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.custom_minimum_size = Vector2(260, 70)
	close_btn.pressed.connect(close_popup.bind(box))
	box.add_child(close_btn)

# === ИМЯ ===

func show_name_edit_popup():
	# Окно выше центра: снизу его закроет экранная клавиатура
	var box = open_popup(520, 0.55)
	box.add_child(make_label("Ваше имя", 34, GOLD))

	var line_edit = LineEdit.new()
	line_edit.text = progression.player_name
	line_edit.max_length = 10
	line_edit.placeholder_text = "Введите имя"
	line_edit.custom_minimum_size = Vector2(460, 64)
	line_edit.add_theme_font_size_override("font_size", 28)
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.text_submitted.connect(func(_text): _on_name_save(line_edit, box))
	box.add_child(line_edit)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var cancel_btn = Button.new()
	cancel_btn.text = "ОТМЕНА"
	cancel_btn.custom_minimum_size = Vector2(200, 64)
	cancel_btn.pressed.connect(close_popup.bind(box))
	row.add_child(cancel_btn)

	var save_btn = Button.new()
	save_btn.text = "СОХРАНИТЬ"
	save_btn.custom_minimum_size = Vector2(200, 64)
	save_btn.pressed.connect(_on_name_save.bind(line_edit, box))
	row.add_child(save_btn)

	line_edit.grab_focus()

func _on_name_save(line_edit: LineEdit, box):
	var new_name = line_edit.text.strip_edges()
	if new_name == "":
		new_name = "Игрок"
	progression.player_name = new_name
	progression.request_save()
	update_profile()
	update_game_profile_button()
	close_popup(box)

# === ВСПОМОГАТЕЛЬНОЕ ===

# wrap = false для коротких подписей: перенос строк дорог при раскладке длинных списков
func make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		wrap: bool = true) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# Рамка выделения для выбранной карточки
func make_highlight_box(color: Color, fill_alpha: float = 0.2) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color(color, fill_alpha)
	box.border_color = color
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	return box

# Окно поверх профиля: затемнение + панель по центру. Возвращает VBox для содержимого.
# area_bottom < 1 — окно центрируется в верхней части экрана (например, над клавиатурой).
func open_popup(min_width: float, area_bottom: float = 1.0) -> VBoxContainer:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_bottom = area_bottom

	var panel = PanelContainer.new()
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(min_width, 0)
	panel.add_child(scroll)

	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(min_width - 20, 0)
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	# Высоту ограничиваем экраном: длинные списки прокручиваются
	box.resized.connect(func(): scroll.custom_minimum_size.y = minf(box.size.y, size.y - 220))
	box.set_meta("overlay", overlay)
	popups.append(box)
	return box

func close_popup(box: Control):
	popups.erase(box)
	if box and is_instance_valid(box):
		var overlay = box.get_meta("overlay", null)
		if overlay and is_instance_valid(overlay):
			overlay.queue_free()

func show_info_popup(title: String, text: String):
	var box = open_popup(560)
	box.add_child(make_label(title, 34, GOLD))
	box.add_child(make_label(text, 22, Color(0.88, 0.9, 1)))
	var close_btn = Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(220, 70)
	close_btn.pressed.connect(close_popup.bind(box))
	box.add_child(close_btn)

func _on_back_pressed():
	var game = get_node_or_null("/root/Game")
	if game:
		game.update_achievements_indicator()
	queue_free()

# Кнопка «Назад» на телефоне (вызывает Game): сначала закрывает окно поверх профиля
func handle_back() -> bool:
	while not popups.is_empty():
		var box = popups.pop_back()
		if is_instance_valid(box):
			close_popup(box)
			return true
	_on_back_pressed()
	return true
