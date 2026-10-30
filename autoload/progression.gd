extends Node

## Прогресс игрока (автозагрузка Progression): уровень, XP, монеты, статистика,
## открытые предметы, ежедневные награды. Живёт всё время работы игры, переживает рестарт сцены.

signal xp_gained(amount)
signal level_up(new_level)
signal coins_changed(new_amount)
signal reward_unlocked(reward_type, reward_data)
signal daily_reward_available
signal daily_reward_claimed(day, reward)

const SAVE_PATH = "user://progression.save"
const OLD_BEST_SCORE_PATH = "user://best_score.save"
const SAVE_VERSION = 2
const AUTOSAVE_DELAY_MS = 3000
const MAX_COLOR_SLOTS = 8

# Мультипликатор наград текущей партии (растёт со счётом)
var score_multiplier = 1.0

# Daily Rewards
var last_claim_date = ""
var daily_streak = 0
var can_claim_daily = false

# Статистика
var best_score = 0
var total_games_played = 0
var total_lines_cleared = 0
var total_time_played = 0  # В секундах
var max_combo_achieved = 0  # Больше всего линий за один ход
var total_score_sum = 0
var total_coins_earned = 0
var total_pieces_placed = 0
var max_streak = 0          # Самая длинная серия очисток
var perfect_clears = 0      # Сколько раз поле очищено полностью
var clutch_clears = 0       # Очистки, когда поле было заполнено на 75% и больше
var best_clean_score = 0    # Лучший счёт без бонусов и продолжений
var continues_used = 0
var powerups_used = 0
var theme_games = {}        # {"space": 12, ...}

# Индикаторы новых предметов
var has_new_items = {
	"achievements": false,
	"avatars": false,
	"frames": false,
	"themes": false,
	"music": false,
	"daily": false
}

# Прогресс игрока
var current_level = 1
var current_xp = 0
var total_coins = 0

# Открытые предметы
var unlocked_avatars = []
var unlocked_frames = []
var unlocked_themes = []
var unlocked_music = []
var player_avatar = 1
var player_frame = 1
var player_name = "Player"
var active_theme = "classic"

# Цвета блоков (тема «Классика»)
var max_color_slots = 4  # Растёт до 8 с уровнями
var active_colors = [0, 1, 2, 3]  # Индексы ItemsDB.block_colors

# Награды Battle Pass за уровень (монеты и слоты). Предметы за уровень описаны в ItemsDB и темах.
var level_rewards = {}

var _dirty := false
var _last_save_ms := 0

func _ready() -> void:
	setup_battle_pass()
	load_progress()
	sync_unlocks()

	if is_unlocked("theme", active_theme):
		ThemeManager.apply_theme(active_theme)
	else:
		active_theme = "classic"

	check_daily_reward()

func _process(_delta: float) -> void:
	if _dirty and Time.get_ticks_msec() - _last_save_ms > AUTOSAVE_DELAY_MS:
		save_progress()

func _notification(what: int) -> void:
	# Телефон может выгрузить игру в любой момент — сохраняемся при сворачивании и закрытии
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _dirty:
			save_progress()

# === BATTLE PASS ===

func setup_battle_pass():
	level_rewards = {
		1: {"type": "coins", "amount": 10},
		2: {"type": "coins", "amount": 10},
		3: {"type": "coins", "amount": 15},
		4: {"type": "coins", "amount": 15},
		5: {"type": "coins", "amount": 20},
		6: {"type": "coins", "amount": 10},
		7: {"type": "coins", "amount": 20},
		8: {"type": "coins", "amount": 15},
		9: {"type": "coins", "amount": 15},
		10: {"type": "slot", "amount": 1},
	}

	# Уровни 11-300
	for i in range(11, 301):
		if i % 10 == 0:
			level_rewards[i] = {"type": "slot", "amount": 1}
		elif i % 5 == 0:
			level_rewards[i] = {"type": "coins", "amount": 25}
		else:
			level_rewards[i] = {"type": "coins", "amount": 10}

func get_reward_for_level(level: int):
	if level_rewards.has(level):
		return level_rewards[level]
	elif level > 300:
		# Бесконечные уровни — цикл монет
		var pattern = [5, 10, 5, 10, 15]
		var index = (level - 301) % 5
		return {"type": "coins", "amount": pattern[index]}
	return null

# Строки наград уровня для экрана Battle Pass
func get_level_reward_lines(level: int) -> Array:
	var lines = []
	var reward = get_reward_for_level(level)
	if reward != null:
		match reward["type"]:
			"coins":
				lines.append("💰 %d монет" % reward["amount"])
			"slot":
				if get_color_slots_for_level(level) > get_color_slots_for_level(level - 1):
					lines.append("⭐ +1 слот для цветов")
				else:
					lines.append("⭐ Слоты цветов: максимум")
	for item in find_items("level", level):
		lines.append(get_item_label(item["type"], item["id"]))
	return lines

func gain_xp(amount: int):
	current_xp += amount
	xp_gained.emit(amount)

	while current_xp >= get_xp_for_next_level():
		level_up_check()

	request_save()

func get_xp_for_next_level() -> int:
	if current_level <= 50:
		return 250
	elif current_level <= 150:
		return 375
	else:
		return 500

func level_up_check():
	current_xp -= get_xp_for_next_level()
	current_level += 1
	level_up.emit(current_level)
	give_level_reward(current_level)
	save_progress()

func give_level_reward(level: int):
	var reward = get_reward_for_level(level)
	if reward != null:
		match reward["type"]:
			"coins":
				add_coins(reward["amount"])
			"slot":
				max_color_slots = mini(MAX_COLOR_SLOTS, max_color_slots + reward["amount"])
		reward_unlocked.emit(reward["type"], reward.get("data", reward.get("amount")))

	for item in find_items("level", level):
		if unlock_item(item["type"], item["id"]):
			reward_unlocked.emit(item["type"], item["id"])

# Сколько слотов цветов положено на этом уровне (по наградам "slot")
func get_color_slots_for_level(level: int) -> int:
	var slots = 4
	for i in range(2, level + 1):
		var reward = get_reward_for_level(i)
		if reward != null and reward["type"] == "slot":
			slots += reward["amount"]
	return mini(MAX_COLOR_SLOTS, slots)

# === МОНЕТЫ ===

func add_coins(amount: int):
	total_coins += amount
	coins_changed.emit(total_coins)
	request_save()

func spend_coins(amount: int) -> bool:
	if total_coins >= amount:
		total_coins -= amount
		coins_changed.emit(total_coins)
		request_save()
		return true
	return false

# === ПРЕДМЕТЫ ===

func is_unlocked(item_type: String, item_id) -> bool:
	match item_type:
		"avatar":
			return unlocked_avatars.has(int(item_id))
		"frame":
			return unlocked_frames.has(int(item_id))
		"theme":
			return unlocked_themes.has(str(item_id))
	return false

# Открывает предмет. Возвращает true, если он открыт впервые.
func unlock_item(item_type: String, item_id, notify: bool = true) -> bool:
	if is_unlocked(item_type, item_id):
		return false

	var category = ""
	match item_type:
		"avatar":
			unlocked_avatars.append(int(item_id))
			category = "avatars"
		"frame":
			unlocked_frames.append(int(item_id))
			category = "frames"
		"theme":
			unlocked_themes.append(str(item_id))
			category = "themes"
		_:
			return false

	if notify:
		has_new_items[category] = true
		Events.item_unlocked.emit(item_type, item_id)
	request_save()
	return true

# Все предметы (аватарки, рамки, темы) с условием открытия заданного типа.
# key: номер уровня для "level", [id, tier] для "achievement", не нужен для "default".
func find_items(unlock_type: String, key = null) -> Array:
	var result = []
	for avatar_id in ItemsDB.get_avatar_ids():
		if _unlock_matches(ItemsDB.get_avatar_data(avatar_id).get("unlock", {}), unlock_type, key):
			result.append({"type": "avatar", "id": avatar_id})
	for frame_id in ItemsDB.get_frame_ids():
		if _unlock_matches(ItemsDB.get_frame_data(frame_id).get("unlock", {}), unlock_type, key):
			result.append({"type": "frame", "id": frame_id})
	for theme in ThemeManager.themes:
		if _unlock_matches(theme.unlock, unlock_type, key):
			result.append({"type": "theme", "id": theme.id})
	return result

func _unlock_matches(unlock: Dictionary, unlock_type: String, key) -> bool:
	if unlock.get("type", "default") != unlock_type:
		return false
	match unlock_type:
		"default":
			return true
		"level":
			return int(unlock.get("level", 0)) == int(key)
		"achievement":
			return unlock.get("id", "") == key[0] and int(unlock.get("tier", 0)) == int(key[1])
	return false

# Выдаёт предметы за ступень достижения (вызывает Achievements)
func grant_achievement_items(achievement_id: String, tier: int, notify: bool = true) -> Array:
	var granted = []
	for item in find_items("achievement", [achievement_id, tier]):
		if unlock_item(item["type"], item["id"], notify):
			granted.append(item)
	return granted

# Открывает всё, что положено по уже достигнутому уровню, и чинит выбор игрока
func sync_unlocks() -> void:
	for item in find_items("default"):
		unlock_item(item["type"], item["id"], false)
	for level in range(2, current_level + 1):
		for item in find_items("level", level):
			unlock_item(item["type"], item["id"])

	if not is_unlocked("avatar", player_avatar):
		var defaults = []
		for item in find_items("default"):
			if item["type"] == "avatar":
				defaults.append(item["id"])
		player_avatar = defaults[randi() % defaults.size()] if not defaults.is_empty() else 1
	if not is_unlocked("frame", player_frame):
		player_frame = 1
	max_color_slots = maxi(max_color_slots, get_color_slots_for_level(current_level))

# Подпись предмета для наград: «👤 Аватарка «Космонавт»»
func get_item_label(item_type: String, item_id) -> String:
	match item_type:
		"avatar":
			return "👤 Аватарка «%s»" % ItemsDB.get_avatar_data(int(item_id)).get("name", "?")
		"frame":
			return "🖼️ Рамка «%s»" % ItemsDB.get_frame_data(int(item_id)).get("name", "?")
		"theme":
			var theme = ThemeManager.get_theme_by_id(str(item_id))
			return "🌌 Тема «%s»" % (theme.display_name if theme else str(item_id))
	return "🎁 Награда"

func select_theme(theme_id: String) -> bool:
	if not is_unlocked("theme", theme_id):
		return false
	active_theme = theme_id
	ThemeManager.apply_theme(theme_id)
	request_save()
	return true

# === СОХРАНЕНИЕ ===

# Отложенное сохранение: частые события (ход, линия) не пишут файл каждый раз
func request_save() -> void:
	_dirty = true

func save_progress():
	var save_data = {
		"save_version": SAVE_VERSION,
		"current_level": current_level,
		"current_xp": current_xp,
		"total_coins": total_coins,
		"daily_streak": daily_streak,
		"last_claim_date": last_claim_date,
		"can_claim_daily": can_claim_daily,
		"player_avatar": player_avatar,
		"player_frame": player_frame,
		"player_name": player_name,
		"active_theme": active_theme,
		"unlocked_avatars": unlocked_avatars,
		"unlocked_frames": unlocked_frames,
		"unlocked_themes": unlocked_themes,
		"unlocked_music": unlocked_music,
		"max_color_slots": max_color_slots,
		"active_colors": active_colors,
		"best_score": best_score,
		"total_games_played": total_games_played,
		"total_lines_cleared": total_lines_cleared,
		"total_time_played": total_time_played,
		"max_combo_achieved": max_combo_achieved,
		"total_score_sum": total_score_sum,
		"total_coins_earned": total_coins_earned,
		"total_pieces_placed": total_pieces_placed,
		"max_streak": max_streak,
		"perfect_clears": perfect_clears,
		"clutch_clears": clutch_clears,
		"best_clean_score": best_clean_score,
		"continues_used": continues_used,
		"powerups_used": powerups_used,
		"theme_games": theme_games,
		"has_new_items": has_new_items,
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
	_dirty = false
	_last_save_ms = Time.get_ticks_msec()

func load_progress():
	# Рекорд раньше хранился в отдельном файле
	var old_best = 0
	if FileAccess.file_exists(OLD_BEST_SCORE_PATH):
		var best_file = FileAccess.open(OLD_BEST_SCORE_PATH, FileAccess.READ)
		if best_file:
			var value = best_file.get_var()
			best_file.close()
			if value is int:
				old_best = value

	if not FileAccess.file_exists(SAVE_PATH):
		best_score = old_best
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var save_data = file.get_var()
	file.close()
	if not save_data is Dictionary:
		return

	var version = save_data.get("save_version", 1)

	current_level = save_data.get("current_level", 1)
	current_xp = save_data.get("current_xp", 0)
	total_coins = save_data.get("total_coins", 0)
	daily_streak = save_data.get("daily_streak", 0)
	last_claim_date = save_data.get("last_claim_date", "")
	can_claim_daily = save_data.get("can_claim_daily", true)
	player_avatar = save_data.get("player_avatar", 1)
	player_frame = save_data.get("player_frame", 1)
	player_name = save_data.get("player_name", "Player")
	active_theme = save_data.get("active_theme", "classic")
	unlocked_avatars = save_data.get("unlocked_avatars", [])
	unlocked_frames = save_data.get("unlocked_frames", [])
	unlocked_themes = save_data.get("unlocked_themes", [])
	unlocked_music = save_data.get("unlocked_music", [])
	max_color_slots = save_data.get("max_color_slots", 4)
	active_colors = save_data.get("active_colors", [0, 1, 2, 3])

	best_score = maxi(save_data.get("best_score", 0), old_best)
	total_games_played = save_data.get("total_games_played", 0)
	total_lines_cleared = save_data.get("total_lines_cleared", 0)
	total_time_played = save_data.get("total_time_played", 0)
	max_combo_achieved = save_data.get("max_combo_achieved", 0)
	total_score_sum = save_data.get("total_score_sum", 0)
	total_coins_earned = save_data.get("total_coins_earned", 0)
	total_pieces_placed = save_data.get("total_pieces_placed", 0)
	max_streak = save_data.get("max_streak", 0)
	perfect_clears = save_data.get("perfect_clears", 0)
	clutch_clears = save_data.get("clutch_clears", 0)
	best_clean_score = save_data.get("best_clean_score", 0)
	continues_used = save_data.get("continues_used", 0)
	powerups_used = save_data.get("powerups_used", 0)
	theme_games = save_data.get("theme_games", {})

	var saved_flags = save_data.get("has_new_items", {})
	for key in has_new_items.keys():
		has_new_items[key] = saved_flags.get(key, false)

	if version < 2:
		# Версия 1: старые аватарки удалены, открытия пересчитываются заново (sync_unlocks)
		unlocked_avatars = []
		unlocked_frames = [1]
		unlocked_themes = []

# === МУЛЬТИПЛИКАТОР ===

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

func reset_multiplier():
	score_multiplier = 1.0

# === DAILY REWARDS ===

func check_daily_reward():
	var current_date = get_current_date()

	if last_claim_date == "":
		can_claim_daily = true
		has_new_items["daily"] = true
		daily_reward_available.emit()
		return

	if last_claim_date == current_date:
		can_claim_daily = false
		return

	var days_passed = get_days_between(last_claim_date, current_date)

	if days_passed == 1:
		can_claim_daily = true
		has_new_items["daily"] = true
		daily_reward_available.emit()
	elif days_passed > 1:
		daily_streak = 0
		can_claim_daily = true
		has_new_items["daily"] = true
		daily_reward_available.emit()
	else:
		can_claim_daily = false

func claim_daily_reward() -> Dictionary:
	if not can_claim_daily:
		return {}

	daily_streak += 1
	if daily_streak > 7:
		daily_streak = 1

	var reward = get_daily_reward_for_day(daily_streak)

	if reward.has("coins"):
		add_coins(reward["coins"])
	if reward.has("xp"):
		gain_xp(reward["xp"])

	last_claim_date = get_current_date()
	can_claim_daily = false
	has_new_items["daily"] = false

	save_progress()

	daily_reward_claimed.emit(daily_streak, reward)
	return reward

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

func get_current_date() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]

func get_days_between(date1: String, date2: String) -> int:
	var parts1 = date1.split("-")
	var parts2 = date2.split("-")

	if parts1.size() != 3 or parts2.size() != 3:
		return 999

	var dict1 = {"year": int(parts1[0]), "month": int(parts1[1]), "day": int(parts1[2]),
		"hour": 0, "minute": 0, "second": 0}
	var dict2 = {"year": int(parts2[0]), "month": int(parts2[1]), "day": int(parts2[2]),
		"hour": 0, "minute": 0, "second": 0}

	var unix1 = Time.get_unix_time_from_datetime_dict(dict1)
	var unix2 = Time.get_unix_time_from_datetime_dict(dict2)
	return int((unix2 - unix1) / 86400.0)

# === СТАТИСТИКА ===

# Значение статистики по имени — так её читают достижения
func get_stat(stat_id: String) -> int:
	match stat_id:
		"games_played":
			return total_games_played
		"lines_cleared":
			return total_lines_cleared
		"best_score":
			return best_score
		"pieces_placed":
			return total_pieces_placed
		"max_streak":
			return max_streak
		"max_combo":
			return max_combo_achieved
		"perfect_clears":
			return perfect_clears
		"clutch_clears":
			return clutch_clears
		"best_clean_score":
			return best_clean_score
		"coins_earned":
			return total_coins_earned
		"time_played":
			return total_time_played
		"level":
			return current_level
	if stat_id.begins_with("theme_games:"):
		return int(theme_games.get(stat_id.trim_prefix("theme_games:"), 0))
	return 0

# Возвращает true, если это новый рекорд
func update_best_score(score: int) -> bool:
	if score > best_score:
		best_score = score
		request_save()
		return true
	return false

func record_game_finished(final_score: int, used_powerups: bool = true, theme_id: String = ""):
	total_games_played += 1
	total_score_sum += final_score
	if not used_powerups:
		best_clean_score = maxi(best_clean_score, final_score)
	if theme_id != "":
		theme_games[theme_id] = int(theme_games.get(theme_id, 0)) + 1
	save_progress()

func record_piece_placed():
	total_pieces_placed += 1
	request_save()

func record_lines_cleared(count: int):
	total_lines_cleared += count
	request_save()

func record_combo(combo_value: int):
	if combo_value > max_combo_achieved:
		max_combo_achieved = combo_value
		request_save()

func record_streak(streak_value: int):
	if streak_value > max_streak:
		max_streak = streak_value
		request_save()

func record_perfect_clear():
	perfect_clears += 1
	request_save()

func record_clutch_clear():
	clutch_clears += 1
	request_save()

func record_continue():
	continues_used += 1
	request_save()

func record_powerup():
	powerups_used += 1
	request_save()

func add_play_time(seconds: int):
	total_time_played += seconds
	request_save()

func record_coins_earned(amount: int):
	total_coins_earned += amount
	request_save()

func get_average_score() -> int:
	if total_games_played == 0:
		return 0
	return total_score_sum / total_games_played

func format_play_time() -> String:
	var hours = total_time_played / 3600
	var minutes = (total_time_played % 3600) / 60
	return "%dh %dm" % [hours, minutes]

# === ИНДИКАТОРЫ НОВОГО ===

func has_any_new_items() -> bool:
	for key in has_new_items.keys():
		if has_new_items[key]:
			return true
	return false

func mark_items_as_seen(category: String):
	if has_new_items.has(category) and has_new_items[category]:
		has_new_items[category] = false
		request_save()
