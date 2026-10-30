extends Control

var progression = null

# Все доступные цвета
var all_colors = ItemsDB.block_colors

func _ready():
	progression = get_node("/root/Game/Progression")
	
	var back_btn = get_node_or_null("BackButton")
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	
	# ПРОВЕРЬ ЭТО:
	var edit_name_btn = get_node_or_null("EditNameButton")
	if edit_name_btn:
		print("✅ EditNameButton найдена, подключаем сигнал")
		edit_name_btn.pressed.connect(_on_edit_name_pressed)
	else:
		print("❌ EditNameButton НЕ НАЙДЕНА!")
	
	await get_tree().process_frame
	
# === ЗАДАЁМ НАЗВАНИЯ ВКЛАДКАМ ===
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
		tab_container.set_tab_title(0, "📊 Statistics")
		tab_container.set_tab_title(1, "🎨 Colors")
		tab_container.set_tab_title(2, "🌌 Backgrounds")
		tab_container.set_tab_title(3, "🎵 Music")
		tab_container.set_tab_title(4, "👤 Avatars")
		tab_container.set_tab_title(5, "🖼️ Frames")
		tab_container.set_tab_title(6, "🏆 Achievements")
		
		# Делаем кнопку прозрачной
		var stylebox = StyleBoxEmpty.new()
		edit_name_btn.add_theme_stylebox_override("normal", stylebox)
		edit_name_btn.add_theme_stylebox_override("hover", stylebox)
		edit_name_btn.add_theme_stylebox_override("pressed", stylebox)
		
		edit_name_btn.pressed.connect(_on_edit_name_pressed)
		
	# Создаём контент
	create_avatars_list()
	create_frames_list()
	create_colors_list()
	create_backgrounds_list()
	create_music_list()
	create_stats_list()
	create_achievements_list()
	
	update_profile()
	
		# Автоматически открываем вкладку с новыми предметами
	auto_open_new_items_tab()

# Обновляет названия вкладок с индикаторами NEW
func update_tab_titles(tab_container):
	var new_achievements = progression.has_new_items.get("achievements", false)
	var new_avatars = progression.has_new_items.get("avatars", false)
	var new_frames = progression.has_new_items.get("frames", false)
	var new_backgrounds = progression.has_new_items.get("backgrounds", false)
	var new_music = progression.has_new_items.get("music", false)
	
	tab_container.set_tab_title(0, "📊 Stats")
	tab_container.set_tab_title(1, "🎨 Colors" + (" NEW!" if new_avatars else ""))
	tab_container.set_tab_title(2, "🌌 Backgrounds" + (" NEW!" if new_backgrounds else ""))
	tab_container.set_tab_title(3, "🎵 Music" + (" NEW!" if new_music else ""))
	tab_container.set_tab_title(4, "👤 Avatars" + (" NEW!" if new_avatars else ""))
	tab_container.set_tab_title(5, "🖼️ Frames" + (" NEW!" if new_frames else ""))
	tab_container.set_tab_title(6, "🏆 Achievements" + (" NEW!" if new_achievements else ""))
	
# === ОБНОВЛЕНИЕ ПРОФИЛЯ ===

func update_profile():
	if progression == null:
		return
	
	# Имя
	var name_label = get_node_or_null("PlayerNameLabel")
	if name_label:
		name_label.text = progression.player_name  # Берём из progression
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# АВТОМАТИЧЕСКОЕ УМЕНЬШЕНИЕ ТЕКСТА
		adjust_text_size(name_label, 180)  # 180px — ширина табличкы
	
	# Аватарка
	var avatar_display = get_node_or_null("AvatarDisplay")
	if avatar_display:
		var avatar_path = "res://assets/avatars/avatar_%d.png" % progression.player_avatar
		if ResourceLoader.exists(avatar_path):
			avatar_display.texture = load(avatar_path)
	
	# Рамка
	var frame_display = get_node_or_null("FrameDisplay")
	if frame_display:
		var frame_path = "res://assets/frames/frame_%d.png" % progression.player_frame
		if ResourceLoader.exists(frame_path):
			frame_display.texture = load(frame_path)
	
	# Уровень
	var level_label = get_node_or_null("AvatarLevelLabel")
	if level_label:
		level_label.text = str(progression.current_level)
	
	# Best Score
	var best_label = get_node_or_null("BestScoreLabel")
	if best_label:
		var game = get_node("/root/Game")
		best_label.text = "🏆 Best: %d" % game.best_score
	
	# Coins
	var coins_label = get_node_or_null("CoinsLabel")
	if coins_label:
		coins_label.text = "💰 %d" % progression.total_coins
	
	# Обновляем статистику
	update_stats_labels()

# === АВАТАРКИ ===

func create_avatars_list():
	# Снимаем индикатор новых аватарок
	progression.mark_items_as_seen("avatars")
	
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
	
	var container = get_node_or_null("CustomizeContainer/👤 Avatars/AvatarsList")
	if container == null:
		print("❌ AvatarsList не найден")
		return
	
	# Очищаем
	for child in container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Создаём кнопки аватарок
	for i in ItemsDB.avatars_data.keys():
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var avatar_path = "res://assets/avatars/avatar_%d.png" % i
		if ResourceLoader.exists(avatar_path):
			btn.texture_normal = load(avatar_path)
		
		# Подсветка выбранной
		if i == progression.player_avatar:
			btn.modulate = Color.YELLOW
		
		# ОДИН КЛИК — показать карточку
		btn.pressed.connect(_on_avatar_clicked.bind(i))
		
		container.add_child(btn)

func _on_avatar_clicked(avatar_id: int):
	# Показываем карточку с кнопкой выбора
	show_item_card("avatar", avatar_id)

# === РАМКИ ===

func create_frames_list():
	# Снимаем индикатор новых рамок
	progression.mark_items_as_seen("frames")
	
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
	
	var container = get_node_or_null("CustomizeContainer/🖼️ Frames/FramesList")
	if container == null:
		print("❌ FramesList не найден")
		return
	
	# Очищаем
	for child in container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Создаём кнопки рамок
	for i in range(1, 2):  # Только 1 рамка (было 19)
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var frame_path = "res://assets/frames/frame_%d.png" % i
		if ResourceLoader.exists(frame_path):
			btn.texture_normal = load(frame_path)
		
		# Подсветка выбранной
		if i == progression.player_frame:
			btn.modulate = Color.YELLOW
		
		# ОДИН КЛИК — показать карточку
		btn.pressed.connect(_on_frame_clicked.bind(i))
		
		container.add_child(btn)

func _on_frame_clicked(frame_id: int):
	# Показываем карточку с кнопкой выбора
	show_item_card("frame", frame_id)

# === ЦВЕТА БЛОКОВ ===

func create_colors_list():
	var slots_label = get_node_or_null("CustomizeContainer/🎨 Colors/ColorsContent/SlotsLabel")
	var active_container = get_node_or_null("CustomizeContainer/🎨 Colors/ColorsContent/ActiveSlots")
	var all_colors_container = get_node_or_null("CustomizeContainer/🎨 Colors/ColorsContent/AllColors")
	
	if slots_label == null or active_container == null or all_colors_container == null:
		print("❌ Контейнеры цветов не найдены")
		return
	
	# Обновляем заголовок
	var active_count = progression.active_colors.size()
	var max_slots = progression.max_color_slots
	slots_label.text = "Active Slots: %d/%d" % [active_count, max_slots]
	
	# === АКТИВНЫЕ СЛОТЫ ===
	for child in active_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	for i in range(8):  # Всегда показываем 8 слотов
		var slot_container = Control.new()
		slot_container.custom_minimum_size = Vector2(80, 80)
		
		var slot = ColorRect.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.position = Vector2(0, 0)
		
		if i < active_count:
			# Слот занят
			var color_index = progression.active_colors[i]
			slot.color = all_colors[color_index]
			
			# Кнопка удаления
			var remove_btn = Button.new()
			remove_btn.text = "✖"
			remove_btn.size = Vector2(80, 80)
			remove_btn.flat = true
			remove_btn.add_theme_font_size_override("font_size", 28)
			remove_btn.add_theme_color_override("font_color", Color.WHITE)
			remove_btn.pressed.connect(_on_remove_color.bind(i))
			slot_container.add_child(slot)
			slot_container.add_child(remove_btn)
		elif i < max_slots:
			# Слот пустой, но доступен
			slot.color = Color(0.3, 0.3, 0.3)
			
			var add_label = Label.new()
			add_label.text = "➕"
			add_label.size = Vector2(80, 80)
			add_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_label.add_theme_font_size_override("font_size", 32)
			slot_container.add_child(slot)
			slot_container.add_child(add_label)
		else:
			# Слот заблокирован
			slot.color = Color(0.15, 0.15, 0.15)
			
			var lock_label = Label.new()
			lock_label.text = "🔒"
			lock_label.size = Vector2(80, 80)
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_label.add_theme_font_size_override("font_size", 32)
			slot_container.add_child(slot)
			slot_container.add_child(lock_label)
		
		active_container.add_child(slot_container)
	
	# === ВСЕ ЦВЕТА ===
	for child in all_colors_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	for i in range(all_colors.size()):
		var color_container = Control.new()
		color_container.custom_minimum_size = Vector2(80, 80)
		
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(80, 80)
		color_rect.color = all_colors[i]
		color_container.add_child(color_rect)
		
		# Проверяем, используется ли
		var is_active = i in progression.active_colors
		
		var select_btn = Button.new()
		select_btn.size = Vector2(80, 80)
		select_btn.flat = true
		
		if is_active:
			select_btn.text = "✓"
			select_btn.add_theme_font_size_override("font_size", 32)
			select_btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			select_btn.text = ""
		
		select_btn.pressed.connect(_on_select_color.bind(i))
		color_container.add_child(select_btn)
		
		all_colors_container.add_child(color_container)

func _on_select_color(color_index: int):
	# Проверяем, не используется ли уже
	if color_index in progression.active_colors:
		print("Цвет уже выбран")
		return
	
	# Проверяем лимит слотов
	if progression.active_colors.size() >= progression.max_color_slots:
		print("Все слоты заняты")
		return
	
	# Добавляем цвет
	progression.active_colors.append(color_index)
	progression.save_progress()
	
	create_colors_list()
	print("✅ Цвет добавлен: ", color_index)

func _on_remove_color(slot_index: int):
	if slot_index < progression.active_colors.size():
		var removed = progression.active_colors[slot_index]
		progression.active_colors.remove_at(slot_index)
		progression.save_progress()
		
		create_colors_list()
		print("❌ Цвет удалён: ", removed)

# === ФОНЫ ===

func create_backgrounds_list():
	# Снимаем индикатор новых фонов
	progression.mark_items_as_seen("backgrounds")
	
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
	
	var container = get_node_or_null("CustomizeContainer/🌌 Backgrounds/BackgroundsList")
	if container == null:
		print("❌ BackgroundsList не найден")
		return
	
	for child in container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	for i in range(1, 11):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 80)
		btn.text = "BG %d" % i
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_background_selected.bind(i))
		container.add_child(btn)

func _on_background_selected(bg_id: int):
	print("Выбран фон: ", bg_id)

# === МУЗЫКА ===

func create_music_list():
	# Снимаем индикатор новой музыки
	progression.mark_items_as_seen("music")
	
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
	
	var container = get_node_or_null("CustomizeContainer/🎵 Music/MusicList")
	if container == null:
		print("❌ MusicList не найден")
		return
	
	for child in container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var tracks = ["Chill", "Epic", "Retro", "Ambient", "Energetic"]
	
	for i in range(tracks.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(700, 60)
		btn.text = "🎵 " + tracks[i]
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_music_selected.bind(i))
		container.add_child(btn)

func _on_music_selected(music_id: int):
	print("Выбрана музыка: ", music_id)

# === ОБНОВЛЕНИЕ ИГРЫ ===

func update_game_profile_button():
	var game = get_node("/root/Game")
	var profile_btn = game.get_node_or_null("ProfileButton")
	
	if profile_btn == null:
		return
	
	profile_btn.ignore_texture_size = true
	profile_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Аватарка
	var avatar_path = "res://assets/avatars/avatar_%d.png" % progression.player_avatar
	if ResourceLoader.exists(avatar_path):
		profile_btn.texture_normal = load(avatar_path)
	
	# Рамка
	var profile_frame = profile_btn.get_node_or_null("ProfileFrame")
	if profile_frame:
		profile_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		profile_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var frame_path = "res://assets/frames/frame_%d.png" % progression.player_frame
		if ResourceLoader.exists(frame_path):
			profile_frame.texture = load(frame_path)
	
	# Уровень
	var level_label = profile_btn.get_node_or_null("ProfileLevelLabel")
	if level_label:
		level_label.text = str(progression.current_level)
	
	# Имя — вызываем через game
	await get_tree().process_frame
	game.update_profile_name_display()

func _on_back_pressed():
	# Обновляем индикатор в игре перед закрытием
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	queue_free()

# === СТАТИСТИКА ===

func create_stats_list():
	# Проверяем существование контейнера
	var stats_content = get_node_or_null("CustomizeContainer/📊 Statistics/StatsContent")
	if stats_content == null:
		print("❌ StatsContent не найден")
		return
	
	print("✅ Обновляем статистику")
	
	# Обновляем все Label
	update_stats_labels()

func update_stats_labels():
	var stats_content = get_node_or_null("CustomizeContainer/📊 Statistics/StatsContent")
	if stats_content == null:
		return
	
	# Обновляем каждый Label
	var games_label = stats_content.get_node_or_null("GamesPlayedLabel")
	if games_label:
		games_label.text = "🎮 Games Played: %d" % progression.total_games_played
	
	var lines_label = stats_content.get_node_or_null("LinesClearedLabel")
	if lines_label:
		lines_label.text = "⭐ Lines Cleared: %d" % progression.total_lines_cleared
	
	var time_label = stats_content.get_node_or_null("TimePlayedLabel")
	if time_label:
		time_label.text = "⏱️ Time Played: %s" % progression.format_play_time()
	
	var best_label = stats_content.get_node_or_null("BestScoreLabel")
	if best_label:
		var game = get_node("/root/Game")
		best_label.text = "🏆 Best Score: %d" % game.best_score
	
	var avg_label = stats_content.get_node_or_null("AverageScoreLabel")
	if avg_label:
		avg_label.text = "📈 Average Score: %d" % progression.get_average_score()
	
	var combo_label = stats_content.get_node_or_null("MaxComboLabel")
	if combo_label:
		combo_label.text = "🔥 Max Combo: x%d" % progression.max_combo_achieved
	
	var coins_label = stats_content.get_node_or_null("TotalCoinsLabel")
	if coins_label:
		coins_label.text = "💰 Total Coins Earned: %d" % progression.total_coins_earned
	
	print("📊 Статистика обновлена")

# === ДОСТИЖЕНИЯ ===

func create_achievements_list():
	var achievements_content = get_node_or_null("CustomizeContainer/🏆 Achievements/AchievementsContent")
	if achievements_content == null:
		print("❌ AchievementsContent не найден")
		return
	
	print("✅ Создаём список достижений")
	
	# Игрок открыл вкладку достижений — снимаем индикатор
	progression.mark_items_as_seen("achievements")
	
	# Обновляем индикатор в игре
	var game = get_node("/root/Game")
	if game:
		game.update_achievements_indicator()
	
	# Обновляем названия вкладок
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container:
		update_tab_titles(tab_container)
	
	# Обновляем общий прогресс
	update_achievements_progress()
	
	# Создаём категории
	create_achievement_categories()

func update_achievements_progress():
	var progress_label = get_node_or_null("CustomizeContainer/🏆 Achievements/AchievementsContent/ProgressLabel")
	var progress_bar = get_node_or_null("CustomizeContainer/🏆 Achievements/AchievementsContent/TotalProgressBar")
	
	if progress_label == null or progress_bar == null:
		return
	
	var total_progress = progression.get_total_achievements_progress()
	
	progress_label.text = "Progress: %d / %d (%.1f%%)" % [
		total_progress["unlocked"],
		total_progress["total"],
		total_progress["percent"]
	]
	
	progress_bar.value = total_progress["percent"]

func create_achievement_categories():
	var categories_container = get_node_or_null("CustomizeContainer/🏆 Achievements/AchievementsContent/CategoriesContainer")
	
	print("━━━ Ищем CategoriesContainer ━━━")
	print("Путь: CustomizeContainer/🏆 Achievements/AchievementsContent/CategoriesContainer")
	
	if categories_container == null:
		print("❌ CategoriesContainer не найден")
		
		# Проверяем что есть
		var tab = get_node_or_null("CustomizeContainer/🏆 Achievements")
		print("🏆 Achievements существует? ", tab != null)
		
		var content = get_node_or_null("CustomizeContainer/🏆 Achievements/AchievementsContent")
		print("🏆 Achievements существует? ", content != null)
		
		if content:
			print("Дети AchievementsContent:")
			for child in content.get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		
		return
	
	print("✅ CategoriesContainer найден!")
	
	# Очищаем старые элементы
	for child in categories_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Определяем категории
	var categories = [
		{"id": "games", "name": "🎮 GAMES PLAYED", "max": 100},
		{"id": "lines", "name": "⭐ LINES CLEARED", "max": 100},
		{"id": "score", "name": "🏆 HIGH SCORE", "max": 100},
		{"id": "combo", "name": "🔥 MAX COMBO", "max": 8},
		{"id": "coins", "name": "💰 COINS EARNED", "max": 100},
		{"id": "time", "name": "⏱️ TIME PLAYED", "max": 100},
		{"id": "level", "name": "📈 BATTLE PASS LEVEL", "max": 100}
	]
	
	for category in categories:
		create_achievement_category_ui(categories_container, category)

func create_achievement_category_ui(parent: Node, category: Dictionary):
	# Получаем данные прогресса
	var progress_data = progression.get_achievement_progress_data(category["id"])
	
	# Кнопка-карточка для категории
	var category_btn = Button.new()
	category_btn.custom_minimum_size = Vector2(700, 100)
	category_btn.text = ""  # Текст добавим через Label внутри
	
	# Контейнер для содержимого кнопки
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Клики проходят на кнопку
	content.position = Vector2(10, 10)
	content.size = Vector2(680, 80)
	
	# Название категории
	var title = Label.new()
	title.text = category["name"]
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	
	# Прогресс текст
	var progress_text = Label.new()
	if progress_data["completed"]:
		progress_text.text = "✅ COMPLETED: %d / %d" % [progress_data["current_level"], progress_data["max_level"]]
		progress_text.add_theme_color_override("font_color", Color.GREEN)
	else:
		progress_text.text = "Level %d / %d" % [progress_data["current_level"], progress_data["max_level"]]
	progress_text.add_theme_font_size_override("font_size", 20)
	progress_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress_text)
	
	# Прогресс-бар (маленький)
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(660, 20)
	progress_bar.max_value = category["max"]
	progress_bar.value = progress_data["current_level"]
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress_bar)
	
	category_btn.add_child(content)
	
	# Подключаем клик
	category_btn.pressed.connect(_on_achievement_category_clicked.bind(category))
	
	parent.add_child(category_btn)

# Открывает popup с уровнями достижения
func _on_achievement_category_clicked(category: Dictionary):
	print("Открываем категорию: ", category["name"])
	show_achievement_details_popup(category)

func show_achievement_details_popup(category: Dictionary):
	print("━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("Открываем popup для: ", category["name"])
	
	# Проверяем, нет ли уже открытого popup
	var existing_overlay = get_node_or_null("AchievementOverlay")
	if existing_overlay:
		print("⚠️ Удаляем старый overlay")
		existing_overlay.queue_free()
	
	var existing_popup = get_node_or_null("AchievementPopup")
	if existing_popup:
		print("⚠️ Удаляем старый popup")
		existing_popup.queue_free()
	
	# Затемнение
	var overlay = ColorRect.new()
	overlay.name = "AchievementOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	add_child(overlay)
	
	# Контейнер для popup
	var popup_container = PanelContainer.new()
	popup_container.name = "AchievementPopup"
	popup_container.position = Vector2(100, 100)
	popup_container.size = Vector2(700, 760)
	add_child(popup_container)
	
	# Внутренний контейнер
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	popup_container.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = category["name"]
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Общий прогресс
	var progress_data = progression.get_achievement_progress_data(category["id"])
	var progress_label = Label.new()
	progress_label.text = "Progress: %d / %d" % [progress_data["current_level"], category["max"]]
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(progress_label)
	
	# ScrollContainer для уровней
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 550)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	vbox.add_child(scroll)
	
	var levels_container = VBoxContainer.new()
	levels_container.add_theme_constant_override("separation", 10)
	scroll.add_child(levels_container)
	
	# ДОБАВЬ ЭТО:
	# Очищаем контейнер (на всякий случай)
	for child in levels_container.get_children():
		child.queue_free()
	
	var existing_children = levels_container.get_child_count()
	print("Детей в контейнере ДО создания: ", existing_children)
	
	# Создаём карточки для ВСЕХ уровней
	print("Создаём ", category["max"], " карточек...")
	for level in range(1, category["max"] + 1):
		create_achievement_level_card(levels_container, category["id"], level)
	
	var actual_count = levels_container.get_child_count()
	print("✅ Создано карточек: ", actual_count)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	# Кнопка закрытия
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(300, 60)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_on_close_achievement_popup.bind(overlay, popup_container))
	vbox.add_child(close_btn)

func create_achievement_level_card(parent: Node, category_id: String, level: int):
	print("  → Создаём карточку Level ", level, " для ", category_id)
	
	var requirement = progression.get_achievement_requirement(category_id, level)
	var reward = progression.get_achievement_reward(category_id, level)
	var achievement_id = "%s_%d" % [category_id, level]
	var is_claimed = progression.achievements.has(achievement_id)
	
	# Получаем текущее значение статистики
	var current_value = get_current_stat_value(category_id)
	var progress_percent = 0.0
	if requirement > 0:
		progress_percent = min(100.0, (float(current_value) / float(requirement)) * 100.0)
	
	# Карточка уровня
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 120)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	card.add_child(card_vbox)
	
	# Заголовок уровня
	var level_title = Label.new()
	if is_claimed:
		level_title.text = "✅ Level %d — CLAIMED" % level
		level_title.add_theme_color_override("font_color", Color.GREEN)
	elif current_value >= requirement:
		level_title.text = "🎁 Level %d — READY TO CLAIM!" % level
		level_title.add_theme_color_override("font_color", Color.YELLOW)
	else:
		level_title.text = "🔒 Level %d (%d/%d)" % [level, current_value, requirement]
		level_title.add_theme_color_override("font_color", Color.GRAY)
	level_title.add_theme_font_size_override("font_size", 22)
	card_vbox.add_child(level_title)
	
	# Требование
	var req_text = Label.new()
	req_text.text = get_requirement_text(category_id, requirement)
	req_text.add_theme_font_size_override("font_size", 18)
	card_vbox.add_child(req_text)
	
	# Награда
	var reward_text = Label.new()
	reward_text.text = "Reward: %d💰" % reward["coins"]
	if reward.has("items") and reward["items"].size() > 0:
		reward_text.text += " + Unique Item"
	reward_text.add_theme_font_size_override("font_size", 18)
	reward_text.add_theme_color_override("font_color", Color(1, 0.84, 0))
	card_vbox.add_child(reward_text)
	
	# Прогресс-бар (если не получено)
	if not is_claimed:
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(620, 20)
		progress_bar.max_value = 100
		progress_bar.value = progress_percent
		progress_bar.show_percentage = false
		card_vbox.add_child(progress_bar)
	
	parent.add_child(card)

func get_current_stat_value(category_id: String) -> int:
	match category_id:
		"games":
			return progression.total_games_played
		"lines":
			return progression.total_lines_cleared
		"score":
			var game = get_node_or_null("/root/Game")
			return game.best_score if game else 0
		"combo":
			return progression.max_combo_achieved
		"coins":
			return progression.total_coins_earned
		"time":
			return progression.total_time_played
		"level":
			return progression.current_level
	return 0

func get_requirement_text(category_id: String, requirement: int) -> String:
	match category_id:
		"games":
			return "Play %d games" % requirement
		"lines":
			return "Clear %d lines" % requirement
		"score":
			return "Score %d points" % requirement
		"combo":
			return "Achieve x%d combo" % requirement
		"coins":
			return "Earn %d coins" % requirement
		"time":
			var hours = requirement / 3600
			var minutes = (requirement % 3600) / 60
			return "Play %dh %dm" % [hours, minutes]
		"level":
			return "Reach level %d" % requirement
	return ""

func _on_close_achievement_popup(overlay, popup):
	overlay.queue_free()
	popup.queue_free()

func update_achievements_display():
	update_achievements_progress()
	create_achievement_categories()

# Автоматически открывает вкладку с новыми предметами
func auto_open_new_items_tab():
	var tab_container = get_node_or_null("CustomizeContainer")
	if tab_container == null:
		return
	
	# Проверяем какие категории имеют новые предметы (в порядке приоритета)
	if progression.has_new_items.get("achievements", false):
		tab_container.current_tab = 6  # Achievements
		print("🔴 Автооткрытие: Achievements")
	elif progression.has_new_items.get("avatars", false):
		tab_container.current_tab = 1  # Avatars
		print("🔴 Автооткрытие: Avatars")
	elif progression.has_new_items.get("frames", false):
		tab_container.current_tab = 2  # Frames
		print("🔴 Автооткрытие: Frames")
	elif progression.has_new_items.get("backgrounds", false):
		tab_container.current_tab = 3  # Backgrounds
		print("🔴 Автооткрытие: Backgrounds")
	elif progression.has_new_items.get("music", false):
		tab_container.current_tab = 4  # Music
		print("🔴 Автооткрытие: Music")

# Показывает карточку предмета с описанием
# Показывает карточку предмета с описанием
func show_item_card(item_type: String, item_id: int):
	var item_data = null
	
	match item_type:
		"avatar":
			item_data = ItemsDB.get_avatar_data(item_id)
		"frame":
			item_data = ItemsDB.get_frame_data(item_id)
		"background":
			item_data = ItemsDB.get_background_data(item_id)
		"music":
			item_data = ItemsDB.get_music_data(item_id)
	
	if item_data == null or item_data.is_empty():
		print("❌ Данные предмета не найдены")
		return
	
	# Затемнение
	var overlay = ColorRect.new()
	overlay.name = "ItemCardOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Карточка
	var card = PanelContainer.new()
	card.position = Vector2(150, 150)
	card.size = Vector2(600, 660)
	add_child(card)
	
	# Контент карточки
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	card.add_child(vbox)
	
	# === ПРЕВЬЮ ПРЕДМЕТА ===
	var preview_container = CenterContainer.new()
	preview_container.custom_minimum_size = Vector2(580, 200)
	vbox.add_child(preview_container)
	
	if item_type == "avatar":
		var avatar_preview = TextureRect.new()
		avatar_preview.custom_minimum_size = Vector2(150, 150)
		avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var avatar_path = "res://assets/avatars/avatar_%d.png" % item_id
		if ResourceLoader.exists(avatar_path):
			avatar_preview.texture = load(avatar_path)
		
		preview_container.add_child(avatar_preview)
	
	elif item_type == "frame":
		var frame_preview = TextureRect.new()
		frame_preview.custom_minimum_size = Vector2(180, 180)
		frame_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var frame_path = "res://assets/frames/frame_%d.png" % item_id
		if ResourceLoader.exists(frame_path):
			frame_preview.texture = load(frame_path)
		
		preview_container.add_child(frame_preview)
	
	# === НАЗВАНИЕ ===
	var name_label = Label.new()
	name_label.text = item_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# === РЕДКОСТЬ ===
	var rarity = item_data.get("rarity", "COMMON")
	var rarity_label = Label.new()
	rarity_label.text = rarity + " " + ItemsDB.get_rarity_stars(rarity)
	rarity_label.add_theme_font_size_override("font_size", 24)
	rarity_label.add_theme_color_override("font_color", ItemsDB.get_rarity_color(rarity))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)
	
	# === РАЗДЕЛИТЕЛЬ ===
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# === ОПИСАНИЕ ===
	var desc_label = Label.new()
	desc_label.text = item_data.get("description", "No description available.")
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(560, 0)
	vbox.add_child(desc_label)
	
	# === КНОПКИ ===
	var buttons_container = HBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 20)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_container)
	
	# Проверяем, выбран ли предмет
	var is_selected = false
	if item_type == "avatar":
		is_selected = (item_id == progression.player_avatar)
	elif item_type == "frame":
		is_selected = (item_id == progression.player_frame)
	
	# Кнопка SELECT / SELECTED
	var select_btn = Button.new()
	select_btn.custom_minimum_size = Vector2(250, 70)
	select_btn.add_theme_font_size_override("font_size", 28)
	
	if is_selected:
		select_btn.text = "SELECTED ✓"
		select_btn.disabled = true
		select_btn.modulate = Color(0.5, 1, 0.5)  # Зелёный оттенок
	else:
		select_btn.text = "SELECT"
		select_btn.pressed.connect(_on_select_item.bind(item_type, item_id, overlay, card))
	
	buttons_container.add_child(select_btn)
	
	# Кнопка CLOSE
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(250, 70)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_on_close_item_card.bind(overlay, card))
	buttons_container.add_child(close_btn)

func _on_select_item(item_type: String, item_id: int, overlay, card):
	# Выбираем предмет
	match item_type:
		"avatar":
			progression.player_avatar = item_id
			print("✅ Выбрана аватарка: ", item_id)
		"frame":
			progression.player_frame = item_id
			print("✅ Выбрана рамка: ", item_id)
	
	progression.save_progress()
	
	# Обновляем профиль и игру
	update_profile()
	update_game_profile_button()
	
	# Закрываем карточку
	overlay.queue_free()
	card.queue_free()
	
	# Обновляем список (чтобы подсветка обновилась)
	match item_type:
		"avatar":
			create_avatars_list()
		"frame":
			create_frames_list()

func _on_close_item_card(overlay, card):
	overlay.queue_free()
	card.queue_free()

# === РЕДАКТИРОВАНИЕ ИМЕНИ ===

func _on_edit_name_pressed():
	show_name_edit_popup()

func show_name_edit_popup():
	# Затемнение
	var overlay = ColorRect.new()
	overlay.name = "NameEditOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Popup
	var popup = PanelContainer.new()
	popup.position = Vector2(200, 350)
	popup.size = Vector2(500, 260)
	add_child(popup)
	
	# Контент
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	popup.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "Change Your Name"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Поле ввода
	var line_edit = LineEdit.new()
	line_edit.name = "NameInput"
	line_edit.text = progression.player_name
	line_edit.max_length = 10  # УМЕНЬШИЛИ с 12 до 10
	line_edit.placeholder_text = "Enter name..."
	line_edit.custom_minimum_size = Vector2(460, 60)
	line_edit.add_theme_font_size_override("font_size", 28)
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(line_edit)
	
	# Кнопки
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	
	# Cancel
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(200, 60)
	cancel_btn.add_theme_font_size_override("font_size", 24)
	cancel_btn.pressed.connect(_on_name_cancel.bind(overlay, popup))
	buttons.add_child(cancel_btn)
	
	# Save
	var save_btn = Button.new()
	save_btn.text = "SAVE"
	save_btn.custom_minimum_size = Vector2(200, 60)
	save_btn.add_theme_font_size_override("font_size", 24)
	save_btn.pressed.connect(_on_name_save.bind(line_edit, overlay, popup))
	buttons.add_child(save_btn)
	
	# Автофокус на поле ввода
	line_edit.grab_focus()

func _on_name_cancel(overlay, popup):
	overlay.queue_free()
	popup.queue_free()

func _on_name_save(line_edit: LineEdit, overlay, popup):
	var new_name = line_edit.text.strip_edges()
	
	# Валидация
	if new_name == "":
		new_name = "Player"
	
	# Сохраняем
	progression.player_name = new_name
	progression.save_progress()
	
	print("✅ Имя изменено на: ", new_name)
	
	# Обновляем профиль
	update_profile()
	update_game_profile_button()
	
	# Закрываем popup
	overlay.queue_free()
	popup.queue_free()

# Автоматически уменьшает размер текста, чтобы влезал в ширину
func adjust_text_size(label: Label, max_width: float):
	if label == null:
		return
	
	var text_length = label.text.length()
	
	# Базовый размер зависит от длины
	var font_size = 28
	
	if text_length <= 6:
		font_size = 28  # Player
	elif text_length <= 8:
		font_size = 24  # Playerok
	elif text_length <= 10:
		font_size = 20  # Playerok12
	else:
		font_size = 18  # Очень длинные (на всякий)
	
	label.add_theme_font_size_override("font_size", font_size)
	
	# Дополнительная проверка по ширине
	await get_tree().process_frame
	
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	
	var min_font_size = 14
	while font_size > min_font_size:
		var text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		
		if text_width <= max_width:
			break
		
		font_size -= 2
		label.add_theme_font_size_override("font_size", font_size)
		await get_tree().process_frame
	
	print("📏 Профиль: шрифт для '", label.text, "' (", text_length, " симв.): ", font_size, "px")
