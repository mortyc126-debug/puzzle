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
const PATH_THEMES = "CustomizeContainer/🌌 Themes/ThemesBox/ThemesList"
const PATH_THEMES_BOX = "CustomizeContainer/🌌 Themes/ThemesBox"
const PATH_EFFECTS = "CustomizeContainer/✨ Effects/EffectsList"
const PATH_REWARDS = "CustomizeContainer/🎁 Rewards/RewardsList"
const PATH_AVATARS = "CustomizeContainer/👤 Avatars/AvatarsList"
const PATH_FRAMES = "CustomizeContainer/🖼️ Frames/FramesList"
const PATH_ACHIEVEMENTS = "CustomizeContainer/🏆 Achievements/AchievementsContent"

const GOLD = Color(1, 0.84, 0)

var progression = null
var all_colors = ItemsDB.block_colors
var best_value_label: Label
var title_button: Button   # титул под именем: нажатие — окно «Титул и оформление имени»
var coins_value_label: Label
var built_tabs = {}  # Вкладки строятся при первом открытии — профиль открывается быстрее
var popups: Array = []  # Открытые окна поверх профиля (закрываются кнопкой «Назад» по очереди)

func _ready():
	progression = Progression

	$BackButton.pressed.connect(_on_back_pressed)
	style_header()
	build_section_nav()
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

# Шапка — карточка игрока: слева аватарка в рамке, справа имя с карандашом, титул, уровень
# с полосой опыта и плашки «рекорд» и «достижения»; монеты — справа вверху, как на экране игры.
# Раньше всё стояло столбиком по центру впритык: имя, титул и плашки налезали друг на друга.
const CARD_RECT = Rect2(24, 108, 852, 300)
const INFO_X = 292.0   # левый край правой колонки карточки
const INFO_W = 560.0
const NAME_MAX_WIDTH = 480.0

var header_level_label: Label
var header_xp_label: Label
var header_xp_bar: ProgressBar
var achievements_value_label: Label

func style_header():
	ScreenStyle.apply_background(get_node_or_null("Background"))
	ScreenStyle.style_back_button($BackButton)
	$BackButton.position = Vector2(24, 30)

	var card = PanelContainer.new()
	card.name = "PlayerCard"
	card.theme_type_variation = &"HudPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = CARD_RECT.position
	card.size = CARD_RECT.size
	add_child(card)
	var background = get_node_or_null("Background")
	move_child(card, background.get_index() + 1 if background else 0)

	var avatar = get_node_or_null("AvatarDisplay")
	if avatar:
		avatar.position = Vector2(56, 163)
		avatar.size = Vector2(190, 190)
	var frame = get_node_or_null("FrameDisplay")
	if frame:
		frame.position = Vector2(41, 148)
		frame.size = Vector2(220, 220)

	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.theme_type_variation = &"DisplayLabel"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.position = Vector2(INFO_X, 126)
		name_label.size = Vector2(NAME_MAX_WIDTH + 10, 60)

	var edit_name_btn = get_node_or_null("EditNameButton")
	if edit_name_btn:
		edit_name_btn.theme_type_variation = &"IconButton"
		edit_name_btn.icon = load("res://assets/ui/icons/edit.svg")
		edit_name_btn.expand_icon = true
		edit_name_btn.add_theme_constant_override("icon_max_width", 26)
		edit_name_btn.size = Vector2(52, 52)
		edit_name_btn.position = Vector2(INFO_X + NAME_MAX_WIDTH, 130)

	title_button = Button.new()
	title_button.theme_type_variation = &"IconButton"
	title_button.icon = icon_texture("star")
	title_button.add_theme_constant_override("icon_max_width", 24)
	title_button.add_theme_font_size_override("font_size", 22)
	title_button.position = Vector2(INFO_X, 192)
	title_button.pressed.connect(show_title_popup)
	add_child(title_button)

	# Уровень и опыт: «Уровень 47 · Инженер» слева, «230 / 580 опыта» справа, под ними полоса
	header_level_label = make_label("", 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT, false)
	header_level_label.theme_type_variation = &"DisplayLabel"
	header_level_label.position = Vector2(INFO_X, 246)
	header_level_label.size = Vector2(INFO_W * 0.6, 36)
	add_child(header_level_label)
	header_xp_label = make_label("", 20, Color(0.8, 0.84, 0.98), HORIZONTAL_ALIGNMENT_RIGHT, false)
	header_xp_label.position = Vector2(INFO_X + INFO_W * 0.6, 248)
	header_xp_label.size = Vector2(INFO_W * 0.4, 34)
	add_child(header_xp_label)
	header_xp_bar = ProgressBar.new()
	header_xp_bar.show_percentage = false
	header_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_xp_bar.position = Vector2(INFO_X, 286)
	header_xp_bar.size = Vector2(INFO_W, 14)
	add_child(header_xp_bar)

	var row = HBoxContainer.new()
	row.position = Vector2(INFO_X, 318)
	row.size = Vector2(INFO_W, 62)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	best_value_label = add_stat_pill(row, "trophy", GOLD, "рекорд")
	achievements_value_label = add_stat_pill(row, "check", Color(0.55, 0.9, 0.6), "ступеней")

	# Монеты — справа вверху, на одной строке с «Назад»
	var top_row = HBoxContainer.new()
	top_row.position = Vector2(476, 30)
	top_row.size = Vector2(400, 64)
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_row)
	coins_value_label = add_stat_pill(top_row, "coin", Color.WHITE)

# Плашка «значок + число [+ подпись]». Возвращает надпись с числом
func add_stat_pill(parent: Control, icon_name: String, tint: Color, caption: String = "") -> Label:
	var pill = PanelContainer.new()
	pill.theme_type_variation = &"Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	if caption != "":
		var caption_label = Label.new()
		caption_label.text = caption
		caption_label.add_theme_font_size_override("font_size", 20)
		caption_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.95))
		line.add_child(caption_label)
	pill.add_child(line)
	parent.add_child(pill)
	return label

func update_profile():
	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.text = progression.player_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var font_size = adjust_text_size(name_label, NAME_MAX_WIDTH)
		NameStyle.apply(name_label)
		# Карандаш — сразу за именем
		var edit_name_btn = get_node_or_null("EditNameButton")
		if edit_name_btn:
			var font = name_label.get_theme_font("font")
			var width = minf(font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, NAME_MAX_WIDTH)
			edit_name_btn.position.x = name_label.position.x + width + 12

	if title_button:
		var title = NameStyle.title_text()
		title_button.text = title if title != "" else "Выбрать титул"
		title_button.add_theme_color_override("font_color", Color(1, 0.78, 0.4) if title != "" else Color(0.75, 0.78, 0.95))
		title_button.size = Vector2.ZERO

	if header_level_label:
		header_level_label.text = "Уровень %d · %s" % [progression.current_level, progression.get_rank()]
		if progression.is_max_level():
			header_xp_bar.max_value = 1
			header_xp_bar.value = 1
			header_xp_label.text = "максимум"
		else:
			header_xp_bar.max_value = progression.get_xp_for_next_level()
			header_xp_bar.value = progression.current_xp
			header_xp_label.text = "%d / %d опыта" % [progression.current_xp, progression.get_xp_for_next_level()]
	if achievements_value_label:
		var total = Achievements.get_total_progress()
		achievements_value_label.text = "%d/%d" % [total["unlocked"], total["total"]]

	var avatar_display = get_node_or_null("AvatarDisplay")
	if avatar_display:
		avatar_display.texture = ItemsDB.get_avatar_texture(progression.player_avatar)
		ItemsDB.style_item_rect(avatar_display, "avatar", progression.player_avatar)

	var frame_display = get_node_or_null("FrameDisplay")
	if frame_display:
		frame_display.texture = ItemsDB.get_frame_texture(progression.player_frame)
		ItemsDB.style_item_rect(frame_display, "frame", progression.player_frame)

	var level_label = get_node_or_null("AvatarLevelLabel")
	if level_label:
		level_label.text = str(progression.current_level)

	if best_value_label:
		best_value_label.text = "%d" % progression.best_score
	if coins_value_label:
		coins_value_label.text = "%d" % progression.total_coins

	update_stats_labels()

# Шрифт имени уменьшается, пока имя не влезет в табличку
func adjust_text_size(label: Label, max_width: float) -> int:
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size = 44
	while font_size > 22:
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x <= max_width:
			break
		font_size -= 2
	label.add_theme_font_size_override("font_size", font_size)
	return font_size

func update_game_profile_button():
	var game = get_node_or_null("/root/Game")
	if game:
		game.refresh_profile_button()
		game.update_profile_name_display()

# === ВКЛАДКИ И ИНДИКАТОРЫ NEW ===

# Разделы профиля — сетка 4×2 кнопок «значок + название» вместо полоски вкладок:
# восемь подписей в одну строку не влезали, и разделы приходилось угадывать по значкам.
# [вкладка, название, иконка, флаг «новое»]
const SECTIONS = [
	[TAB_STATS, "Статистика", "chart", ""],
	[TAB_REWARDS, "Путь наград", "gift", ""],
	[TAB_COLORS, "Кубики", "cube", "skins|paints|colors"],
	[TAB_THEMES, "Темы", "layers", "themes|backdrops"],
	[TAB_EFFECTS, "Эффекты", "sparkle", "effects"],
	[TAB_AVATARS, "Аватарки", "user", "avatars"],
	[TAB_FRAMES, "Рамки", "frame", "frames"],
	[TAB_ACHIEVEMENTS, "Достижения", "trophy", "achievements"],
]
const NAV_TOP = 424.0
const NAV_ROW = 56.0
const NAV_GAP = 8.0

var section_buttons = {}  # вкладка -> [кнопка, точка «новое»]

func build_section_nav():
	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs == null:
		return
	var grid = GridContainer.new()
	grid.name = "SectionNav"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", int(NAV_GAP))
	grid.add_theme_constant_override("v_separation", int(NAV_GAP))
	grid.position = Vector2(tabs.position.x, NAV_TOP)
	grid.size = Vector2(tabs.size.x, NAV_ROW * 2 + NAV_GAP)
	add_child(grid)
	for entry in SECTIONS:
		var button = Button.new()
		button.text = entry[1]
		button.icon = icon_texture(entry[2])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		button.add_theme_constant_override("h_separation", 6)
		button.add_theme_font_size_override("font_size", 21)
		button.custom_minimum_size = Vector2(0, NAV_ROW)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.pressed.connect(func(): tabs.current_tab = entry[0])
		var dot = Panel.new()
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = Color(1, 0.3, 0.3)
		dot_style.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -22.0
		dot.offset_right = -8.0
		dot.offset_top = 7.0
		dot.offset_bottom = 21.0
		button.add_child(dot)
		grid.add_child(button)
		section_buttons[entry[0]] = [button, dot]
	# Полоска вкладок больше не нужна: содержимое начинается сразу под сеткой
	tabs.tabs_visible = false
	var top = NAV_TOP + NAV_ROW * 2 + NAV_GAP + 12.0
	tabs.size.y -= top - tabs.position.y
	tabs.position.y = top
	var panel_style = tabs.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		panel_style = panel_style.duplicate()
		panel_style.corner_radius_top_left = panel_style.corner_radius_top_right
		tabs.add_theme_stylebox_override("panel", panel_style)

func update_tab_titles():
	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs == null:
		return
	var flags = progression.has_new_items
	for entry in SECTIONS:
		if not section_buttons.has(entry[0]):
			continue
		var button: Button = section_buttons[entry[0]][0]
		var selected = entry[0] == tabs.current_tab
		for style in ["normal", "hover", "pressed", "focus"]:
			if selected:
				button.add_theme_stylebox_override(style, make_highlight_box(GOLD, 0.22))
			else:
				button.remove_theme_stylebox_override(style)
		button.add_theme_color_override("font_color", GOLD if selected else Color(0.86, 0.88, 1))
		button.add_theme_color_override("icon_normal_color", GOLD if selected else Color(0.86, 0.88, 1))
		var has_new = false
		for flag in entry[3].split("|", false):
			has_new = has_new or flags.get(flag, false)
		section_buttons[entry[0]][1].visible = has_new

# Открытая вкладка считается просмотренной
func _on_tab_changed(tab: int):
	ensure_tab_built(tab)
	var category = ""
	match tab:
		TAB_THEMES:
			category = "themes"
			progression.mark_items_as_seen("backdrops")
		TAB_EFFECTS:
			category = "effects"
		TAB_COLORS:
			category = "colors"
			progression.mark_items_as_seen("skins")
			progression.mark_items_as_seen("paints")
			create_skins_section()  # превью кубиков — на текущей теме, а её могли сменить
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
		["backdrops", TAB_THEMES],
		["avatars", TAB_AVATARS],
		["frames", TAB_FRAMES],
		["effects", TAB_EFFECTS],
		["skins", TAB_COLORS],
		["paints", TAB_COLORS],
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
	["zen_best", "Рекорд спокойного"], ["zen_games", "Спокойных партий"],
	["challenge_days", "Испытаний пройдено"], ["challenge_streak", "Испытаний подряд"],
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
	# Уровень и опыт — в шапке профиля; здесь то, чего там нет: следующая награда и коллекция
	level_card["next"] = make_label("", 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(level_card["next"])
	level_card["collection"] = make_label("", 22, Color(0.8, 0.84, 0.98), HORIZONTAL_ALIGNMENT_LEFT, false)
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
		var caption = make_label(entry[1], 21, Color(0.7, 0.74, 0.92), HORIZONTAL_ALIGNMENT_LEFT, false)
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
		"zen_best": str(progression.best_zen_score),
		"zen_games": str(progression.zen_games),
		"challenge_days": str(Challenge.total_done),
		"challenge_streak": "%d (лучшая %d)" % [Challenge.current_streak(), Challenge.best_streak],
	}
	for key in values.keys():
		stat_values[key].text = values[key]

	if progression.is_max_level():
		level_card["next"].text = "Максимальный уровень — вы прошли всю игру!"
	else:
		var next = progression.get_next_special_reward()
		level_card["next"].text = "Наград по уровню больше нет — копите на коллекцию" if next.is_empty() else \
			"На уровне %d: %s" % [next["level"], ", ".join(next["lines"])]
	var collection = progression.get_collection_progress()
	level_card["collection"].text = "Коллекция: %d из %d предметов" % [collection["have"], collection["total"]]

# === ЦВЕТА БЛОКОВ (тема «Классика») ===

# === КУБИКИ ===
# Вид блоков поверх любой темы: сверху раздела «Кубики», под ним — цвета (для «Классики»)
func create_skins_section():
	var content = get_node_or_null(PATH_COLORS)
	if content == null:
		return
	var section = content.get_node_or_null("SkinsSection")
	if section == null:
		section = VBoxContainer.new()
		section.name = "SkinsSection"
		section.add_theme_constant_override("separation", 12)
		content.add_child(section)
		content.move_child(section, 0)
		var colors_header = make_label("ЦВЕТА БЛОКОВ", 22, Color(0.64, 0.67, 0.85), HORIZONTAL_ALIGNMENT_LEFT, false)
		colors_header.name = "ColorsHeader"
		content.add_child(colors_header)
		content.move_child(colors_header, 1)
	for child in section.get_children():
		child.queue_free()
	section.add_child(make_label("ВИД КУБИКОВ — поверх любой темы", 22, Color(0.64, 0.67, 0.85), HORIZONTAL_ALIGNMENT_LEFT, false))
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	section.add_child(grid)
	for skin_id in [0] + ItemsDB.get_skin_ids():
		grid.add_child(make_skin_card(skin_id))
	section.add_child(HSeparator.new())
	section.add_child(make_label("ОКРАСКА — цвета блоков поверх темы", 22, Color(0.64, 0.67, 0.85), HORIZONTAL_ALIGNMENT_LEFT, false))
	var paints = GridContainer.new()
	paints.columns = 3
	paints.add_theme_constant_override("h_separation", 12)
	paints.add_theme_constant_override("v_separation", 12)
	section.add_child(paints)
	for paint_id in [0] + ItemsDB.get_paint_ids():
		paints.add_child(make_paint_card(paint_id))
	section.add_child(HSeparator.new())

func make_skin_card(skin_id: int) -> Control:
	var data = ItemsDB.get_skin_data(skin_id)
	var unlocked = skin_id == 0 or progression.is_unlocked("skin", skin_id)
	var selected = skin_id == progression.player_skin
	var card = Button.new()
	card.custom_minimum_size = Vector2(262, 262)
	if selected:
		card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))
	card.pressed.connect(_on_skin_clicked.bind(skin_id))
	var preview = ThemePreview.new()
	preview.position = Vector2(16, 12)
	preview.size = Vector2(230, 160)
	preview.paint = ThemeManager.paint_id
	preview.set_theme_resource(ThemeManager.with_skin(ThemeManager.current, skin_id), not unlocked)
	card.add_child(preview)
	var name_text = data.get("name", "Как в теме") if skin_id > 0 else "Как в теме"
	var rarity = data.get("rarity", "COMMON")
	var title = make_label(name_text, 24, ItemsDB.get_rarity_color(rarity) if skin_id > 0 else Color.WHITE)
	title.position = Vector2(8, 176)
	title.size = Vector2(246, 34)
	card.add_child(title)
	var status = "Выбрано" if selected else ("Нажмите, чтобы выбрать" if unlocked else "")
	if not unlocked:
		var price = progression.get_price("skin", skin_id)
		status = "%d монет или ур. %d" % [price, int(data.get("unlock", {}).get("level", 0))] if price > 0 \
			else ItemsDB.get_unlock_text(data.get("unlock", {}))
	var status_label = make_label(status, 20, GOLD if selected or (not unlocked and progression.get_price("skin", skin_id) > 0)
		else Color(0.8, 0.82, 0.95))
	status_label.position = Vector2(8, 210)
	status_label.size = Vector2(246, 48)
	card.add_child(status_label)
	return card

func make_paint_card(paint_id: int) -> Control:
	var data = ItemsDB.get_paint_data(paint_id)
	var unlocked = paint_id == 0 or progression.is_unlocked("paint", paint_id)
	var selected = paint_id == progression.player_paint
	var card = Button.new()
	card.custom_minimum_size = Vector2(262, 262)
	if selected:
		card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))
	card.pressed.connect(_on_paint_clicked.bind(paint_id))
	var preview = ThemePreview.new()
	preview.position = Vector2(16, 12)
	preview.size = Vector2(230, 160)
	preview.paint = paint_id if paint_id > 0 else -1
	preview.set_theme_resource(ThemeManager.with_skin(ThemeManager.current, progression.player_skin), not unlocked)
	card.add_child(preview)
	var rarity = data.get("rarity", "COMMON")
	var title = make_label(data.get("name", "") if paint_id > 0 else "Цвета темы", 24,
		ItemsDB.get_rarity_color(rarity) if paint_id > 0 else Color.WHITE)
	title.position = Vector2(8, 176)
	title.size = Vector2(246, 34)
	card.add_child(title)
	var price = progression.get_price("paint", paint_id) if paint_id > 0 else 0
	var status = "Выбрано" if selected else ("Нажмите, чтобы выбрать" if unlocked else "")
	if not unlocked:
		status = "%d монет или ур. %d" % [price, int(data.get("unlock", {}).get("level", 0))] if price > 0 \
			else ItemsDB.get_unlock_text(data.get("unlock", {}))
	var status_label = make_label(status, 20, GOLD if selected or (not unlocked and price > 0) else Color(0.8, 0.82, 0.95))
	status_label.position = Vector2(8, 210)
	status_label.size = Vector2(246, 48)
	card.add_child(status_label)
	return card

func _on_paint_clicked(paint_id: int):
	if paint_id != 0 and not progression.is_unlocked("paint", paint_id):
		show_locked_card("paint", paint_id)
		return
	progression.select_paint(paint_id)
	create_skins_section()
	create_colors_list()

func _on_skin_clicked(skin_id: int):
	if skin_id != 0 and not progression.is_unlocked("skin", skin_id):
		show_locked_card("skin", skin_id)
		return
	progression.select_skin(skin_id)
	create_skins_section()

func create_colors_list():
	var content = get_node_or_null(PATH_COLORS)
	if content == null:
		return
	if content.get_node_or_null("SkinsSection") == null:
		create_skins_section()
	var slots_label = content.get_node_or_null("SlotsLabel")
	var active_container = content.get_node_or_null("ActiveSlots")
	var all_colors_container = content.get_node_or_null("AllColors")
	if slots_label == null or active_container == null or all_colors_container == null:
		return

	var active_count = progression.active_colors.size()
	var max_slots = progression.max_color_slots
	slots_label.text = "Слоты: %d/%d" % [active_count, max_slots]
	if progression.player_paint > 0:
		slots_label.text += "  (сейчас выбрана окраска — цвета не действуют)"
	elif not ThemeManager.current.use_player_colors:
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
			var buy_btn = Button.new()
			buy_btn.flat = true
			buy_btn.size = Vector2(80, 80)
			buy_btn.pressed.connect(show_locked_card.bind("color", i))
			color_container.add_child(buy_btn)
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
	create_backdrops_section()

# Фоны — отдельная коллекция под темами: живой фон поверх любой темы
func create_backdrops_section():
	var box = get_node_or_null(PATH_THEMES_BOX)
	if box == null:
		return
	var section = box.get_node_or_null("BackdropsSection")
	if section == null:
		section = VBoxContainer.new()
		section.name = "BackdropsSection"
		section.add_theme_constant_override("separation", 12)
		box.add_child(section)
	for child in section.get_children():
		child.queue_free()
	section.add_child(HSeparator.new())
	section.add_child(make_label("ФОНЫ — живой фон поверх любой темы", 22, Color(0.64, 0.67, 0.85), HORIZONTAL_ALIGNMENT_LEFT, false))
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	section.add_child(grid)
	for backdrop_id in [0] + ItemsDB.get_backdrop_ids():
		grid.add_child(make_backdrop_card(backdrop_id))

func make_backdrop_card(backdrop_id: int) -> Control:
	var data = ItemsDB.get_backdrop_data(backdrop_id)
	var unlocked = backdrop_id == 0 or progression.is_unlocked("backdrop", backdrop_id)
	var selected = backdrop_id == progression.player_backdrop
	var card = Button.new()
	card.custom_minimum_size = Vector2(262, 322)
	if selected:
		card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))
	card.pressed.connect(_on_backdrop_clicked.bind(backdrop_id))
	var preview = BackdropPreview.new()
	preview.position = Vector2(16, 12)
	preview.size = Vector2(230, 220)
	card.add_child(preview)
	preview.setup(backdrop_id, not unlocked)
	var rarity = data.get("rarity", "COMMON")
	var title = make_label(data.get("name", "") if backdrop_id > 0 else "Как в теме", 24,
		ItemsDB.get_rarity_color(rarity) if backdrop_id > 0 else Color.WHITE)
	title.position = Vector2(8, 236)
	title.size = Vector2(246, 34)
	card.add_child(title)
	var price = progression.get_price("backdrop", backdrop_id) if backdrop_id > 0 else 0
	var status = "Выбран" if selected else ("Нажмите, чтобы выбрать" if unlocked else "")
	if not unlocked:
		status = "%d монет или ур. %d" % [price, int(data.get("unlock", {}).get("level", 0))] if price > 0 \
			else ItemsDB.get_unlock_text(data.get("unlock", {}))
	var status_label = make_label(status, 20, GOLD if selected or (not unlocked and price > 0) else Color(0.8, 0.82, 0.95))
	status_label.position = Vector2(8, 270)
	status_label.size = Vector2(246, 48)
	card.add_child(status_label)
	return card

func _on_backdrop_clicked(backdrop_id: int):
	if backdrop_id != 0 and not progression.is_unlocked("backdrop", backdrop_id):
		show_locked_card("backdrop", backdrop_id)
		return
	progression.select_backdrop(backdrop_id)
	create_backdrops_section()

func _on_theme_clicked(theme_id: String):
	var block_theme = ThemeManager.get_theme_by_id(theme_id)
	if block_theme == null:
		return
	if not progression.is_unlocked("theme", theme_id):
		show_locked_card("theme", theme_id)
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
		card.custom_minimum_size = Vector2(262, 286)
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
		var status_label = make_label(status, 20, GOLD if selected else Color(0.8, 0.82, 0.95))
		status_label.position = Vector2(8, 204)
		status_label.size = Vector2(246, 76)
		card.add_child(status_label)

		container.add_child(card)

func _on_effect_clicked(effect_id: int):
	var data = ItemsDB.get_effect_data(effect_id)
	if not progression.is_unlocked("effect", effect_id):
		show_locked_card("effect", effect_id)
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
		card.custom_minimum_size = Vector2(156, 200)
		card.pressed.connect(show_item_card.bind(item_type, item_id))
		if item_id == selected_id:
			card.add_theme_stylebox_override("normal", make_highlight_box(GOLD))

		# Рамка показывается на аватарке игрока — сразу видно, как она будет выглядеть
		if item_type == "frame":
			var avatar = TextureRect.new()
			avatar.texture = ItemsDB.get_avatar_texture(progression.player_avatar)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar.position = Vector2(22, 21)
			avatar.size = Vector2(112, 112)
			avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not unlocked:
				avatar.modulate = Color(0.45, 0.45, 0.5)
			card.add_child(avatar)
		var picture = TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(13, 12)
		picture.size = Vector2(130, 130)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			picture.modulate = Color(0.55, 0.55, 0.6) if item_type == "frame" else Color(0.25, 0.25, 0.3)
		else:
			ItemsDB.style_item_rect(picture, item_type, item_id)
		card.add_child(picture)
		var tier = progression.get_item_tier(item_type, item_id) if unlocked else 0
		if tier > 0:
			# Значок ступени: серебряная звезда — сияющая, золотая — золотая
			var badge = TextureRect.new()
			badge.texture = icon_texture("star")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.position = Vector2(120, 6)
			badge.size = Vector2(30, 30)
			badge.modulate = GOLD if tier >= 2 else Color(0.85, 0.92, 1)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(badge)

		# Закрытый предмет, который можно купить, показывает цену — это цель, а не тупик
		var price = progression.get_price(item_type, item_id)
		var caption_text = data.get("name", "?") if unlocked else ("%d монет" % price if price > 0 else "Закрыто")
		var caption = make_label(caption_text, 21,
			GOLD if (not unlocked and price > 0) else ItemsDB.get_rarity_color(data.get("rarity", "COMMON")))
		caption.position = Vector2(4, 144)
		caption.size = Vector2(148, 52)
		card.add_child(caption)
		fit_caption(caption, 21, 20)

		container.add_child(card)

func show_item_card(item_type: String, item_id: int):
	var data = ItemsDB.get_avatar_data(item_id) if item_type == "avatar" else ItemsDB.get_frame_data(item_id)
	if data.is_empty():
		return
	var unlocked = progression.is_unlocked(item_type, item_id)
	var box = open_popup(580)

	var preview_holder = CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(540, 230)
	if item_type == "frame":
		# Рамка — на аватарке игрока
		var stack = Control.new()
		stack.custom_minimum_size = Vector2(220, 220)
		var avatar = TextureRect.new()
		avatar.texture = ItemsDB.get_avatar_texture(progression.player_avatar)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.position = Vector2(15, 15)
		avatar.size = Vector2(190, 190)
		ItemsDB.style_item_rect(avatar, "avatar", progression.player_avatar)
		stack.add_child(avatar)
		preview_holder.add_child(stack)
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(220, 220)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = ItemsDB.get_avatar_texture(item_id) if item_type == "avatar" else ItemsDB.get_frame_texture(item_id)
	if not unlocked and item_type != "frame":
		preview.modulate = Color(0.35, 0.35, 0.4)
	if unlocked:
		ItemsDB.style_item_rect(preview, item_type, item_id)
	if item_type == "frame":
		preview.size = Vector2(220, 220)
		preview_holder.get_child(0).add_child(preview)
	else:
		preview_holder.add_child(preview)
	box.add_child(preview_holder)

	var rarity = data.get("rarity", "COMMON")
	box.add_child(make_label(data.get("name", "?"), 36, Color.WHITE))
	box.add_child(make_label(ItemsDB.get_rarity_name(rarity), 22, ItemsDB.get_rarity_color(rarity)))
	box.add_child(HSeparator.new())
	box.add_child(make_label(data.get("description", ""), 22, Color(0.88, 0.9, 1)))
	if not unlocked:
		box.add_child(make_label(ItemsDB.get_unlock_text(data.get("unlock", {})), 22, GOLD))

	if not unlocked:
		add_buy_row(box, item_type, item_id)
		return

	add_upgrade_row(box, item_type, item_id)

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

# Улучшение открытой аватарки или рамки: маленькое превью «как будет», цена и кнопка
func add_upgrade_row(box: Control, item_type: String, item_id: int):
	var tier = progression.get_item_tier(item_type, item_id)
	box.add_child(HSeparator.new())
	if tier >= 2:
		box.add_child(make_label("Золотая версия — высшая ступень", 24, GOLD))
		return
	var next = tier + 1
	var price = progression.get_upgrade_price(item_type, item_id)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var sample_holder = Control.new()
	sample_holder.custom_minimum_size = Vector2(116, 116)
	row.add_child(sample_holder)
	if item_type == "frame":
		# Рамка — на аватарке игрока, как в сетке
		var under = TextureRect.new()
		under.texture = ItemsDB.get_avatar_texture(progression.player_avatar)
		under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		under.position = Vector2(8, 8)
		under.size = Vector2(100, 100)
		sample_holder.add_child(under)
	var sample = TextureRect.new()
	sample.texture = ItemsDB.get_avatar_texture(item_id) if item_type == "avatar" else ItemsDB.get_frame_texture(item_id)
	sample.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sample.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sample.size = Vector2(116, 116)
	ItemsDB.style_item_rect(sample, item_type, item_id, next)
	sample_holder.add_child(sample)
	var texts = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var what = "по картинке пробегает блик" if next == 1 else "золото и мерцающие искры"
	texts.add_child(make_label("%s версия" % Progression.TIER_NAMES[next], 26, GOLD if next == 2 else Color(0.85, 0.92, 1),
		HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(make_label("Видна везде: %s." % what, 21, Color(0.85, 0.88, 1), HORIZONTAL_ALIGNMENT_LEFT))
	if progression.total_coins < price:
		texts.add_child(make_label("Не хватает %d монет" % (price - progression.total_coins), 21, Color(1, 0.62, 0.3),
			HORIZONTAL_ALIGNMENT_LEFT))
	var button = Button.new()
	button.theme_type_variation = &"GoldButton"
	button.icon = icon_texture("coin")
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))
	button.text = "УЛУЧШИТЬ · %d" % price
	button.custom_minimum_size = Vector2(0, 72)
	button.disabled = progression.total_coins < price
	button.pressed.connect(_on_upgrade.bind(item_type, item_id, box))
	box.add_child(button)

func _on_upgrade(item_type: String, item_id: int, box):
	if not progression.upgrade_item(item_type, item_id):
		return
	Sfx.play("reward")
	close_popup(box)
	if item_type == "avatar":
		create_avatars_list()
	else:
		create_frames_list()
	update_profile()
	update_game_profile_button()
	show_item_card(item_type, item_id)

# === ТИТУЛ И ОФОРМЛЕНИЕ ИМЕНИ ===

func show_title_popup():
	var box = open_popup(640)
	box.add_child(make_label("Титул и имя", 36, GOLD))
	box.add_child(make_label("Титул виден под именем — в профиле и на экране игры.", 21, Color(0.85, 0.88, 1)))

	var name_row = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(name_row)
	var preview = Label.new()
	preview.theme_type_variation = &"DisplayLabel"
	preview.add_theme_font_size_override("font_size", 40)
	preview.text = progression.player_name
	NameStyle.apply(preview)
	name_row.add_child(preview)

	box.add_child(make_label("ЦВЕТ ИМЕНИ", 22, Color(0.64, 0.67, 0.85)))
	var colors = GridContainer.new()
	colors.columns = 3
	colors.add_theme_constant_override("h_separation", 10)
	colors.add_theme_constant_override("v_separation", 10)
	box.add_child(colors)
	for def in Progression.NAME_COLORS:
		var owned = progression.owned_name_colors.has(def["id"])
		var button = Button.new()
		button.custom_minimum_size = Vector2(196, 64)
		button.add_theme_font_size_override("font_size", 21)
		button.text = def["name"] if owned else "%s · %d" % [def["name"], def["price"]]
		button.add_theme_color_override("font_color", def["color"] if not def.get("rainbow", false) else Color(1, 0.8, 0.95))
		if progression.name_color == def["id"]:
			for style in ["normal", "hover", "pressed", "focus"]:
				button.add_theme_stylebox_override(style, make_highlight_box(GOLD, 0.2))
		elif not owned and progression.total_coins < int(def["price"]):
			button.modulate = Color(1, 1, 1, 0.55)
		button.pressed.connect(_on_name_color.bind(def["id"], box))
		colors.add_child(button)

	var glow = Button.new()
	glow.custom_minimum_size = Vector2(0, 64)
	glow.add_theme_font_size_override("font_size", 22)
	if progression.name_glow_owned:
		glow.text = "Свечение имени: %s" % ("включено" if progression.name_glow else "выключено")
	else:
		glow.text = "Свечение имени · %d" % Progression.NAME_GLOW_PRICE
		glow.icon = icon_texture("coin")
		glow.add_theme_constant_override("icon_max_width", 28)
		if progression.total_coins < Progression.NAME_GLOW_PRICE:
			glow.modulate = Color(1, 1, 1, 0.55)
	glow.pressed.connect(_on_name_glow.bind(box))
	box.add_child(glow)

	box.add_child(make_label("ТИТУЛЫ", 22, Color(0.64, 0.67, 0.85)))
	var none = Button.new()
	none.text = "Без титула"
	none.custom_minimum_size = Vector2(0, 60)
	none.add_theme_font_size_override("font_size", 22)
	if progression.player_title == "":
		for style in ["normal", "hover", "pressed", "focus"]:
			none.add_theme_stylebox_override(style, make_highlight_box(GOLD, 0.2))
	none.pressed.connect(_on_title_pick.bind("", box))
	box.add_child(none)
	for def in Progression.TITLES:
		box.add_child(make_title_row(def, box))

	var close_btn = Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.custom_minimum_size = Vector2(0, 72)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close_popup.bind(box))
	box.add_child(close_btn)

# Строка титула: название и состояние (выбран, есть, цена, условие)
func make_title_row(def: Dictionary, box: Control) -> Control:
	var owned = progression.has_title(def["id"])
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 74)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	button.add_child(row)
	var name_label = make_label(def["name"], 24, GOLD if owned else Color(0.85, 0.87, 1), HORIZONTAL_ALIGNMENT_LEFT, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var status = ""
	var status_color = Color(0.7, 0.74, 0.92)
	if progression.player_title == def["id"]:
		status = "Выбран"
		status_color = GOLD
		for style in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(style, make_highlight_box(GOLD, 0.2))
	elif owned:
		status = "Выбрать"
	elif def.has("price"):
		status = "%d монет" % def["price"]
		status_color = GOLD if progression.total_coins >= int(def["price"]) else Color(0.7, 0.72, 0.85)
	else:
		status = title_condition(def)
	var status_label = make_label(status, 21, status_color, HORIZONTAL_ALIGNMENT_RIGHT, false)
	row.add_child(status_label)
	button.pressed.connect(_on_title_pick.bind(def["id"], box))
	return button

func title_condition(def: Dictionary) -> String:
	var value = int(def.get("value", 0))
	var have = progression.get_stat(def.get("stat", ""))
	match def.get("stat", ""):
		"challenge_days":
			return "Испытания: %d / %d" % [mini(have, value), value]
		"max_streak":
			return "Серия ×%d" % value
		"perfect_clears":
			return "Чистых полей: %d / %d" % [mini(have, value), value]
		"best_clean_score":
			return "%d очков без бонусов" % value
		"best_score":
			return "Рекорд %d" % value
		"zen_games":
			return "Спокойных партий: %d / %d" % [mini(have, value), value]
		"games_played":
			return "Партий: %d / %d" % [mini(have, value), value]
	return ""

func _on_title_pick(title_id: String, box):
	if title_id == "" or progression.has_title(title_id):
		progression.set_title(title_id)
	else:
		var def = progression.get_title_def(title_id)
		if not def.has("price"):
			return  # заслуженный титул ещё не получен: строка показывает условие
		if progression.total_coins < int(def["price"]):
			show_info_popup("Не хватает монет", "Титул «%s» стоит %d монет, у вас %d." % [def["name"], def["price"], progression.total_coins])
			return
		if not progression.buy_title(title_id):
			return
		Sfx.play("reward")
	refresh_after_style_change(box)

func _on_name_color(color_id: String, box):
	if progression.owned_name_colors.has(color_id):
		progression.set_name_color(color_id)
	else:
		var def = progression.get_name_color_def(color_id)
		if progression.total_coins < int(def["price"]):
			show_info_popup("Не хватает монет", "Цвет «%s» стоит %d монет, у вас %d." % [def["name"], def["price"], progression.total_coins])
			return
		if not progression.buy_name_color(color_id):
			return
		Sfx.play("reward")
	refresh_after_style_change(box)

func _on_name_glow(box):
	if progression.name_glow_owned:
		progression.set_name_glow(not progression.name_glow)
	else:
		if progression.total_coins < Progression.NAME_GLOW_PRICE:
			show_info_popup("Не хватает монет", "Свечение имени стоит %d монет, у вас %d." % [Progression.NAME_GLOW_PRICE, progression.total_coins])
			return
		if not progression.buy_name_glow():
			return
		Sfx.play("reward")
	refresh_after_style_change(box)

# Окно перестраивается на месте с той же прокруткой — выбор виден сразу
func refresh_after_style_change(box):
	var scroll = box.get_parent() as ScrollContainer
	var offset = scroll.scroll_vertical if scroll else 0
	close_popup(box)
	update_profile()
	update_game_profile_button()
	show_title_popup()
	var fresh = popups[-1] if not popups.is_empty() else null
	if fresh and offset > 0:
		var fresh_scroll = fresh.get_parent() as ScrollContainer
		if fresh_scroll:
			fresh_scroll.set_deferred("scroll_vertical", offset)

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

# === ПОКУПКА ЗА МОНЕТЫ ===

# Карточка закрытой темы, эффекта или цвета: превью, как открыть, кнопка «Купить»
func show_locked_card(item_type: String, item_id):
	var title = ""
	var description = ""
	var rarity = progression.get_item_rarity(item_type, item_id)
	var preview: Control
	match item_type:
		"theme":
			var block_theme = ThemeManager.get_theme_by_id(str(item_id))
			if block_theme == null:
				return
			title = block_theme.display_name
			description = block_theme.description
			var theme_preview = ThemePreview.new()
			theme_preview.set_theme_resource(block_theme, false)
			preview = theme_preview
			preview.custom_minimum_size = Vector2(380, 230)
		"effect":
			var data = ItemsDB.get_effect_data(int(item_id))
			title = data.get("name", "?")
			description = data.get("description", "")
			var effect_preview = EffectPreview.new()
			effect_preview.setup(data.get("kind", "sparks"), ThemeManager.get_block_color(int(item_id)))
			preview = effect_preview
			preview.custom_minimum_size = Vector2(380, 220)
		"backdrop":
			var backdrop_data = ItemsDB.get_backdrop_data(int(item_id))
			title = "Фон «%s»" % backdrop_data.get("name", "?")
			description = backdrop_data.get("description", "") + " Поле и блоки остаются от темы."
			var backdrop_preview = BackdropPreview.new()
			backdrop_preview.custom_minimum_size = Vector2(260, 400)
			backdrop_preview.board_share = 0.5
			backdrop_preview.setup(int(item_id), false)
			preview = backdrop_preview
		"paint":
			var paint_data = ItemsDB.get_paint_data(int(item_id))
			title = "Окраска «%s»" % paint_data.get("name", "?")
			description = paint_data.get("description", "") + " Действует в любой теме."
			var paint_preview = ThemePreview.new()
			paint_preview.paint = int(item_id)
			paint_preview.set_theme_resource(ThemeManager.with_skin(ThemeManager.current, progression.player_skin), false)
			preview = paint_preview
			preview.custom_minimum_size = Vector2(380, 230)
		"skin":
			var skin = ItemsDB.get_skin_data(int(item_id))
			title = "Кубики «%s»" % skin.get("name", "?")
			description = skin.get("description", "") + " Фон и поле остаются от темы."
			var skin_preview = ThemePreview.new()
			skin_preview.set_theme_resource(ThemeManager.with_skin(ThemeManager.current, int(item_id)), false)
			preview = skin_preview
			preview.custom_minimum_size = Vector2(380, 230)
		"color":
			title = "Цвет «%s»" % ItemsDB.color_names[int(item_id)]
			description = "Цвет блоков для темы «Классика». Включается во вкладке «Цвета»."
			var swatch = ColorRect.new()
			swatch.color = all_colors[int(item_id)]
			swatch.custom_minimum_size = Vector2(150, 150)
			preview = swatch
	var box = open_popup(580)
	var holder = CenterContainer.new()
	holder.custom_minimum_size = Vector2(540, preview.custom_minimum_size.y + 10)
	holder.add_child(preview)
	box.add_child(holder)
	box.add_child(make_label(title, 34, Color.WHITE))
	if item_type != "color":
		box.add_child(make_label(ItemsDB.get_rarity_name(rarity), 22, ItemsDB.get_rarity_color(rarity)))
	box.add_child(HSeparator.new())
	box.add_child(make_label(description, 22, Color(0.88, 0.9, 1)))
	box.add_child(make_label(ItemsDB.get_unlock_text(progression.get_item_unlock(item_type, item_id)), 22, GOLD))
	add_buy_row(box, item_type, item_id)

# Цена, сколько монет у игрока и кнопки «Купить» / «Закрыть»
func add_buy_row(box: Control, item_type: String, item_id):
	var price = progression.get_price(item_type, item_id)
	if price > 0:
		var coins = progression.total_coins
		var hint = "Можно купить сразу: %d монет. У вас %d." % [price, coins] if coins >= price \
			else "Или купить за %d монет — не хватает %d." % [price, price - coins]
		box.add_child(make_label(hint, 21, Color(0.85, 0.88, 1)))
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	if price > 0:
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(240, 76)
		buy_btn.add_theme_font_size_override("font_size", 26)
		buy_btn.icon = icon_texture("coin")
		buy_btn.add_theme_constant_override("icon_max_width", 32)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			buy_btn.add_theme_color_override(state, Color.WHITE)
		buy_btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))
		buy_btn.text = "КУПИТЬ · %d" % price
		buy_btn.theme_type_variation = &"GoldButton"
		buy_btn.disabled = progression.total_coins < price
		buy_btn.pressed.connect(_on_buy.bind(item_type, item_id, box))
		row.add_child(buy_btn)
	var close_btn = Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.custom_minimum_size = Vector2(220, 76)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close_popup.bind(box))
	row.add_child(close_btn)

func _on_buy(item_type: String, item_id, box):
	if not progression.buy_item(item_type, item_id):
		return
	close_popup(box)
	var category = {"avatar": "avatars", "frame": "frames", "theme": "themes", "effect": "effects", "color": "colors",
		"skin": "skins", "paint": "paints", "backdrop": "backdrops"}.get(item_type, "")
	progression.mark_items_as_seen(category)
	var rebuild = {"avatar": [TAB_AVATARS, create_avatars_list], "frame": [TAB_FRAMES, create_frames_list],
		"theme": [TAB_THEMES, create_themes_list], "effect": [TAB_EFFECTS, create_effects_list],
		"color": [TAB_COLORS, create_colors_list], "skin": [TAB_COLORS, create_skins_section],
		"paint": [TAB_COLORS, create_skins_section], "backdrop": [TAB_THEMES, create_backdrops_section]}.get(item_type, [])
	if not rebuild.is_empty() and built_tabs.has(rebuild[0]):
		rebuild[1].call()
	if built_tabs.has(TAB_REWARDS):
		create_rewards_list()
	update_profile()
	update_tab_titles()
	update_game_profile_button()

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

# Подпись под картинкой: одна строка, если влезает при шрифте не мельче min_size,
# иначе — две строки (длинные имена вроде «Пиксельный пришелец»)
func fit_caption(label: Label, max_size: int, min_size: int) -> void:
	var font = label.get_theme_font("font")
	var font_size = max_size
	while font_size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

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
