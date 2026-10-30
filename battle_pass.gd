extends Control

var progression = null

func _ready():
	# Получаем ссылку на систему прогрессии
	progression = get_node("/root/Game/Progression")
	
	# Подключаем кнопку назад
	$BackButton.pressed.connect(_on_back_pressed)
	
	# Обновляем UI
	update_ui()
	populate_rewards()

func update_ui():
	if progression == null:
		return
	
	# Обновляем прогресс внизу
	var progress_text = "Level %d • %d / %d XP • 💰 %d" % [
		progression.current_level,
		progression.current_xp,
		progression.get_xp_for_next_level(),
		progression.total_coins
	]
	$ProgressLabel.text = progress_text

func populate_rewards():
	if progression == null:
		return
	
	# Очищаем старый список
	for child in $RewardsScroll/RewardsList.get_children():
		child.queue_free()
	
	# Генерируем элементы для первых 50 уровней
	for level in range(1, 51):
		create_reward_item(level)

func create_reward_item(level: int):
	var reward = progression.get_reward_for_level(level)
	if reward == null:
		return
	
	# Создаём контейнер для награды
	var item = HBoxContainer.new()
	item.custom_minimum_size = Vector2(760, 60)
	
	# Иконка уровня
	var level_label = Label.new()
	level_label.custom_minimum_size = Vector2(80, 60)
	level_label.text = str(level)
	level_label.add_theme_font_size_override("font_size", 32)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Проверяем, разблокирован ли уровень
	var is_unlocked = level <= progression.current_level
	
	if is_unlocked:
		level_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))  # Зелёный
	else:
		level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Серый
	
	item.add_child(level_label)
	
	# Описание награды
	var reward_label = Label.new()
	reward_label.custom_minimum_size = Vector2(500, 60)
	reward_label.text = get_reward_text(reward)
	reward_label.add_theme_font_size_override("font_size", 24)
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if is_unlocked:
		reward_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		reward_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	item.add_child(reward_label)
	
	# Статус (✓ или 🔒)
	var status_label = Label.new()
	status_label.custom_minimum_size = Vector2(80, 60)
	status_label.text = "✓" if is_unlocked else "🔒"
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_child(status_label)
	
	# Разделитель
	var separator = HSeparator.new()
	
	# Добавляем в список
	$RewardsScroll/RewardsList.add_child(item)
	$RewardsScroll/RewardsList.add_child(separator)

func get_reward_text(reward: Dictionary) -> String:
	match reward["type"]:
		"coins":
			return "💰 %d монет" % reward["amount"]
		"color":
			return "🎨 Цвет: %s" % reward["data"]
		"slot":
			return "⭐ +1 слот для цветов"
		"theme":
			return "🎨 Тема: %s" % reward["data"]
		"music":
			return "🎵 Музыка: %s" % reward["data"]
		"background":
			return "🖼️ Фон: %s" % reward["data"]
		_:
			return "🎁 Награда"

func _on_back_pressed():
	# Возвращаемся в игру
	queue_free()
