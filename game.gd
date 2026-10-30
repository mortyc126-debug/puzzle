extends Node2D

var score = 0
var score_label = null
var active_blocks = []  # Список активных блоков
var game_over = false
var best_score = 0
var best_score_label = null

# COMBO SYSTEM
var combo_multiplier = 1
var combo_label = null

# ТАЙМЕР ИГРЫ (ДОБАВЬ ЭТО)
var game_start_time = 0  # Время начала игры
var game_timer = 0       # Таймер обновления

# Continue система
var continue_cost = 100  # Начальная цена Continue
var continue_used_count = 0  # Сколько раз продолжили в этом матче

# Ссылка на систему прогрессии
var progression = null

# Power-ups
var hammer_mode = false  # Активен ли режим молотка
var last_move = null     # Последний ход для Undo

# Ссылка на сцену блока
var block_scene = preload("res://block.tscn")

# Позиции для 3 блоков внизу экрана
var block_positions = [
	Vector2(150, 800),
	Vector2(400, 800),
	Vector2(650, 800)
]

# Библиотека форм блоков
var shapes = [
	# === ОДИНОЧНЫЕ И МАЛЕНЬКИЕ ===
	# Одиночная клетка
	[Vector2(0, 0)],
	
	# === ЛИНИИ ===
	# Горизонтальная линия 2
	[Vector2(0, 0), Vector2(1, 0)],
	
	# Горизонтальная линия 3
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)],
	
	# Горизонтальная линия 4
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)],
	
	# Вертикальная линия 2
	[Vector2(0, 0), Vector2(0, 1)],
	
	# Вертикальная линия 3
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2)],
	
	# Вертикальная линия 4
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(0, 3)],
	
	# === КВАДРАТЫ ===
	# Квадрат 2x2
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	
	# === L-ФОРМЫ (все 4 поворота) ===
	# L - стандартная
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 2)],
	
	# L - повёрнутая на 90°
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(0, 1)],
	
	# L - повёрнутая на 180°
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(1, 2)],
	
	# L - повёрнутая на 270°
	[Vector2(2, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	
	# === ОБРАТНАЯ L (все 4 поворота) ===
	# Обратная L
	[Vector2(1, 0), Vector2(1, 1), Vector2(1, 2), Vector2(0, 2)],
	
	# Обратная L - 90°
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	
	# Обратная L - 180°
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 2)],
	
	# Обратная L - 270°
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(2, 1)],
	
	# === T-ФОРМЫ (все 4 поворота) ===
	# T - стандартная
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1)],
	
	# T - 90°
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2)],
	
	# T - 180°
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	
	# T - 270°
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)],
	
	# === Z-ФОРМЫ (2 поворота) ===
	# Z - горизонтальная
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)],
	
	# Z - вертикальная
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)],
	
	# === S-ФОРМЫ (2 поворота) ===
	# S - горизонтальная
	[Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(1, 1)],
	
	# S - вертикальная
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2)],
	
	# === МАЛЕНЬКИЕ L ===
	# Маленькая L (3 клетки)
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
	
	# Маленькая обратная L
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	
	# === УГОЛКИ ===
	# Уголок 2x2 (левый верхний)
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
	
	# Уголок 2x2 (правый верхний)
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	
	# Уголок 2x2 (левый нижний)
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
	
	# Уголок 2x2 (правый нижний)
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
]

# Цвета для блоков
var colors = ItemsDB.block_colors

func _ready():
	# Убираем тени от всех кнопок
	remove_button_shadows()
	# Загружаем и применяем настройки при запуске
	load_and_apply_settings()
	# Получаем ссылку на систему прогрессии
	progression = get_node("Progression")
	
	# Подключаем кнопку Settings
	var settings_btn = get_node("SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	
	# Подписываемся на события прогрессии
	progression.xp_gained.connect(_on_xp_gained)
	progression.level_up.connect(_on_level_up)
	progression.coins_changed.connect(_on_coins_changed)
	progression.reward_unlocked.connect(_on_reward_unlocked)
	# Загружаем лучший результат
	load_best_score()
	
	# Создаём label для текущих очков
	score_label = Label.new()
	score_label.position = Vector2(450, 80)  # По центру
	score_label.add_theme_font_size_override("font_size", 64)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 4)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.size = Vector2(400, 100)
	score_label.position.x -= 200  # Центрируем
	score_label.text = "0"
	add_child(score_label)
	
	# Создаём label для лучшего результата (ПО ЦЕНТРУ ВВЕРХУ)
	best_score_label = Label.new()
	best_score_label.position = Vector2(350, 20)  # Центр вверху
	best_score_label.add_theme_font_size_override("font_size", 32)
	best_score_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	best_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	best_score_label.add_theme_constant_override("outline_size", 3)
	best_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_score_label.size = Vector2(200, 40)
	best_score_label.text = "Best: " + str(best_score)
	add_child(best_score_label)
	
	# Label для XP
	var xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.position = Vector2(450, 175)
	xp_label.add_theme_font_size_override("font_size", 18)
	xp_label.add_theme_color_override("font_color", Color.WHITE)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.size = Vector2(200, 30)
	xp_label.position.x -= 100
	xp_label.text = str(progression.current_xp) + " / " + str(progression.get_xp_for_next_level()) + " XP"
	add_child(xp_label)
	
	# === COMBO LABEL (ДОБАВЬ ПОСЛЕ XP LABEL) ===
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(250, 400)  # По центру экрана
	combo_label.size = Vector2(400, 150)
	combo_label.add_theme_font_size_override("font_size", 72)
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.text = ""
	combo_label.modulate = Color(1, 1, 1, 0)  # Изначально невидим
	add_child(combo_label)
	
	# Label для монет
	var coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.position = Vector2(700, 80)
	coins_label.add_theme_font_size_override("font_size", 28)
	coins_label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # Золотой
	coins_label.add_theme_color_override("font_outline_color", Color.BLACK)
	coins_label.add_theme_constant_override("outline_size", 2)
	coins_label.text = "💰 " + str(progression.total_coins)
	add_child(coins_label)
	
	# Label для мультипликатора
	var multiplier_label = Label.new()
	multiplier_label.name = "MultiplierLabel"
	multiplier_label.position = Vector2(700, 120)
	multiplier_label.add_theme_font_size_override("font_size", 24)
	multiplier_label.add_theme_color_override("font_color", Color(1, 0.5, 0))  # Оранжевый
	multiplier_label.add_theme_color_override("font_outline_color", Color.BLACK)
	multiplier_label.add_theme_constant_override("outline_size", 2)
	multiplier_label.text = "x1.0"
	multiplier_label.visible = false  # Скрыт пока множитель = 1.0
	add_child(multiplier_label)
	
	# Прогресс-бар XP
	var xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.position = Vector2(50, 150)
	xp_bar.size = Vector2(800, 20)
	xp_bar.max_value = progression.get_xp_for_next_level()
	xp_bar.value = progression.current_xp
	xp_bar.show_percentage = false
	add_child(xp_bar)
	
		# Подключаем кнопку профиля
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn:
		print("━━━ ИНИЦИАЛИЗАЦИЯ PROFILEBUTTON ━━━")
		profile_btn.pressed.connect(_on_profile_pressed)
		profile_btn.ignore_texture_size = true
		profile_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Загружаем аватарку
		var avatar_id = progression.player_avatar
		var avatar_path = "res://assets/avatars/avatar_%d.png" % avatar_id
		
		if ResourceLoader.exists(avatar_path):
			var texture = load(avatar_path)
			profile_btn.texture_normal = texture
			print("✅ Аватарка загружена: ", avatar_id)
		
		# Загружаем рамку
		var frame_id = progression.player_frame
		var frame_path = "res://assets/frames/frame_%d.png" % frame_id
		var profile_frame = profile_btn.get_node_or_null("ProfileFrame")
		
		if profile_frame and ResourceLoader.exists(frame_path):
			profile_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			profile_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var frame_texture = load(frame_path)
			profile_frame.texture = frame_texture
			print("✅ Рамка загружена: ", frame_id)
		
		# Уровень на рамке
		var profile_level_label = profile_btn.get_node_or_null("ProfileLevelLabel")
		if profile_level_label:
			profile_level_label.text = str(progression.current_level)
			print("✅ Уровень установлен: ", progression.current_level)
			
		# Имя игрока
		var name_label = profile_btn.get_node_or_null("PlayerNameLabel")
		if name_label:
			print("✅ PlayerNameLabel найден!")
			print("   → Тип узла: ", name_label.get_class())
			print("   → Текущий текст: '", name_label.text, "'")
			print("   → Имя из progression: '", progression.player_name, "'")
			name_label.text = progression.player_name
			print("   → Текст установлен: '", name_label.text, "'")
		else:
			print("❌ PlayerNameLabel НЕ НАЙДЕН!")
		
		# Обновляем индикатор новых достижений
		update_achievements_indicator()
		
		print("━━━ ОЖИДАНИЕ ЗАГРУЗКИ... ━━━")
	
	# Ждём загрузки и обновляем имя
	await get_tree().process_frame
	await get_tree().process_frame
	print("━━━ ВЫЗЫВАЕМ update_profile_name_display() ━━━")
	update_profile_name_display()
	
	# Подписываемся на сигнал очистки линий
	var grid = get_node("Grid")
	grid.lines_cleared.connect(_on_lines_cleared)
	
	# Создаём первые 3 блока
	spawn_blocks()
	
	# Подключаем кнопку Restart
	var restart_btn = get_node("RestartButton")
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_button_pressed)
	
	# Подключаем кнопку Battle Pass
	var bp_button = get_node("BattlePassButton")
	if bp_button:
		bp_button.pressed.connect(_on_battle_pass_pressed)
	
	# Подключаем кнопки Power-ups
	var hammer_btn = get_node_or_null("HammerButton")
	var shuffle_btn = get_node_or_null("ShuffleButton")
	var undo_btn = get_node_or_null("UndoButton")
	
	if hammer_btn:
		hammer_btn.pressed.connect(_on_hammer_pressed)
	if shuffle_btn:
		shuffle_btn.pressed.connect(_on_shuffle_pressed)
	if undo_btn:
		undo_btn.pressed.connect(_on_undo_pressed)
	
	# Обновляем состояние кнопок
	update_powerup_buttons()
	
	# Кнопка Daily Reward
	var daily_btn = Button.new()
	daily_btn.name = "DailyButton"
	daily_btn.position = Vector2(580, 880)
	daily_btn.size = Vector2(180, 60)
	daily_btn.text = "🎁 DAILY"
	daily_btn.add_theme_font_size_override("font_size", 24)
	daily_btn.pressed.connect(_on_daily_pressed)
	add_child(daily_btn)
	
	# Подписываемся на события Daily Rewards
	progression.daily_reward_available.connect(_on_daily_available)
	progression.daily_reward_claimed.connect(_on_daily_claimed)
	
	# Обновляем кнопку Daily Reward
	update_daily_button()
	
	# ДОБАВЬ ЭТО:
	# Запускаем таймер игры
	game_start_time = Time.get_unix_time_from_system()

func spawn_blocks():
	# Очищаем список активных блоков
	active_blocks.clear()
	
	# Берём только существующие индексы цветов из профиля
	var active_colors = []
	for color_index in progression.active_colors:
		if color_index >= 0 and color_index < colors.size():
			active_colors.append(color_index)
	
	# Создаём 3 случайных блока
	for i in range(3):
		var block = block_scene.instantiate()
		
		# Задаём случайную форму
		var random_shape = shapes[randi() % shapes.size()]
		block.shape = random_shape
		
		# ИСПОЛЬЗУЕМ ЦВЕТА ИЗ ПРОГРЕССИИ
		if active_colors.size() > 0:
			block.color = colors[active_colors[randi() % active_colors.size()]]
		else:
			# Fallback если нет активных цветов
			block.color = colors[randi() % colors.size()]
		
		# Вычисляем центр формы для правильного позиционирования
		var min_x = 0
		var max_x = 0
		var min_y = 0
		var max_y = 0
		
		for cell in random_shape:
			if cell.x < min_x:
				min_x = cell.x
			if cell.x > max_x:
				max_x = cell.x
			if cell.y < min_y:
				min_y = cell.y
			if cell.y > max_y:
				max_y = cell.y
		
		var width = (max_x - min_x + 1) * 80  # 80 = cell_size
		var height = (max_y - min_y + 1) * 80
		
		# Центрируем блок относительно позиции
		var offset_x = width / 2.0
		var offset_y = height / 2.0
		
		# Позиционируем блок с учётом центрирования
		block.global_position = block_positions[i] - Vector2(offset_x, offset_y)
		
		# Подписываемся на удаление блока
		block.tree_exited.connect(_on_block_removed)
		
		# Добавляем в сцену
		add_child(block)
		active_blocks.append(block)
	
	# Проверяем Game Over сразу после создания блоков
	check_game_over()

func _on_block_removed():
	# Проверяем, что сцена всё ещё активна (не во время перезагрузки)
	if not is_inside_tree():
		return
	
	# Ждём один кадр, чтобы все блоки успели удалиться
	await get_tree().process_frame
	
	# Ещё раз проверяем (могли перезагрузить во время ожидания)
	if not is_inside_tree():
		return
	
	# Подсчитываем оставшиеся блоки
	var remaining = 0
	for block in active_blocks:
		if is_instance_valid(block):
			remaining += 1
	
	# Если все блоки размещены — создаём новые
	if remaining == 0:
		print("Все блоки размещены! Создаём новые...")
		spawn_blocks()
		# Проверяем Game Over ПОСЛЕ создания новых блоков
		await get_tree().process_frame
		check_game_over()
	else:
		# Если остались блоки — проверяем Game Over
		# ВАЖНО: Ждём ещё немного, чтобы очистка линий точно завершилась
		await get_tree().create_timer(0.1).timeout
		if is_inside_tree():  # Проверяем ещё раз
			check_game_over()

func _on_lines_cleared(count: int):
	# ВОСПРОИЗВОДИМ ЗВУК ОЧИСТКИ
	var sound_clear = get_node("SoundClear")
	if sound_clear:
		sound_clear.play()
	
	# ЗАПИСЫВАЕМ СТАТИСТИКУ (ДОБАВЬ ЭТО)
	progression.record_lines_cleared(count)
	
	# === РАССЧИТЫВАЕМ КОМБО ===
	combo_multiplier = count
	
	# ЗАПИСЫВАЕМ КОМБО (ДОБАВЬ ЭТО)
	progression.record_combo(combo_multiplier)
	
	# Начисляем очки С КОМБО-МНОЖИТЕЛЕМ
	var base_points = count * 10  # 10 очков за линию
	var combo_points = base_points * combo_multiplier
	score += combo_points
	score_label.text = str(score)
	
	print("🔥 Очищено линий: ", count, " | Комбо: x", combo_multiplier, " | Очки: +", combo_points)
	
	# === ПОКАЗЫВАЕМ КОМБО ТЕКСТ ===
	show_combo_text(count)
	
	# ОБНОВЛЯЕМ МУЛЬТИПЛИКАТОР на основе текущего счёта
	progression.score_multiplier = progression.calculate_multiplier(score)
	
	# Обновляем UI множителя
	var multiplier_label = get_node_or_null("MultiplierLabel")
	if multiplier_label:
		multiplier_label.text = "x" + str(progression.score_multiplier)
		multiplier_label.visible = progression.score_multiplier > 1.0
	
	# НАЧИСЛЯЕМ XP за очистку линий С МУЛЬТИПЛИКАТОРОМ И КОМБО
	var base_xp = count * 5  # Базовые 5 XP за линию
	if count >= 2:
		base_xp += 10  # Бонус за несколько линий
	
	# Добавляем бонус за комбо
	var combo_bonus_xp = count * 2 * combo_multiplier  # Дополнительный XP за комбо
	base_xp += combo_bonus_xp
	
	var final_xp = int(base_xp * progression.score_multiplier)
	progression.gain_xp(final_xp)
	
	print("XP с множителем x", progression.score_multiplier, " и комбо x", combo_multiplier, ": ", final_xp)
	
	# Обновляем лучший результат
	if score > best_score:
		best_score = score
		best_score_label.text = "Best: " + str(best_score)
		save_best_score()
	
	print("Очки: ", score, " | Множитель: x", progression.score_multiplier, " | Комбо: x", combo_multiplier)

# Проверяет, можно ли разместить хотя бы один из активных блоков
func check_game_over():
	if game_over:
		return
	
	var grid = get_node("Grid")
	var can_place_any = false
	
	# Проверяем каждый активный блок
	for block in active_blocks:
		if is_instance_valid(block):
			# Проверяем ВСЕ возможные позиции на сетке
			if can_block_be_placed_anywhere(block, grid):
				can_place_any = true
				break
	
	# Если ни один блок нельзя разместить — сразу Game Over
	if not can_place_any:
		game_over = true
		show_game_over()

# Проверяет, можно ли разместить блок где-либо на сетке
func can_block_be_placed_anywhere(block, grid) -> bool:
	# Перебираем ВСЕ возможные стартовые позиции
	for start_y in range(8):
		for start_x in range(8):
			# Проверяем, можно ли разместить блок начиная с этой позиции
			var can_place = true
			
			for cell in block.shape:
				var check_x = start_x + int(cell.x)
				var check_y = start_y + int(cell.y)
				
				# Проверяем границы и занятость клетки
				if check_x < 0 or check_x >= 8 or check_y < 0 or check_y >= 8:
					can_place = false
					break
				
				if grid.grid_data[check_y][check_x] != 0:
					can_place = false
					break
			
			# Если нашли хотя бы одну подходящую позицию
			if can_place:
				return true
	
	# Не нашли ни одной подходящей позиции
	return false

func show_game_over():
	# Проверяем Continue ДО наград
	var can_continue = progression.total_coins >= continue_cost
	
	# Начисляем награды
	award_game_over_rewards()
	
	# Перепроверяем после наград
	can_continue = progression.total_coins >= continue_cost
	
	if can_continue:
		show_continue_screen()
	else:
		show_final_game_over()

func _on_restart_pressed():
	# Перезагружаем сцену
	get_tree().reload_current_scene()

# Сохраняет лучший результат в файл
func save_best_score():
	var file = FileAccess.open("user://best_score.save", FileAccess.WRITE)
	if file:
		file.store_var(best_score)
		file.close()
		print("Лучший результат сохранён: ", best_score)

# Загружает лучший результат из файла
func load_best_score():
	if FileAccess.file_exists("user://best_score.save"):
		var file = FileAccess.open("user://best_score.save", FileAccess.READ)
		if file:
			best_score = file.get_var()
			file.close()
			print("Лучший результат загружен: ", best_score)
	else:
		best_score = 0
		print("Файла сохранения нет, начинаем с 0")

# Обработчики событий прогрессии
func _on_xp_gained(amount: int):
	print("Получено XP: +", amount)
	
	# Обновляем UI
	var xp_bar = get_node_or_null("XPBar")
	var xp_label = get_node_or_null("XPLabel")
	
	if xp_bar:
		xp_bar.max_value = progression.get_xp_for_next_level()
		xp_bar.value = progression.current_xp
	
	if xp_label:
		xp_label.text = str(progression.current_xp) + " / " + str(progression.get_xp_for_next_level()) + " XP"

func _on_level_up(new_level: int):
	print("🎉 LEVEL UP! Новый уровень: ", new_level)
	
	var xp_bar = get_node_or_null("XPBar")
	var xp_label = get_node_or_null("XPLabel")
	
	if xp_bar:
		xp_bar.max_value = progression.get_xp_for_next_level()
		xp_bar.value = progression.current_xp
	
	if xp_label:
		xp_label.text = str(progression.current_xp) + " / " + str(progression.get_xp_for_next_level()) + " XP"

func _on_coins_changed(new_amount: int):
	print("💰 Монет: ", new_amount)
	
	# Обновляем UI
	var coins_label = get_node_or_null("CoinsLabel")
	if coins_label:
		coins_label.text = "💰 " + str(new_amount)
	
	# Обновляем кнопки Power-ups
	update_powerup_buttons()

func _on_reward_unlocked(reward_type: String, reward_data):
	print("🎁 Разблокировано: ", reward_type, " - ", reward_data)
	# TODO: Показать красивое уведомление

func _on_battle_pass_pressed():
	# Загружаем сцену Battle Pass
	var bp_scene = load("res://battle_pass.tscn")
	var bp_instance = bp_scene.instantiate()
	add_child(bp_instance)

# Обновляет состояние кнопок Power-ups
func update_powerup_buttons():
	var hammer_btn = get_node_or_null("HammerButton")
	var shuffle_btn = get_node_or_null("ShuffleButton")
	var undo_btn = get_node_or_null("UndoButton")
	
	if hammer_btn:
		hammer_btn.disabled = progression.total_coins < 10  # Было 20, стало 10
	if shuffle_btn:
		shuffle_btn.disabled = progression.total_coins < 30
	if undo_btn:
		undo_btn.disabled = (progression.total_coins < 20) or (last_move == null)

# === POWER-UPS ===

func _on_hammer_pressed():
	if not progression.spend_coins(10):  # Было 20, стало 10
		print("Недостаточно монет!")
		return
	
	print("🔨 Hammer активирован! Кликни на блок на сетке чтобы удалить.")
	hammer_mode = true
	
	# Меняем текст кнопки
	var hammer_btn = get_node("HammerButton")
	if hammer_btn:
		hammer_btn.text = "🔨 Кликни\nна блок!"
		hammer_btn.modulate = Color(1, 1, 0)  # Жёлтая подсветка

func use_hammer_on_cell(x: int, y: int):
	var grid = get_node("Grid")
	if grid == null:
		return
	
	# Проверяем что клетка занята
	if grid.grid_data[y][x] == 0:
		print("Клетка пустая!")
		return
	
	# Удаляем блок
	grid.grid_data[y][x] = 0
	grid.block_colors[y][x] = Color.TRANSPARENT
	grid.queue_redraw()
	
	print("🔨 Блок удалён!")
	
	# Выключаем режим молотка
	hammer_mode = false
	var hammer_btn = get_node("HammerButton")
	if hammer_btn:
		hammer_btn.text = "🔨 Hammer\n10💰"  # ВОЗВРАЩАЕМ ПРАВИЛЬНУЮ ЦЕНУ
		hammer_btn.modulate = Color.WHITE
	
	# Обновляем состояние кнопок
	update_powerup_buttons()

func _on_shuffle_pressed():
	if not progression.spend_coins(30):
		print("Недостаточно монет!")
		return
	
	print("🔄 Shuffle! Заменяем все блоки...")
	
	# Удаляем все текущие блоки
	for block in active_blocks:
		if is_instance_valid(block):
			block.queue_free()
	
	active_blocks.clear()
	
	# Создаём новые блоки
	spawn_blocks()
	
	print("🔄 Новые блоки созданы!")

func _on_undo_pressed():
	if last_move == null:
		print("Нет хода для отмены!")
		return
	
	if not progression.spend_coins(20):
		print("Недостаточно монет!")
		return
	
	print("↩️ Undo! Отменяем последний ход...")
	
	var grid = get_node("Grid")
	if grid == null:
		return
	
	# Удаляем блоки последнего хода
	for cell_pos in last_move["cells"]:
		var x = int(cell_pos.x)
		var y = int(cell_pos.y)
		grid.grid_data[y][x] = 0
		grid.block_colors[y][x] = Color.TRANSPARENT
	
	grid.queue_redraw()
	
	# Создаём блок обратно внизу
	var block = block_scene.instantiate()
	
	# Вычисляем форму из saved cells
	var min_x = 999
	var min_y = 999
	for cell_pos in last_move["cells"]:
		if cell_pos.x < min_x:
			min_x = cell_pos.x
		if cell_pos.y < min_y:
			min_y = cell_pos.y
	
	var restored_shape = []
	for cell_pos in last_move["cells"]:
		restored_shape.append(Vector2(cell_pos.x - min_x, cell_pos.y - min_y))
	
	block.shape = restored_shape
	block.color = last_move["color"]
	
	# Находим свободную позицию внизу
	var free_position = null
	for pos in block_positions:
		var occupied = false
		for existing_block in active_blocks:
			if is_instance_valid(existing_block):
				if existing_block.global_position.distance_to(pos) < 50:
					occupied = true
					break
		if not occupied:
			free_position = pos
			break
	
	if free_position == null:
		free_position = block_positions[0]  # Fallback
	
	# Центрируем блок
	var width = 0
	var height = 0
	for cell in restored_shape:
		if cell.x > width:
			width = cell.x
		if cell.y > height:
			height = cell.y
	
	var offset_x = (width + 1) * 80 / 2.0
	var offset_y = (height + 1) * 80 / 2.0
	
	block.global_position = free_position - Vector2(offset_x, offset_y)
	block.tree_exited.connect(_on_block_removed)
	add_child(block)
	active_blocks.append(block)
	
	print("↩️ Ход отменён! Блок возвращён.")
	
	# Очищаем last_move
	last_move = null
	update_powerup_buttons()

# === DAILY REWARDS ===

func update_daily_button():
	var daily_btn = get_node_or_null("DailyButton")
	if daily_btn == null:
		return
	
	if progression.can_claim_daily:
		daily_btn.text = "🎁 DAILY"
		daily_btn.modulate = Color(1, 1, 0)  # Жёлтая — доступна награда
		daily_btn.disabled = false
	else:
		daily_btn.text = "🎁 DAILY"  # УБРАЛИ "Tomorrow"
		daily_btn.modulate = Color(0.6, 0.6, 0.6)  # Серая
		daily_btn.disabled = true

func _on_daily_available():
	update_daily_button()

func _on_daily_pressed():
	if not progression.can_claim_daily:
		print("Ежедневная награда уже получена!")
		return
	
	show_daily_reward_popup()

func _on_daily_claimed(day: int, reward: Dictionary):
	update_daily_button()

func show_daily_reward_popup():
	# Создаём затемнение
	var overlay = ColorRect.new()
	overlay.name = "DailyOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	add_child(overlay)
	
	# Контейнер для UI
	var container = VBoxContainer.new()
	container.position = Vector2(200, 250)
	container.custom_minimum_size = Vector2(500, 400)
	add_child(container)
	
	# Заголовок
	var title = Label.new()
	title.text = "DAILY REWARD"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	# Показываем все 7 дней
	for day in range(1, 8):
		var day_container = HBoxContainer.new()
		day_container.custom_minimum_size = Vector2(480, 50)
		
		var day_label = Label.new()
		day_label.text = "Day %d" % day
		day_label.custom_minimum_size = Vector2(100, 50)
		day_label.add_theme_font_size_override("font_size", 24)
		day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var reward = progression.get_daily_reward_for_day(day)
		var reward_label = Label.new()
		var reward_text = ""
		if reward.has("coins"):
			reward_text += "%d 💰" % reward["coins"]
		if reward.has("xp"):
			reward_text += " + %d XP" % reward["xp"]
		reward_label.text = reward_text
		reward_label.custom_minimum_size = Vector2(200, 50)
		reward_label.add_theme_font_size_override("font_size", 24)
		reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var status_label = Label.new()
		status_label.custom_minimum_size = Vector2(80, 50)
		status_label.add_theme_font_size_override("font_size", 28)
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		if day < progression.daily_streak:
			status_label.text = "✓"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		elif day == progression.daily_streak:
			status_label.text = "→"
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			status_label.text = "🔒"
			status_label.add_theme_color_override("font_color", Color.GRAY)
		
		day_container.add_child(day_label)
		day_container.add_child(reward_label)
		day_container.add_child(status_label)
		container.add_child(day_container)
	
	# Кнопка Claim
	var claim_btn = Button.new()
	claim_btn.text = "CLAIM REWARD!"
	claim_btn.custom_minimum_size = Vector2(300, 60)
	claim_btn.add_theme_font_size_override("font_size", 32)
	claim_btn.pressed.connect(_on_claim_daily_reward.bind(overlay, container))
	container.add_child(claim_btn)

func _on_claim_daily_reward(overlay, container):
	# Получаем награду
	var reward = progression.claim_daily_reward()
	
	if reward.is_empty():
		print("Награда уже получена!")
		return
	
	# Удаляем UI
	overlay.queue_free()
	container.queue_free()
	
	# Показываем уведомление
	var notification = Label.new()
	notification.position = Vector2(300, 400)
	notification.size = Vector2(300, 100)
	
	var text = "🎁 Day %d Claimed!\n" % progression.daily_streak
	if reward.has("coins"):
		text += "+%d 💰\n" % reward["coins"]
	if reward.has("xp"):
		text += "+%d XP" % reward["xp"]
	
	notification.text = text
	notification.add_theme_font_size_override("font_size", 32)
	notification.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	notification.add_theme_color_override("font_outline_color", Color.BLACK)
	notification.add_theme_constant_override("outline_size", 3)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(notification)
	
	# Удаляем уведомление через 3 секунды
	await get_tree().create_timer(3.0).timeout
	notification.queue_free()

func _on_settings_pressed():
	# Загружаем сцену Settings
	var settings_scene = load("res://settings.tscn")
	var settings_instance = settings_scene.instantiate()
	add_child(settings_instance)
	
# Загружает и применяет сохранённые настройки
func load_and_apply_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()
			
			var sound_enabled = save_data.get("sound", true)
			var music_enabled = save_data.get("music", true)
			
			# Применяем к аудио
			var sfx_bus = AudioServer.get_bus_index("SFX")
			var music_bus = AudioServer.get_bus_index("Music")
			
			if sfx_bus >= 0:
				AudioServer.set_bus_mute(sfx_bus, not sound_enabled)
			if music_bus >= 0:
				AudioServer.set_bus_mute(music_bus, not music_enabled)
			
			print("Настройки применены при запуске")

# Убирает тени от всех кнопок в сцене
func remove_button_shadows():
	for node in get_tree().get_nodes_in_group("buttons"):
		if node is Button:
			var stylebox = StyleBoxFlat.new()
			stylebox.bg_color = Color(0.2, 0.2, 0.2)
			stylebox.shadow_size = 0
			node.add_theme_stylebox_override("normal", stylebox)
	
	# Применяем ко всем кнопкам
	await get_tree().process_frame
	for child in get_all_children(self):
		if child is Button:
			child.flat = true  # Плоский стиль без теней

# Получает всех потомков узла рекурсивно
func get_all_children(node) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(get_all_children(child))
	return children

func _on_restart_button_pressed():
	# Показываем подтверждение
	show_restart_confirmation()

func show_restart_confirmation():
	# Проверяем, нет ли уже окна подтверждения
	if get_node_or_null("RestartConfirmation") != null:
		return
	
	# Создаём затемнение
	var overlay = ColorRect.new()
	overlay.name = "RestartConfirmation"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	add_child(overlay)
	
	# Контейнер для UI
	var container = VBoxContainer.new()
	container.position = Vector2(250, 350)
	container.custom_minimum_size = Vector2(400, 200)
	container.add_theme_constant_override("separation", 20)
	add_child(container)
	
	# Предупреждение
	var warning_label = Label.new()
	warning_label.text = "⚠️ RESTART GAME?\n\nYou will lose current progress"
	warning_label.add_theme_font_size_override("font_size", 28)
	warning_label.add_theme_color_override("font_color", Color.YELLOW)
	warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	warning_label.add_theme_constant_override("outline_size", 3)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.custom_minimum_size = Vector2(400, 120)
	container.add_child(warning_label)
	
	# Кнопки
	var buttons_container = HBoxContainer.new()
	buttons_container.custom_minimum_size = Vector2(400, 80)
	buttons_container.add_theme_constant_override("separation", 20)
	container.add_child(buttons_container)
	
	# Кнопка Cancel
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(180, 70)
	cancel_btn.add_theme_font_size_override("font_size", 28)
	cancel_btn.pressed.connect(_on_restart_cancel.bind(overlay, container))
	buttons_container.add_child(cancel_btn)
	
	# Кнопка Restart
	var confirm_btn = Button.new()
	confirm_btn.text = "RESTART"
	confirm_btn.custom_minimum_size = Vector2(180, 70)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.pressed.connect(_on_restart_confirm.bind(overlay, container))
	buttons_container.add_child(confirm_btn)

func _on_restart_cancel(overlay, container):
	overlay.queue_free()
	container.queue_free()

func _on_restart_confirm(overlay, container):
	overlay.queue_free()
	container.queue_free()
	
	# НАЧИСЛЯЕМ НАГРАДЫ (как при Game Over)
	award_game_over_rewards()
	
	# Перезагружаем сцену
	get_tree().reload_current_scene()

# Начисляет награды как при Game Over (без показа экрана)
func award_game_over_rewards():
	# Проверяем, есть ли вообще счёт
	if score == 0:
		print("🎮 Счёт 0, награды не начисляются")
		return
	
	# ЗАПИСЫВАЕМ ИГРУ (ДОБАВЬ ЭТО)
	progression.record_game_finished(score)
	
	# НАЧИСЛЯЕМ XP за завершённую игру С МУЛЬТИПЛИКАТОРОМ
	var base_xp = 10
	
	# Бонусы за высокие очки
	if score >= 1000:
		base_xp += 20
	if score >= 5000:
		base_xp += 50
	if score >= 10000:
		base_xp += 100
	
	var final_xp = int(base_xp * progression.score_multiplier)
	progression.gain_xp(final_xp)
	print("🎮 Restart награды: XP с множителем x", progression.score_multiplier, ": ", final_xp)
	
	# КОНВЕРТАЦИЯ ОЧКОВ В МОНЕТЫ С МУЛЬТИПЛИКАТОРОМ
	var base_coins = int(score / 10.0)
	var final_coins = int(base_coins * progression.score_multiplier)
	
	if final_coins > 0:
		progression.add_coins(final_coins)
		# ЗАПИСЫВАЕМ ЗАРАБОТАННЫЕ МОНЕТЫ (ДОБАВЬ ЭТО)
		progression.record_coins_earned(final_coins)
		print("🎮 Restart награды: монет за очки (x", progression.score_multiplier, "): ", final_coins)
	
	# Бонус за побитие рекорда (без мультипликатора)
	if score > best_score:
		progression.add_coins(20)
		# ЗАПИСЫВАЕМ БОНУС (ДОБАВЬ ЭТО)
		progression.record_coins_earned(20)
		print("🎮 Restart награды: бонус за новый рекорд: +20 монет!")
	
	# СБРАСЫВАЕМ МУЛЬТИПЛИКАТОР для новой игры
	progression.reset_multiplier()
	
	print("🎮 RESTART с наградами! Финальный счёт: ", score)

# === CONTINUE СИСТЕМА ===

func show_continue_screen():
	# ВОСПРОИЗВОДИМ ЗВУК GAME OVER
	var sound_gameover = get_node("SoundGameOver")
	if sound_gameover:
		sound_gameover.play()
	
	# Создаём затемнение
	var overlay = ColorRect.new()
	overlay.name = "ContinueOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	add_child(overlay)
	
	# Контейнер
	var container = VBoxContainer.new()
	container.position = Vector2(200, 300)
	container.custom_minimum_size = Vector2(500, 400)
	container.add_theme_constant_override("separation", 30)
	add_child(container)
	
	# Заголовок
	var title_label = Label.new()
	title_label.text = "CONTINUE?"
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title_label)
	
	# Текущий счёт
	var score_label_continue = Label.new()
	score_label_continue.text = "Score: " + str(score)
	score_label_continue.add_theme_font_size_override("font_size", 36)
	score_label_continue.add_theme_color_override("font_color", Color.WHITE)
	score_label_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(score_label_continue)
	
	# Цена Continue
	var cost_label = Label.new()
	cost_label.text = "💰 " + str(continue_cost) + " coins"
	cost_label.add_theme_font_size_override("font_size", 48)
	cost_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_label.add_theme_constant_override("outline_size", 3)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(cost_label)
	
	# Кнопки
	var buttons_container = HBoxContainer.new()
	buttons_container.custom_minimum_size = Vector2(500, 80)
	buttons_container.add_theme_constant_override("separation", 30)
	container.add_child(buttons_container)
	
	# Кнопка Give Up
	var give_up_btn = Button.new()
	give_up_btn.text = "GIVE UP"
	give_up_btn.custom_minimum_size = Vector2(220, 80)
	give_up_btn.add_theme_font_size_override("font_size", 32)
	give_up_btn.pressed.connect(_on_give_up.bind(overlay, container))
	buttons_container.add_child(give_up_btn)
	
	# Кнопка Continue
	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.custom_minimum_size = Vector2(220, 80)
	continue_btn.add_theme_font_size_override("font_size", 32)
	continue_btn.pressed.connect(_on_continue_game.bind(overlay, container))
	buttons_container.add_child(continue_btn)

func _on_continue_game(overlay, container):
	# Тратим монеты
	if not progression.spend_coins(continue_cost):
		print("Недостаточно монет!")
		return
	
	print("💎 CONTINUE! Потрачено: ", continue_cost, " монет")
	
	# Увеличиваем цену для следующего раза
	continue_used_count += 1
	continue_cost *= 2
	print("💎 Следующий Continue будет стоить: ", continue_cost)
	
	# Удаляем UI
	overlay.queue_free()
	container.queue_free()
	
	# === УДАЛЯЕМ СТАРЫЕ БЛОКИ ===
	for block in active_blocks:
		if is_instance_valid(block):
			block.queue_free()
	
	active_blocks.clear()
	
	# Продолжаем игру — создаём НОВЫЕ блоки
	game_over = false
	spawn_blocks()
	
	print("💎 Игра продолжается!")

func _on_give_up(overlay, container):
	# Удаляем экран Continue
	overlay.queue_free()
	container.queue_free()
	
	# ЗАПИСЫВАЕМ ИГРУ ПЕРЕД GAME OVER (ДОБАВЬ ЭТО)
	if score > 0:
		progression.record_game_finished(score)
	
	# Показываем финальный Game Over
	show_final_game_over()

func show_final_game_over():
	# ФИНАЛЬНОЕ СОХРАНЕНИЕ И ПРОВЕРКА ДОСТИЖЕНИЙ
	progression.save_progress()
	progression.check_achievements()
	
	# ВОСПРОИЗВОДИМ ЗВУК GAME OVER
	var sound_gameover = get_node("SoundGameOver")
	if sound_gameover:
		sound_gameover.play()
	
	# Сбрасываем цену Continue для новой игры
	continue_cost = 100
	continue_used_count = 0
	
	# Создаём затемнение фона
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(900, 960)
	overlay.position = Vector2(0, 0)
	add_child(overlay)
	
	# Текст Game Over
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.position = Vector2(450, 300)
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.size = Vector2(400, 100)
	game_over_label.position.x -= 200
	add_child(game_over_label)
	
	# Финальный счёт
	var final_score_label = Label.new()
	final_score_label.text = "Score: " + str(score)
	final_score_label.position = Vector2(450, 400)
	final_score_label.add_theme_font_size_override("font_size", 48)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.size = Vector2(400, 80)
	final_score_label.position.x -= 200
	add_child(final_score_label)
	
	# Кнопка Restart
	var restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.position = Vector2(350, 620)
	restart_button.size = Vector2(200, 80)
	restart_button.add_theme_font_size_override("font_size", 32)
	restart_button.pressed.connect(_on_restart_pressed)
	add_child(restart_button)

func _on_profile_pressed():
	# Загружаем профиль
	var profile_scene = load("res://profile.tscn")
	var profile_instance = profile_scene.instantiate()
	add_child(profile_instance)

# === COMBO SYSTEM ===

func show_combo_text(lines_count: int):
	if combo_label == null:
		return
	
	# Определяем текст и цвет по количеству линий
	var combo_text = ""
	var combo_color = Color.WHITE
	var shake_strength = 0.0
	
	match lines_count:
		1:
			# 1 линия — без эффектов
			return
		2:
			combo_text = "DOUBLE!"
			combo_color = Color.YELLOW
			shake_strength = 5.0
		3:
			combo_text = "TRIPLE!"
			combo_color = Color.ORANGE
			shake_strength = 10.0
		4:
			combo_text = "MEGA!"
			combo_color = Color.RED
			shake_strength = 15.0
		5:
			combo_text = "INSANE!"
			combo_color = Color.MAGENTA
			shake_strength = 20.0
		6:
			combo_text = "LEGENDARY!"
			combo_color = Color(1, 0.84, 0)  # Золотой
			shake_strength = 25.0
		_:
			if lines_count >= 7:
				combo_text = "GODLIKE!"
				combo_color = Color(0.5, 1, 1)  # Голубой
				shake_strength = 30.0
	
	# Устанавливаем текст и цвет
	combo_label.text = combo_text
	combo_label.add_theme_color_override("font_color", combo_color)
	
	# Анимация появления
	animate_combo_label()
	
	# Screen shake
	if shake_strength > 0:
		screen_shake(shake_strength)
	
	# Создаём частицы
	spawn_combo_particles(combo_color)

# Анимация комбо текста
func animate_combo_label():
	if combo_label == null:
		return
	
	# Сброс позиции и размера
	combo_label.position = Vector2(250, 350)
	combo_label.scale = Vector2(0.5, 0.5)
	combo_label.modulate = Color(1, 1, 1, 0)
	
	# Tween анимация
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Появление (fade in + scale up)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.2)
	
	# Удержание
	tween.chain()
	tween.tween_interval(0.8)
	
	# Исчезновение (fade out + scale down)
	tween.set_parallel(true)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(combo_label, "position:y", 300, 0.3)

# Screen Shake эффект
func screen_shake(strength: float):
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		# Если нет камеры, трясём весь узел Game
		var original_pos = position
		var shake_count = 10
		var shake_duration = 0.02
		
		for i in range(shake_count):
			var offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
			position = original_pos + offset
			await get_tree().create_timer(shake_duration).timeout
		
		position = original_pos
	else:
		# Если есть камера, трясём её
		var original_offset = camera.offset
		var shake_count = 10
		var shake_duration = 0.02
		
		for i in range(shake_count):
			var offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
			camera.offset = original_offset + offset
			await get_tree().create_timer(shake_duration).timeout
		
		camera.offset = original_offset

# Создание частиц для комбо
func spawn_combo_particles(color: Color):
	var particles = GPUParticles2D.new()
	particles.position = Vector2(450, 480)  # Центр экрана
	particles.amount = 50
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	
	# Процесс-материал для частиц
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 20.0
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 200.0
	process_material.initial_velocity_max = 400.0
	process_material.gravity = Vector3(0, 500, 0)
	process_material.scale_min = 4.0
	process_material.scale_max = 8.0
	process_material.color = color
	
	particles.process_material = process_material
	particles.emitting = true
	
	add_child(particles)
	
	# Удаляем частицы через 2 секунды
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

# Обновляется каждый кадр
func _process(delta):
	if not game_over:
		# Каждые 10 секунд сохраняем время
		game_timer += delta
		if game_timer >= 10.0:
			progression.add_play_time(10)
			game_timer = 0.0

# Обновляет индикатор новых предметов
func update_achievements_indicator():
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn == null:
		return
	
	var indicator = profile_btn.get_node_or_null("NewIndicator")
	if indicator:
		# Показываем если ЕСТЬ ЛЮБЫЕ новые предметы
		indicator.visible = progression.has_any_new_items()
		
		if indicator.visible:
			print("🔴 Индикатор: ВКЛ (есть новые предметы)")
		else:
			print("⚪ Индикатор: ВЫКЛ")

# Автоматически уменьшает размер имени в игровой кнопке
func adjust_name_text_size(label: Label, max_width: float):
	if label == null:
		print("❌ adjust_name_text_size: label == null")
		return
	
	var text_length = label.text.length()
	print("📏 Подгонка шрифта для: '", label.text, "' (", text_length, " символов)")
	
	# Формула: чем больше символов, тем меньше шрифт
	var font_size = 18  # Было 20, стало 18
	
	if text_length <= 6:
		font_size = 18  # Player (было 20)
	elif text_length <= 8:
		font_size = 15  # Playerok (было 17)
	elif text_length <= 10:
		font_size = 12  # Playerok12 (было 14)
	elif text_length <= 12:
		font_size = 10  # Playerok1234 (было 12)
	else:
		font_size = 8  # Очень длинные (было 10)
	
	print("  → Начальный размер: ", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	
	# Ждём обновления
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Получаем шрифт
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
		print("  → Используем fallback font")
	
	# Проверяем реальную ширину и уменьшаем если нужно
	var min_font_size = 8
	var iterations = 0
	
	while font_size > min_font_size and iterations < 20:
		var text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		print("  → Итерация ", iterations, ": размер ", font_size, "px, ширина ", text_width, "px / ", max_width, "px")
		
		if text_width <= max_width:
			print("  ✅ Влезает! Финальный размер: ", font_size, "px")
			break
		
		font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)
		await get_tree().process_frame
		iterations += 1
	
	if iterations >= 20:
		print("  ⚠️ Достигнут лимит итераций!")

func update_profile_name_display():
	var profile_btn = get_node_or_null("ProfileButton")
	if profile_btn == null:
		return
	
	var name_label = profile_btn.get_node_or_null("PlayerNameLabel")
	if name_label == null:
		print("❌ PlayerNameLabel не найден в ProfileButton")
		return
	
	name_label.text = progression.player_name
	print("🔄 Обновляем имя: '", progression.player_name, "'")
	
	# УМЕНЬШИ max_width с 90 до 75
	adjust_name_text_size(name_label, 75)  # Было 90, стало 75
