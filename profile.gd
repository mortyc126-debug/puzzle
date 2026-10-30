extends Control

## Профиль игрока: аватарка, рамка, имя, статистика и вкладки кастомизации.
## Вкладки: Статистика, Цвета, Темы, Музыка, Аватарки, Рамки, Достижения.

const TAB_STATS = 0
const TAB_COLORS = 1
const TAB_THEMES = 2
const TAB_MUSIC = 3
const TAB_AVATARS = 4
const TAB_FRAMES = 5
const TAB_ACHIEVEMENTS = 6

const PATH_TABS = "CustomizeContainer"
const PATH_STATS = "CustomizeContainer/📊 Statistics/StatsContent"
const PATH_COLORS = "CustomizeContainer/🎨 Colors/ColorsContent"
const PATH_THEMES = "CustomizeContainer/🌌 Themes/ThemesList"
const PATH_MUSIC = "CustomizeContainer/🎵 Music/MusicList"
const PATH_AVATARS = "CustomizeContainer/👤 Avatars/AvatarsList"
const PATH_FRAMES = "CustomizeContainer/🖼️ Frames/FramesList"
const PATH_ACHIEVEMENTS = "CustomizeContainer/🏆 Achievements/AchievementsContent"

const GOLD = Color(1, 0.84, 0)

var progression = null
var all_colors = ItemsDB.block_colors

func _ready():
	progression = Progression

	$BackButton.pressed.connect(_on_back_pressed)
	var edit_name_btn = get_node_or_null("EditNameButton")
	if edit_name_btn:
		var empty = StyleBoxEmpty.new()
		for style in ["normal", "hover", "pressed", "focus"]:
			edit_name_btn.add_theme_stylebox_override(style, empty)
		edit_name_btn.pressed.connect(show_name_edit_popup)

	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)

	update_profile()
	create_stats_list()
	create_colors_list()
	create_themes_list()
	create_music_list()
	create_avatars_list()
	create_frames_list()
	create_achievements_list()
	update_tab_titles()
	auto_open_new_items_tab()

# === ШАПКА ===

func update_profile():
	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.text = progression.player_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		adjust_text_size(name_label, 180)

	var avatar_display = get_node_or_null("AvatarDisplay")
	if avatar_display:
		avatar_display.texture = ItemsDB.get_avatar_texture(progression.player_avatar)

	var frame_display = get_node_or_null("FrameDisplay")
	if frame_display:
		frame_display.texture = ItemsDB.get_frame_texture(progression.player_frame)

	var level_label = get_node_or_null("AvatarLevelLabel")
	if level_label:
		level_label.text = str(progression.current_level)

	var best_label = get_node_or_null("BestScoreLabel")
	if best_label:
		best_label.text = "🏆 Best: %d" % progression.best_score

	var coins_label = get_node_or_null("CoinsLabel")
	if coins_label:
		coins_label.text = "💰 %d" % progression.total_coins

	update_stats_labels()

# Шрифт имени уменьшается, пока имя не влезет в табличку
func adjust_text_size(label: Label, max_width: float):
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size = 28
	while font_size > 14:
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
	var flags = progression.has_new_items
	var new_mark = func(key): return " NEW!" if flags.get(key, false) else ""
	tabs.set_tab_title(TAB_STATS, "📊 Stats")
	tabs.set_tab_title(TAB_COLORS, "🎨 Colors")
	tabs.set_tab_title(TAB_THEMES, "🌌 Темы" + new_mark.call("themes"))
	tabs.set_tab_title(TAB_MUSIC, "🎵 Music")
	tabs.set_tab_title(TAB_AVATARS, "👤 Avatars" + new_mark.call("avatars"))
	tabs.set_tab_title(TAB_FRAMES, "🖼️ Frames" + new_mark.call("frames"))
	tabs.set_tab_title(TAB_ACHIEVEMENTS, "🏆 Achievements" + new_mark.call("achievements"))

# Открытая вкладка считается просмотренной
func _on_tab_changed(tab: int):
	var category = ""
	match tab:
		TAB_THEMES:
			category = "themes"
		TAB_AVATARS:
			category = "avatars"
		TAB_FRAMES:
			category = "frames"
		TAB_ACHIEVEMENTS:
			category = "achievements"
	if category != "":
		progression.mark_items_as_seen(category)
		update_tab_titles()
		var game = get_node_or_null("/root/Game")
		if game:
			game.update_achievements_indicator()

func auto_open_new_items_tab():
	var tabs: TabContainer = get_node_or_null(PATH_TABS)
	if tabs == null:
		return
	var order = [
		["achievements", TAB_ACHIEVEMENTS],
		["themes", TAB_THEMES],
		["avatars", TAB_AVATARS],
		["frames", TAB_FRAMES],
	]
	for pair in order:
		if progression.has_new_items.get(pair[0], false):
			tabs.current_tab = pair[1]
			_on_tab_changed(pair[1])
			return

# === СТАТИСТИКА ===

func create_stats_list():
	var stats_content = get_node_or_null(PATH_STATS)
	if stats_content == null:
		return
	# Новые строки статистики добавляются кодом к строкам из сцены
	for extra in ["PiecesPlacedLabel", "BestStreakLabel", "PerfectClearsLabel", "ThemeGamesLabel"]:
		if stats_content.get_node_or_null(extra) == null:
			var label = Label.new()
			label.name = extra
			label.add_theme_font_size_override("font_size", 28)
			stats_content.add_child(label)
	update_stats_labels()

func update_stats_labels():
	var stats_content = get_node_or_null(PATH_STATS)
	if stats_content == null:
		return
	var texts = {
		"GamesPlayedLabel": "🎮 Games Played: %d" % progression.total_games_played,
		"LinesClearedLabel": "⭐ Lines Cleared: %d" % progression.total_lines_cleared,
		"TimePlayedLabel": "⏱️ Time Played: %s" % progression.format_play_time(),
		"BestScoreLabel": "🏆 Best Score: %d" % progression.best_score,
		"AverageScoreLabel": "📈 Average Score: %d" % progression.get_average_score(),
		"MaxComboLabel": "💥 Max Lines in One Move: %d" % progression.max_combo_achieved,
		"TotalCoinsLabel": "💰 Total Coins Earned: %d" % progression.total_coins_earned,
		"PiecesPlacedLabel": "🧱 Pieces Placed: %d" % progression.total_pieces_placed,
		"BestStreakLabel": "🔥 Best Streak: ×%d" % progression.max_streak,
		"PerfectClearsLabel": "✨ Perfect Clears: %d" % progression.perfect_clears,
		"ThemeGamesLabel": "🌌 Games in Space: %d" % int(progression.theme_games.get("space", 0)),
	}
	for node_name in texts.keys():
		var label = stats_content.get_node_or_null(node_name)
		if label:
			label.text = texts[node_name]

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
	slots_label.text = "Active Slots: %d/%d" % [active_count, max_slots]
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
			slot.color = all_colors[progression.active_colors[i]]
			var remove_btn = Button.new()
			remove_btn.text = "✖"
			remove_btn.size = Vector2(80, 80)
			remove_btn.flat = true
			remove_btn.add_theme_font_size_override("font_size", 28)
			remove_btn.pressed.connect(_on_remove_color.bind(i))
			slot_container.add_child(remove_btn)
		elif i < max_slots:
			slot.color = Color(0.3, 0.3, 0.3)
			overlay_label.text = "➕"
			slot_container.add_child(overlay_label)
		else:
			slot.color = Color(0.15, 0.15, 0.15)
			overlay_label.text = "🔒"
			slot_container.add_child(overlay_label)

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

		var select_btn = Button.new()
		select_btn.size = Vector2(80, 80)
		select_btn.flat = true
		if i in progression.active_colors:
			select_btn.text = "✓"
			select_btn.add_theme_font_size_override("font_size", 32)
			select_btn.add_theme_color_override("font_color", Color.GREEN)
		select_btn.pressed.connect(_on_select_color.bind(i))
		color_container.add_child(select_btn)

		all_colors_container.add_child(color_container)

func _on_select_color(color_index: int):
	if color_index in progression.active_colors:
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
		var status = "✓ Выбрана" if selected else ("Нажмите, чтобы выбрать" if unlocked else "🔒 " + ItemsDB.get_unlock_text(block_theme.unlock))
		box.add_child(make_label(status, 20, GOLD if selected else Color(0.8, 0.82, 0.95)))

		container.add_child(card)

func _on_theme_clicked(theme_id: String):
	var block_theme = ThemeManager.get_theme_by_id(theme_id)
	if block_theme == null:
		return
	if not progression.is_unlocked("theme", theme_id):
		show_info_popup(block_theme.display_name, block_theme.description + "\n\n🔒 " + ItemsDB.get_unlock_text(block_theme.unlock))
		return
	progression.select_theme(theme_id)
	create_themes_list()
	create_colors_list()

# === МУЗЫКА (заготовка) ===

func create_music_list():
	var container = get_node_or_null(PATH_MUSIC)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	container.add_child(make_label("🎵 Музыкальные треки появятся в следующих обновлениях.", 26, Color(0.8, 0.82, 0.95)))

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

		var caption = make_label(data.get("name", "?") if unlocked else "🔒", 18,
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
	box.add_child(make_label(rarity + " " + ItemsDB.get_rarity_stars(rarity), 22, ItemsDB.get_rarity_color(rarity)))
	box.add_child(HSeparator.new())
	box.add_child(make_label(data.get("description", ""), 22, Color(0.88, 0.9, 1)))
	if not unlocked:
		box.add_child(make_label("🔒 " + ItemsDB.get_unlock_text(data.get("unlock", {})), 22, GOLD))

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
		select_btn.text = "SELECTED ✓"
		select_btn.disabled = true
	elif not unlocked:
		select_btn.text = "🔒 LOCKED"
		select_btn.disabled = true
	else:
		select_btn.text = "SELECT"
		select_btn.pressed.connect(_on_select_item.bind(item_type, item_id, box))
	row.add_child(select_btn)

	var close_btn = Button.new()
	close_btn.text = "CLOSE"
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
		progress_label.text = "Progress: %d / %d (%.0f%%)" % [total["unlocked"], total["total"], total["percent"]]
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

	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(20, 12)
	box.size = Vector2(750, 108)
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var title = "%s %s" % [def["icon"], def["title"]]
	if tier > 0:
		title += " — " + Achievements.get_tier_label(def, tier)
	box.add_child(make_label(title, 28, Achievements.get_tier_color(tier) if tier > 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))

	if info["completed"]:
		box.add_child(make_label("✅ " + Achievements.get_description(def, info["max_tier"]), 20, Color(0.6, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var next_text = "%s  (%s / %s)" % [Achievements.get_description(def, tier + 1),
			Achievements.format_value(def, info["value"]), Achievements.format_value(def, info["next_target"])]
		box.add_child(make_label(next_text, 20, Color(0.82, 0.85, 0.98), HORIZONTAL_ALIGNMENT_LEFT))

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(740, 16)
	bar.show_percentage = false
	bar.value = info["percent"]
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	return card

func show_achievement_popup(def: Dictionary):
	var info = Achievements.get_info(def)
	var box = open_popup(640)
	box.add_child(make_label("%s %s" % [def["icon"], def["title"]], 38, GOLD))
	box.add_child(make_label("Текущее значение: %s" % Achievements.format_value(def, info["value"]), 22, Color(0.85, 0.88, 1)))

	var tiers: Array = def["tiers"]
	for tier in range(1, tiers.size() + 1):
		var done = info["tier"] >= tier
		var panel = PanelContainer.new()
		if done:
			panel.add_theme_stylebox_override("panel", make_highlight_box(Achievements.get_tier_color(tier), 0.3))
		var tier_box = VBoxContainer.new()
		panel.add_child(tier_box)

		var header = ("✅ " if done else "🔒 ") + Achievements.get_tier_label(def, tier)
		tier_box.add_child(make_label(header, 24, Achievements.get_tier_color(tier), HORIZONTAL_ALIGNMENT_LEFT))
		tier_box.add_child(make_label(Achievements.get_description(def, tier), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))

		var rewards = ["💰 %d" % Achievements.get_reward_coins(def, tier)]
		for item in progression.find_items("achievement", [def["id"], tier]):
			rewards.append(progression.get_item_label(item["type"], item["id"]))
		tier_box.add_child(make_label("Награда: " + ", ".join(rewards), 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		box.add_child(panel)

	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(260, 70)
	close_btn.pressed.connect(close_popup.bind(box))
	box.add_child(close_btn)

# === ИМЯ ===

func show_name_edit_popup():
	var box = open_popup(520)
	box.add_child(make_label("Change Your Name", 34, GOLD))

	var line_edit = LineEdit.new()
	line_edit.text = progression.player_name
	line_edit.max_length = 10
	line_edit.placeholder_text = "Enter name..."
	line_edit.custom_minimum_size = Vector2(460, 64)
	line_edit.add_theme_font_size_override("font_size", 28)
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line_edit)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(200, 64)
	cancel_btn.pressed.connect(close_popup.bind(box))
	row.add_child(cancel_btn)

	var save_btn = Button.new()
	save_btn.text = "SAVE"
	save_btn.custom_minimum_size = Vector2(200, 64)
	save_btn.pressed.connect(_on_name_save.bind(line_edit, box))
	row.add_child(save_btn)

	line_edit.grab_focus()

func _on_name_save(line_edit: LineEdit, box):
	var new_name = line_edit.text.strip_edges()
	if new_name == "":
		new_name = "Player"
	progression.player_name = new_name
	progression.request_save()
	update_profile()
	update_game_profile_button()
	close_popup(box)

# === ВСПОМОГАТЕЛЬНОЕ ===

func make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
func open_popup(min_width: float) -> VBoxContainer:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

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
	return box

func close_popup(box: Control):
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
