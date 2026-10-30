extends Node

# Сигналы для уведомлений
signal xp_gained(amount)
signal level_up(new_level)
signal coins_changed(new_amount)
signal reward_unlocked(reward_type, reward_data)

# Мультипликатор наград
var score_multiplier = 1.0  # Текущий множитель (растёт по мере игры)

# ДОБАВЬ ЭТИ ПЕРЕМЕННЫЕ:
var battle_pass_level = 1        # Уровень в Battle Pass (может отличаться от current_level)
var unlocked_rewards = []        # Список уже полученных наград
var last_daily_claim = 0         # Unix timestamp последнего получения награды

# Daily Rewards
var last_claim_date = ""
var daily_streak = 0
var can_claim_daily = false

signal daily_reward_available
signal daily_reward_claimed(day, reward)

# Статистика
var total_games_played = 0
var total_lines_cleared = 0
var total_time_played = 0  # В секундах
var max_combo_achieved = 0
var total_score_sum = 0  # Для среднего счёта
var total_coins_earned = 0       # Всего монет заработано за всё время

# ДОСТИЖЕНИЯ (ДОБАВЬ ЭТО)
var achievements = {}  # {"games_1": true, "lines_10": true, ...}
var achievement_progress = {
	"games": 0,      # Текущий уровень достижения
	"lines": 0,
	"score": 0,
	"combo": 0,
	"coins": 0,
	"time": 0,
	"level": 0
}

# ИНДИКАТОРЫ НОВЫХ ПРЕДМЕТОВ (ЗАМЕНИ старую переменную)
var has_new_items = {
	"achievements": false,  # Новые достижения
	"avatars": false,       # Новые аватарки
	"frames": false,        # Новые рамки
	"backgrounds": false,   # Новые фоны
	"music": false,         # Новая музыка
	"daily": false          # Доступна Daily Reward (опционально)
}

# Прогресс игрока
var current_level = 1
var current_xp = 0
var total_coins = 0

# Награды Battle Pass
var unlocked_colors = []  # Список разблокированных цветов
var unlocked_themes = []  # Список разблокированных тем
var unlocked_backgrounds = []
var unlocked_music = []
var unlocked_sounds = []

# Данные уровней Battle Pass
var level_rewards = {}

var player_avatar = 1
var player_frame = 1
var player_name = "Player"  # ДОБАВЬ ЭТО
var unlocked_avatars = []
var unlocked_frames = [1]

# ДОБАВЬ ЭТО:
# Цвета блоков
const MAX_COLOR_SLOTS = 8
var max_color_slots = 4  # Начальное количество слотов (растёт до 8)
var active_colors = [0, 1, 2, 3]  # Индексы активных цветов (изначально 4)

func _ready():
	setup_battle_pass()
	load_progress()
	
	# Проверяем доступность ежедневной награды
	check_daily_reward()

# Настройка наград Battle Pass
func setup_battle_pass():
	# Уровни 1-50
	level_rewards = {
		1: {"type": "coins", "amount": 10},
		2: {"type": "coins", "amount": 10},
		3: {"type": "color", "data": "orange"},
		4: {"type": "coins", "amount": 15},
		5: {"type": "music", "data": "chill"},
		6: {"type": "coins", "amount": 10},
		7: {"type": "coins", "amount": 20},
		8: {"type": "color", "data": "pink"},
		9: {"type": "coins", "amount": 15},
		10: {"type": "slot", "amount": 1},  # +1 слот
		# Добавим больше позже
	}
	
	# Генерируем уровни 11-300
	for i in range(11, 301):
		if i % 10 == 0:
			# Каждые 10 уровней — слот
			level_rewards[i] = {"type": "slot", "amount": 1}
		elif i % 5 == 0:
			# Каждые 5 уровней — больше монет
			level_rewards[i] = {"type": "coins", "amount": 25}
		else:
			# Обычные уровни — монеты
			level_rewards[i] = {"type": "coins", "amount": 10}
	
	# Уровни 301+ (бесконечность)
	# Будем генерировать на лету

# Получение XP
func gain_xp(amount: int):
	current_xp += amount
	xp_gained.emit(amount)
	
	# Проверяем повышение уровня
	while current_xp >= get_xp_for_next_level():
		level_up_check()
	
	# ДОБАВЬ СОХРАНЕНИЕ (если нет)
	save_progress()

# XP нужно для следующего уровня
func get_xp_for_next_level() -> int:
	if current_level <= 50:
		return 250  # Было 100, стало 250
	elif current_level <= 150:
		return 375  # Было 150, стало 375 (в 2.5 раза больше)
	else:
		return 500  # Было 200, стало 500 (в 2.5 раза больше)

# Проверка повышения уровня
func level_up_check():
	current_xp -= get_xp_for_next_level()
	current_level += 1
	level_up.emit(current_level)
	
	print("LEVEL UP! Новый уровень: ", current_level)
	
	# Выдаём награду за уровень
	give_level_reward(current_level)
	
	# ДОБАВЬ СОХРАНЕНИЕ (если нет)
	save_progress()

# Выдача награды за уровень
func give_level_reward(level: int):
	var reward = get_reward_for_level(level)
	
	if reward == null:
		return
	
	match reward["type"]:
		"coins":
			add_coins(reward["amount"])
			print("Награда: ", reward["amount"], " монет")
		
		"color":
			unlock_color(reward["data"])
			print("Разблокирован цвет: ", reward["data"])
		
		"slot":
			max_color_slots = min(MAX_COLOR_SLOTS, max_color_slots + reward["amount"])
			print("Разблокирован +1 слот! Теперь слотов: ", max_color_slots)
		
		"theme":
			unlock_theme(reward["data"])
			print("Разблокирована тема: ", reward["data"])
		
		"music":
			unlock_music(reward["data"])
			print("Разблокирована музыка: ", reward["data"])
		
		"background":
			unlock_background(reward["data"])
			print("Разблокирован фон: ", reward["data"])
	
	reward_unlocked.emit(reward["type"], reward.get("data", reward.get("amount")))

# Сколько слотов цветов положено на этом уровне (по наградам "slot")
func get_color_slots_for_level(level: int) -> int:
	var slots = 4
	for i in range(2, level + 1):
		var reward = get_reward_for_level(i)
		if reward != null and reward["type"] == "slot":
			slots += reward["amount"]
	return min(MAX_COLOR_SLOTS, slots)

# Получить награду для уровня
func get_reward_for_level(level: int):
	if level_rewards.has(level):
		return level_rewards[level]
	elif level > 300:
		# Бесконечные уровни — цикл монет
		var pattern = [5, 10, 5, 10, 15]
		var index = (level - 301) % 5
		return {"type": "coins", "amount": pattern[index]}
	else:
		return null

# Управление монетами
func add_coins(amount: int):
	total_coins += amount
	coins_changed.emit(total_coins)
	save_progress()

func spend_coins(amount: int) -> bool:
	if total_coins >= amount:
		total_coins -= amount
		coins_changed.emit(total_coins)
		save_progress()
		return true
	return false

# Разблокировка контента
func unlock_color(color_id: String):
	if not unlocked_colors.has(color_id):
		unlocked_colors.append(color_id)
		save_progress()

func unlock_theme(theme_id: String):
	if not unlocked_themes.has(theme_id):
		unlocked_themes.append(theme_id)
		save_progress()

func unlock_background(bg_id: String):
	if not unlocked_backgrounds.has(bg_id):
		unlocked_backgrounds.append(bg_id)
		save_progress()

func unlock_music(music_id: String):
	if not unlocked_music.has(music_id):
		unlocked_music.append(music_id)
		save_progress()

# Сохранение прогресса
func save_progress():
	var save_data = {
		"current_level": current_level,
		"current_xp": current_xp,
		"total_coins": total_coins,
		"battle_pass_level": battle_pass_level,
		"unlocked_rewards": unlocked_rewards,
		"daily_streak": daily_streak,
		"last_claim_date": last_claim_date,
		"last_daily_claim": last_daily_claim,
		"can_claim_daily": can_claim_daily,
		"player_avatar": player_avatar,
		"player_frame": player_frame,
		"unlocked_avatars": unlocked_avatars,
		"unlocked_frames": unlocked_frames,
		"max_color_slots": max_color_slots,
		"active_colors": active_colors,
		"player_name": player_name,
		"total_games_played": total_games_played,
		"total_lines_cleared": total_lines_cleared,
		"total_time_played": total_time_played,
		"max_combo_achieved": max_combo_achieved,
		"total_score_sum": total_score_sum,
		"total_coins_earned": total_coins_earned,
		"has_new_items": has_new_items,
		"achievements": achievements,
		"achievement_progress": achievement_progress
	}
	
	var file = FileAccess.open("user://progression.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Прогресс сохранён")

# Загрузка прогресса
func load_progress():
	if FileAccess.file_exists("user://progression.save"):
		var file = FileAccess.open("user://progression.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()
			
			current_level = save_data.get("current_level", 1)
			current_xp = save_data.get("current_xp", 0)
			total_coins = save_data.get("total_coins", 0)
			battle_pass_level = save_data.get("battle_pass_level", 1)
			unlocked_rewards = save_data.get("unlocked_rewards", [])
			daily_streak = save_data.get("daily_streak", 1)
			last_claim_date = save_data.get("last_claim_date", "")
			last_daily_claim = save_data.get("last_daily_claim", 0)
			can_claim_daily = save_data.get("can_claim_daily", true)
			player_avatar = save_data.get("player_avatar", 1)
			player_frame = save_data.get("player_frame", 1)
			unlocked_avatars = save_data.get("unlocked_avatars", [])
			unlocked_frames = save_data.get("unlocked_frames", [1])  # Только 1 рамка
			max_color_slots = save_data.get("max_color_slots", 4)
			# Раньше награда "slot" не увеличивала слоты — досчитываем по уровню
			max_color_slots = max(max_color_slots, get_color_slots_for_level(current_level))
			player_name = save_data.get("player_name", "Player")
			active_colors = save_data.get("active_colors", [0, 1, 2, 3])
			
			# === СТАТИСТИКА (ДОБАВЬ) ===
			total_games_played = save_data.get("total_games_played", 0)
			total_lines_cleared = save_data.get("total_lines_cleared", 0)
			total_time_played = save_data.get("total_time_played", 0)
			max_combo_achieved = save_data.get("max_combo_achieved", 1)
			total_score_sum = save_data.get("total_score_sum", 0)
			total_coins_earned = save_data.get("total_coins_earned", 0)
			
			# ДОЛЖНО БЫТЬ ЭТО:
			achievements = save_data.get("achievements", {})
			achievement_progress = save_data.get("achievement_progress", {
				"games": 0,
				"lines": 0,
				"score": 0,
				"combo": 0,
				"coins": 0,
				"time": 0,
				"level": 0
			})
			
			# ДОСТИЖЕНИЯ (ДОБАВЬ ЭТО)
			has_new_items = save_data.get("has_new_items", {
				"achievements": false,
				"avatars": false,
				"frames": false,
				"backgrounds": false,
				"music": false,
				"daily": false
			})
			
			print("Прогресс загружен: Уровень ", current_level)
	else:
		print("Файла сохранения нет, создаём новый профиль")
		# Случайная аватарка из доступных, рамка всегда 1 (бронза)
		var avatar_ids = ItemsDB.avatars_data.keys()
		if avatar_ids.size() > 0:
			player_avatar = avatar_ids[randi() % avatar_ids.size()]
		player_frame = 1

# Вычисляет мультипликатор на основе текущего счёта
func calculate_multiplier(current_score: int) -> float:
	if current_score < 200:
		return 1.0
	elif current_score < 800:
		return 1.5
	elif current_score < 1700:
		return 2.0
	elif current_score < 4200:
		return 2.5
	elif current_score < 8300:
		return 3.0
	elif current_score < 16700:
		return 4.0
	else:
		return 5.0

# Сбрасывает мультипликатор (при новой игре)
func reset_multiplier():
	score_multiplier = 1.0

# === DAILY REWARDS ===

# Проверяет, доступна ли ежедневная награда
func check_daily_reward():
	var current_date = get_current_date()
	
	if last_claim_date == "":
		can_claim_daily = true
		has_new_items["daily"] = true  # ДОБАВЬ
		daily_reward_available.emit()
		return
	
	if last_claim_date == current_date:
		can_claim_daily = false
		return
	
	var days_passed = get_days_between(last_claim_date, current_date)
	
	if days_passed == 1:
		can_claim_daily = true
		has_new_items["daily"] = true  # ДОБАВЬ
		daily_reward_available.emit()
	elif days_passed > 1:
		daily_streak = 0
		can_claim_daily = true
		has_new_items["daily"] = true  # ДОБАВЬ
		daily_reward_available.emit()
	else:
		can_claim_daily = false

# Получает ежедневную награду
func claim_daily_reward() -> Dictionary:
	if not can_claim_daily:
		return {}
	
	# Увеличиваем серию
	daily_streak += 1
	if daily_streak > 7:
		daily_streak = 1  # Цикл повторяется
	
	# Определяем награду для текущего дня
	var reward = get_daily_reward_for_day(daily_streak)
	
	# Выдаём награду
	if reward.has("coins"):
		add_coins(reward["coins"])
	if reward.has("xp"):
		gain_xp(reward["xp"])
	
	# Сохраняем дату получения
	last_claim_date = get_current_date()
	can_claim_daily = false
	
	# ДОБАВЬ:
	has_new_items["daily"] = false
	
	save_progress()
	
	daily_reward_claimed.emit(daily_streak, reward)
	print("🎁 Daily Reward день ", daily_streak, ": ", reward)
	
	return reward

# Получает награду для конкретного дня
func get_daily_reward_for_day(day: int) -> Dictionary:
	match day:
		1: return {"coins": 50}
		2: return {"coins": 75}
		3: return {"coins": 100}
		4: return {"coins": 125}
		5: return {"coins": 150}
		6: return {"coins": 200, "xp": 100}
		7: return {"coins": 300, "xp": 200}
		_: return {"coins": 50}

# Получает текущую дату в формате "YYYY-MM-DD"
func get_current_date() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]

# Вычисляет количество дней между двумя датами
func get_days_between(date1: String, date2: String) -> int:
	# Преобразуем строки в unix timestamp
	var parts1 = date1.split("-")
	var parts2 = date2.split("-")
	
	if parts1.size() != 3 or parts2.size() != 3:
		return 999  # Ошибка формата
	
	var dict1 = {
		"year": int(parts1[0]),
		"month": int(parts1[1]),
		"day": int(parts1[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	
	var dict2 = {
		"year": int(parts2[0]),
		"month": int(parts2[1]),
		"day": int(parts2[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	
	var unix1 = Time.get_unix_time_from_datetime_dict(dict1)
	var unix2 = Time.get_unix_time_from_datetime_dict(dict2)
	
	var diff_seconds = unix2 - unix1
	var diff_days = int(diff_seconds / 86400.0)  # 86400 секунд в дне
	
	return diff_days

# === СТАТИСТИКА ===

func record_game_finished(final_score: int):
	total_games_played += 1
	total_score_sum += final_score
	save_progress()
	check_achievements()
	print("📊 Игра записана. Всего игр: ", total_games_played)

func record_lines_cleared(count: int):
	total_lines_cleared += count
	save_progress()
	check_achievements()

func record_combo(combo_value: int):
	if combo_value > max_combo_achieved:
		max_combo_achieved = combo_value
		save_progress()
		check_achievements()
		print("🔥 Новый рекорд комбо: x", max_combo_achieved)

func add_play_time(seconds: int):
	total_time_played += seconds

func record_coins_earned(amount: int):
	total_coins_earned += amount
	# Не сохраняем каждый раз (слишком часто)

func get_average_score() -> int:
	if total_games_played == 0:
		return 0
	return total_score_sum / total_games_played

func format_play_time() -> String:
	var hours = total_time_played / 3600
	var minutes = (total_time_played % 3600) / 60
	return "%dh %dm" % [hours, minutes]

# === СИСТЕМА ДОСТИЖЕНИЙ ===

# Определяет требования для каждого уровня достижения
func get_achievement_requirement(category: String, level: int) -> int:
	match category:
		"games":
			return level * 20  # 20, 40, 60... 2000
		"lines":
			return level * 100  # 100, 200... 10,000
		"score":
			return level * 100  # 100, 200... 10,000
		"combo":
			return level + 1  # x2, x3, x4... x8 (макс 8 уровней)
		"coins":
			return level * 1000  # 1000, 2000... 100,000
		"time":
			return level * 600  # 600 сек (10 мин), 1200 (20 мин)... 60,000 (1000 часов)
		"level":
			return level * 10  # 10, 20, 30... 1000
	return 0

# Получает награду за уровень достижения
func get_achievement_reward(category: String, level: int) -> Dictionary:
	var reward = {
		"coins": level * 10,  # Базовая награда в монетах
		"items": []  # Уникальные предметы
	}
	
	# Уникальные награды на 50 и 100 уровнях
	if level == 50:
		match category:
			"games":
				reward["items"].append({"type": "avatar", "id": "veteran"})
			"lines":
				reward["items"].append({"type": "music", "id": "victory"})
			"score":
				reward["items"].append({"type": "frame", "id": "pro"})
			"combo":
				if level <= 6:  # Комбо только до 8 уровней
					reward["items"].append({"type": "avatar", "id": "combo_king"})
			"coins":
				reward["items"].append({"type": "avatar", "id": "rich"})
			"time":
				reward["items"].append({"type": "music", "id": "dedication"})
			"level":
				reward["items"].append({"type": "background", "id": "ascended"})
	
	elif level == 100:
		match category:
			"games":
				reward["items"].append({"type": "frame", "id": "legend"})
				reward["items"].append({"type": "background", "id": "champion"})
			"lines":
				reward["items"].append({"type": "avatar", "id": "line_master"})
			"score":
				reward["items"].append({"type": "background", "id": "elite"})
				reward["items"].append({"type": "music", "id": "epic"})
			"combo":
				if level <= 8:
					reward["items"].append({"type": "frame", "id": "godlike"})
			"coins":
				reward["items"].append({"type": "background", "id": "golden_palace"})
				reward["items"].append({"type": "frame", "id": "tycoon"})
			"time":
				reward["items"].append({"type": "avatar", "id": "hardcore"})
				reward["items"].append({"type": "frame", "id": "immortal"})
			"level":
				reward["items"].append({"type": "avatar", "id": "maxed"})
				reward["items"].append({"type": "frame", "id": "ultimate"})
				reward["items"].append({"type": "music", "id": "legendary"})
	
	return reward

# Проверяет и разблокирует достижения
func check_achievements():
	var stats = {
		"games": total_games_played,
		"lines": total_lines_cleared,
		"score": 0,  # Best score берём из game.gd
		"combo": max_combo_achieved,
		"coins": total_coins_earned,
		"time": total_time_played,
		"level": current_level
	}
	
	# Best score нужно получить из game.gd
	var game = get_node_or_null("/root/Game")
	if game:
		stats["score"] = game.best_score
	
	for category in stats.keys():
		var current_value = stats[category]
		var current_progress = achievement_progress.get(category, 0)
		
		# Определяем максимальный уровень для категории
		var max_level = 100
		if category == "combo":
			max_level = 8  # Комбо только до 8
		
		# Проверяем каждый уровень от текущего до максимального
		for level in range(current_progress + 1, max_level + 1):
			var requirement = get_achievement_requirement(category, level)
			
			if current_value >= requirement:
				# Достижение разблокировано!
				unlock_achievement(category, level)
			else:
				# Дальше проверять не нужно
				break

# Разблокирует достижение и выдаёт награды
func unlock_achievement(category: String, level: int):
	var achievement_id = "%s_%d" % [category, level]
	
	# Проверяем, не получено ли уже
	if achievements.has(achievement_id):
		return
	
	# Отмечаем как полученное
	achievements[achievement_id] = true
	achievement_progress[category] = level
	
	# Получаем награды
	var reward = get_achievement_reward(category, level)
	
	# Выдаём монеты
	if reward.has("coins"):
		add_coins(reward["coins"])
		print("🏆 Достижение разблокировано: ", achievement_id)
		print("💰 Получено монет: ", reward["coins"])
	
	# Выдаём уникальные предметы
	if reward.has("items"):
		for item in reward["items"]:
			unlock_achievement_item(item["type"], item["id"])
			print("🎁 Получен предмет: ", item["type"], " - ", item["id"])
	
	# Включаем индикатор новых достижений
	has_new_items["achievements"] = true
	
	save_progress()
	
	# Сохраняем прогресс
	save_progress()
	
	# Отправляем сигнал (для уведомлений)
	# TODO: добавить сигнал achievement_unlocked

# Получает прогресс достижения (для UI)
func get_achievement_progress_data(category: String) -> Dictionary:
	var achievement_level = achievement_progress.get(category, 0)
	var max_level = 100
	if category == "combo":
		max_level = 8
	
	var stats = {
		"games": total_games_played,
		"lines": total_lines_cleared,
		"score": 0,
		"combo": max_combo_achieved,
		"coins": total_coins_earned,
		"time": total_time_played,
		"level": current_level
	}
	
	var game = get_node_or_null("/root/Game")
	if game:
		stats["score"] = game.best_score
	
	var current_value = stats[category]
	var next_level = achievement_level + 1
	
	if next_level > max_level:
		# Все достижения в категории получены
		return {
			"current_level": achievement_level,
			"max_level": max_level,
			"current_value": current_value,
			"next_requirement": 0,
			"progress_percent": 100.0,
			"completed": true
		}
	
	var next_requirement = get_achievement_requirement(category, next_level)
	var progress_percent = 0.0
	
	if next_requirement > 0:
		progress_percent = min(100.0, (float(current_value) / float(next_requirement)) * 100.0)
	
	return {
		"current_level": achievement_level,
		"max_level": max_level,
		"current_value": current_value,
		"next_requirement": next_requirement,
		"progress_percent": progress_percent,
		"completed": false
	}

# Получает общий прогресс всех достижений (для UI)
func get_total_achievements_progress() -> Dictionary:
	var total = 0
	var unlocked = 0
	
	var categories = ["games", "lines", "score", "combo", "coins", "time", "level"]
	
	for category in categories:
		var max_level = 100
		if category == "combo":
			max_level = 8
		
		total += max_level
		unlocked += achievement_progress.get(category, 0)
	
	var percent = 0.0
	if total > 0:
		percent = (float(unlocked) / float(total)) * 100.0
	
	return {
		"unlocked": unlocked,
		"total": total,
		"percent": percent
	}

# === РАЗБЛОКИРОВКА ПРЕДМЕТОВ С ИНДИКАТОРАМИ ===

# Разблокирует уникальный предмет из достижения
func unlock_achievement_item(item_type: String, item_id: String):
	match item_type:
		"avatar":
			print("Разблокирована аватарка: ", item_id)
			has_new_items["avatars"] = true  # ДОБАВЬ
		"frame":
			print("Разблокирована рамка: ", item_id)
			has_new_items["frames"] = true  # ДОБАВЬ
		"background":
			print("Разблокирован фон: ", item_id)
			has_new_items["backgrounds"] = true  # ДОБАВЬ
		"music":
			print("Разблокирована музыка: ", item_id)
			has_new_items["music"] = true  # ДОБАВЬ
	
	save_progress()

# Проверяет есть ли ЛЮБЫЕ новые предметы
func has_any_new_items() -> bool:
	for key in has_new_items.keys():
		if has_new_items[key]:
			return true
	return false

# Снимает индикатор для конкретной категории
func mark_items_as_seen(category: String):
	if has_new_items.has(category):
		has_new_items[category] = false
		save_progress()
		print("✅ Индикатор снят для: ", category)
