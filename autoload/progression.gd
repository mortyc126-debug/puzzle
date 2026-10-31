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
const SAVE_VERSION = 3
const AUTOSAVE_DELAY_MS = 3000
const MAX_COLOR_SLOTS = 8
const MAX_LEVEL = 500
const SLOT_LEVELS = [10, 20, 30, 40]  # +1 слот цветов (4 → 8)

# Звания: уровень, с которого действует, и название
const RANKS = [
	[1, "Новичок"], [5, "Ученик"], [10, "Укладчик"], [20, "Сборщик"], [30, "Строитель"],
	[40, "Инженер"], [50, "Архитектор"], [75, "Мастер блоков"], [100, "Знаток"], [125, "Эксперт"],
	[150, "Виртуоз"], [200, "Гроссмейстер"], [250, "Стратег"], [300, "Мудрец"], [350, "Титан"],
	[400, "Хранитель поля"], [450, "Повелитель линий"], [500, "Легенда"],
]

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
var total_daily_claims = 0  # Сколько раз забрана ежедневная награда
var best_run_lines = 0      # Больше всего линий за одну партию

# Индикаторы новых предметов
var has_new_items = {
	"achievements": false,
	"avatars": false,
	"frames": false,
	"themes": false,
	"effects": false,
	"colors": false,
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
var unlocked_effects = []
var unlocked_colors = []
var player_avatar = 1
var player_frame = 1
var player_effect = 1  # Эффект очистки линий (ItemsDB.effects_data)
var player_name = "Игрок"
var active_theme = "classic"

# Цвета блоков (тема «Классика»)
var max_color_slots = 4  # Растёт до 8 с уровнями
var active_colors = [0, 1, 2, 3]  # Индексы ItemsDB.block_colors

var _dirty := false
var _last_save_ms := 0
# Кэши: предметы по уровням (каталог не меняется во время игры) и ближайшая особая награда
# (её показывает шапка игры после каждой очистки линии)
var _level_items: Dictionary = {}
var _next_special_cache: Dictionary = {}
var _next_special_level := -1

func _ready() -> void:
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

# === УРОВНИ (1–500) ===
# Награда за уровень: монеты (больше на каждом 5-м и 25-м), слоты цветов, звания и предметы.
# Предметы за уровень описаны у самих предметов (ItemsDB, темы) через unlock {"type": "level"}.

# Опыт, нужный для перехода с уровня level на следующий
func get_xp_for_level(level: int) -> int:
	return 120 + 10 * (level - 1)

func get_xp_for_next_level() -> int:
	return get_xp_for_level(current_level)

func is_max_level() -> bool:
	return current_level >= MAX_LEVEL

func get_level_coins(level: int) -> int:
	var coins = 10 + 5 * (level / 25)
	if level % 5 == 0:
		coins *= 2
	if level % 25 == 0:
		coins += 100
	return coins

func get_rank_for_level(level: int) -> String:
	var rank = RANKS[0][1]
	for entry in RANKS:
		if level >= entry[0]:
			rank = entry[1]
	return rank

func get_rank() -> String:
	return get_rank_for_level(current_level)

# Новое звание, которое даёт именно этот уровень (или "")
func get_rank_unlocked_at(level: int) -> String:
	for entry in RANKS:
		if entry[0] == level and level > 1:
			return entry[1]
	return ""

# Строки наград уровня: для итогов партии и подсказки «следующая награда»
func get_level_reward_lines(level: int, include_coins: bool = true) -> Array:
	var lines = []
	if include_coins:
		lines.append("💰 %d монет" % get_level_coins(level))
	if level in SLOT_LEVELS:
		lines.append("🎨 +1 слот для цветов")
	var rank = get_rank_unlocked_at(level)
	if rank != "":
		lines.append("🏅 Звание «%s»" % rank)
	for item in get_level_items(level):
		lines.append(get_item_label(item["type"], item["id"]))
	return lines

# Предметы, которые открывает уровень. Раскладка по уровням строится один раз.
func get_level_items(level: int) -> Array:
	if _level_items.is_empty():
		_level_items[-1] = []  # метка «уже построено», даже если предметов за уровни нет
		for item in get_all_items():
			var unlock: Dictionary = item["unlock"]
			if unlock.get("type", "default") == "level":
				var unlock_level = int(unlock.get("level", 0))
				if not _level_items.has(unlock_level):
					_level_items[unlock_level] = []
				_level_items[unlock_level].append({"type": item["type"], "id": item["id"]})
	return _level_items.get(level, [])

# Ближайший уровень, где кроме монет есть что-то ещё: {"level": int, "lines": Array} или {}
func get_next_special_reward() -> Dictionary:
	if _next_special_level == current_level:
		return _next_special_cache
	_next_special_level = current_level
	_next_special_cache = {}
	for level in range(current_level + 1, MAX_LEVEL + 1):
		var lines = get_level_reward_lines(level, false)
		if not lines.is_empty():
			_next_special_cache = {"level": level, "lines": lines}
			break
	return _next_special_cache

func gain_xp(amount: int):
	if is_max_level():
		return
	current_xp += amount
	xp_gained.emit(amount)

	while not is_max_level() and current_xp >= get_xp_for_next_level():
		level_up_check()
	if is_max_level():
		current_xp = 0

	request_save()

func level_up_check():
	current_xp -= get_xp_for_next_level()
	current_level += 1
	level_up.emit(current_level)
	give_level_reward(current_level)
	save_progress()

func give_level_reward(level: int):
	var coins = get_level_coins(level)
	add_coins(coins)
	reward_unlocked.emit("coins", coins)

	if level in SLOT_LEVELS:
		max_color_slots = mini(MAX_COLOR_SLOTS, max_color_slots + 1)
		reward_unlocked.emit("slot", 1)

	var rank = get_rank_unlocked_at(level)
	if rank != "":
		reward_unlocked.emit("rank", rank)

	for item in get_level_items(level):
		if unlock_item(item["type"], item["id"]):
			reward_unlocked.emit(item["type"], item["id"])

# Сколько слотов цветов положено на этом уровне
func get_color_slots_for_level(level: int) -> int:
	var slots = 4
	for slot_level in SLOT_LEVELS:
		if level >= slot_level:
			slots += 1
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
		"effect":
			return unlocked_effects.has(int(item_id))
		"color":
			return unlocked_colors.has(int(item_id))
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
		"effect":
			unlocked_effects.append(int(item_id))
			category = "effects"
		"color":
			unlocked_colors.append(int(item_id))
			category = "colors"
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
	for item in get_all_items():
		if _unlock_matches(item["unlock"], unlock_type, key):
			result.append({"type": item["type"], "id": item["id"]})
	return result

# Весь каталог в порядке: аватарки, рамки, темы, эффекты, цвета — [{"type", "id", "unlock"}]
func get_all_items() -> Array:
	var items = []
	for avatar_id in ItemsDB.get_avatar_ids():
		items.append({"type": "avatar", "id": avatar_id, "unlock": ItemsDB.get_avatar_data(avatar_id).get("unlock", {})})
	for frame_id in ItemsDB.get_frame_ids():
		items.append({"type": "frame", "id": frame_id, "unlock": ItemsDB.get_frame_data(frame_id).get("unlock", {})})
	for theme in ThemeManager.themes:
		items.append({"type": "theme", "id": theme.id, "unlock": theme.unlock})
	for effect_id in ItemsDB.get_effect_ids():
		items.append({"type": "effect", "id": effect_id, "unlock": ItemsDB.get_effect_data(effect_id).get("unlock", {})})
	for color_index in ItemsDB.get_color_ids():
		items.append({"type": "color", "id": color_index, "unlock": ItemsDB.get_color_unlock(color_index)})
	return items

# Сколько предметов собрано из всех: аватарки, рамки, темы, эффекты, цвета
func get_collection_progress() -> Dictionary:
	var total = ItemsDB.get_avatar_ids().size() + ItemsDB.get_frame_ids().size() + ThemeManager.themes.size() \
		+ ItemsDB.get_effect_ids().size() + ItemsDB.get_color_ids().size()
	var have = unlocked_avatars.size() + unlocked_frames.size() + unlocked_themes.size() \
		+ unlocked_effects.size() + unlocked_colors.size()
	return {"have": mini(have, total), "total": total}

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
		for item in get_level_items(level):
			unlock_item(item["type"], item["id"])

	if not is_unlocked("avatar", player_avatar):
		var defaults = []
		for item in find_items("default"):
			if item["type"] == "avatar":
				defaults.append(item["id"])
		player_avatar = defaults[randi() % defaults.size()] if not defaults.is_empty() else 1
	if not is_unlocked("frame", player_frame):
		player_frame = 1
	if not is_unlocked("effect", player_effect):
		player_effect = 1
	# В слотах могут стоять только открытые цвета
	var allowed_colors = []
	for color_index in active_colors:
		if is_unlocked("color", color_index):
			allowed_colors.append(color_index)
	active_colors = allowed_colors if not allowed_colors.is_empty() else [0, 1, 2, 3]
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
		"effect":
			return "✨ Эффект «%s»" % ItemsDB.get_effect_data(int(item_id)).get("name", "?")
		"color":
			return "🎨 Цвет «%s»" % ItemsDB.color_names[int(item_id)]
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
		"unlocked_effects": unlocked_effects,
		"unlocked_colors": unlocked_colors,
		"player_effect": player_effect,
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
		"total_daily_claims": total_daily_claims,
		"best_run_lines": best_run_lines,
		"has_new_items": has_new_items,
	}

	SafeFile.save_var(SAVE_PATH, save_data)
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

	var save_data = SafeFile.load_dict(SAVE_PATH)
	if save_data.is_empty():
		best_score = old_best
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
	player_name = save_data.get("player_name", "Игрок")
	active_theme = save_data.get("active_theme", "classic")
	unlocked_avatars = save_data.get("unlocked_avatars", [])
	unlocked_frames = save_data.get("unlocked_frames", [])
	unlocked_themes = save_data.get("unlocked_themes", [])
	unlocked_music = save_data.get("unlocked_music", [])
	unlocked_effects = save_data.get("unlocked_effects", [])
	unlocked_colors = save_data.get("unlocked_colors", [])
	player_effect = save_data.get("player_effect", 1)
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
	total_daily_claims = save_data.get("total_daily_claims", 0)
	best_run_lines = save_data.get("best_run_lines", 0)

	var saved_flags = save_data.get("has_new_items", {})
	for key in has_new_items.keys():
		has_new_items[key] = saved_flags.get(key, false)

	current_level = mini(current_level, MAX_LEVEL)

	if version < 3:
		# Версия 2: все цвета были открыты — сохраняем те, что игрок уже выбрал
		for color_index in active_colors:
			if not unlocked_colors.has(int(color_index)):
				unlocked_colors.append(int(color_index))

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
	total_daily_claims += 1
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
		"daily_claims":
			return total_daily_claims
		"best_run_lines":
			return best_run_lines
		"avatars_unlocked":
			return unlocked_avatars.size()
		"themes_played":
			return theme_games.size()
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

func record_game_finished(final_score: int, used_powerups: bool = true, theme_id: String = "", run_lines: int = 0):
	total_games_played += 1
	total_score_sum += final_score
	best_run_lines = maxi(best_run_lines, run_lines)
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
	return "%d ч %d мин" % [hours, minutes]

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
