extends Node

## Прогресс игрока (автозагрузка Progression): уровень, XP, монеты, статистика,
## открытые предметы, ежедневные награды. Живёт всё время работы игры, переживает рестарт сцены.

signal xp_gained(amount)
signal level_up(new_level)
signal coins_changed(new_amount)
signal reward_unlocked(reward_type, reward_data)
signal daily_reward_available
signal daily_reward_claimed(day, reward)
signal item_upgraded(item_type, item_id, tier)
signal title_unlocked(title_id)
signal name_style_changed

const SAVE_PATH = "user://progression.save"
const OLD_BEST_SCORE_PATH = "user://best_score.save"
const SAVE_VERSION = 3
const AUTOSAVE_DELAY_MS = 3000
const MAX_COLOR_SLOTS = 8
const MAX_LEVEL = 500
const STARTER_COINS = 50
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
var best_zen_score = 0       # Рекорд спокойного режима — отдельно: там нельзя проиграть
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
var multi_clears = 0        # Ходы, очистившие 2 и больше линий
var missions_done = 0       # Выполнено заданий дня
var full_days = 0           # Дни, когда выполнены все три задания
var zen_games = 0           # Партии в спокойном режиме
var coins_spent = 0         # Потрачено монет на покупки в профиле

# Улучшенные версии аватарок и рамок: {"frame:3": 1, "avatar:5": 2} — 1 сияющая, 2 золотая
var item_tiers = {}
# Титулы и оформление имени
var owned_titles: Array = []
var player_title := ""
var owned_name_colors: Array = ["white"]
var name_color := "white"
var name_glow_owned := false
var name_glow := false

# Индикаторы новых предметов
var has_new_items = {
	"achievements": false,
	"avatars": false,
	"frames": false,
	"themes": false,
	"effects": false,
	"colors": false,
	"skins": false,
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
var unlocked_skins = []
var player_avatar = 1
var player_frame = 1
var player_effect = 1  # Эффект очистки линий (ItemsDB.effects_data)
var player_skin = 0    # Кубики (ItemsDB.skins_data), 0 — как в теме
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
	ThemeManager.apply_skin(player_skin)

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

# Опыт, нужный для перехода с уровня level на следующий. Первые уровни короче:
# даже слабая первая партия должна принести уровень и награду (симуляция новичков).
const FIRST_LEVELS_XP = [60, 80, 100, 110]

func get_xp_for_level(level: int) -> int:
	if level >= 1 and level <= FIRST_LEVELS_XP.size():
		return FIRST_LEVELS_XP[level - 1]
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

# Строки наград уровня: для итогов партии и подсказки «следующая награда».
# skip_owned — не показывать предметы, которые уже открыты (куплены заранее)
func get_level_reward_lines(level: int, include_coins: bool = true, skip_owned: bool = false) -> Array:
	var lines = []
	if include_coins:
		lines.append("%d монет" % get_level_coins(level))
	if level in SLOT_LEVELS:
		lines.append("+1 слот для цветов")
	var rank = get_rank_unlocked_at(level)
	if rank != "":
		lines.append("Звание «%s»" % rank)
	for item in get_level_items(level):
		if skip_owned and is_unlocked(item["type"], item["id"]):
			continue
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
		var lines = get_level_reward_lines(level, false, true)
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

# Покупка за монеты: предметы, которые открываются уровнем, можно взять раньше.
# Предметы за достижения остаются наградой за достижения, мифические — только за уровень.
const PRICES = {"COMMON": 300, "UNCOMMON": 600, "RARE": 1200, "EPIC": 2500, "LEGENDARY": 5000}
const COLOR_PRICE = 200
const THEME_PRICE_FACTOR = 1.5

func get_item_unlock(item_type: String, item_id) -> Dictionary:
	match item_type:
		"avatar":
			return ItemsDB.get_avatar_data(int(item_id)).get("unlock", {})
		"frame":
			return ItemsDB.get_frame_data(int(item_id)).get("unlock", {})
		"effect":
			return ItemsDB.get_effect_data(int(item_id)).get("unlock", {})
		"skin":
			return ItemsDB.get_skin_data(int(item_id)).get("unlock", {})
		"theme":
			var theme = ThemeManager.get_theme_by_id(str(item_id))
			return theme.unlock if theme else {}
		"color":
			return ItemsDB.get_color_unlock(int(item_id))
	return {}

func get_item_rarity(item_type: String, item_id) -> String:
	match item_type:
		"avatar":
			return ItemsDB.get_avatar_data(int(item_id)).get("rarity", "COMMON")
		"frame":
			return ItemsDB.get_frame_data(int(item_id)).get("rarity", "COMMON")
		"effect":
			return ItemsDB.get_effect_data(int(item_id)).get("rarity", "COMMON")
		"skin":
			return ItemsDB.get_skin_data(int(item_id)).get("rarity", "COMMON")
		"theme":
			var theme = ThemeManager.get_theme_by_id(str(item_id))
			return theme.rarity if theme else "COMMON"
	return "COMMON"

# Цена в монетах; 0 — купить нельзя (уже открыт, открывается не уровнем или мифический)
func get_price(item_type: String, item_id) -> int:
	if is_unlocked(item_type, item_id) or get_item_unlock(item_type, item_id).get("type", "") != "level":
		return 0
	if item_type == "color":
		return COLOR_PRICE
	var rarity = get_item_rarity(item_type, item_id)
	if not PRICES.has(rarity):
		return 0
	var price: int = PRICES[rarity]
	if item_type == "theme":
		price = int(price * THEME_PRICE_FACTOR)
	return price

func buy_item(item_type: String, item_id) -> bool:
	var price = get_price(item_type, item_id)
	if price <= 0 or not spend_coins(price):
		return false
	unlock_item(item_type, item_id)
	coins_spent += price
	_next_special_level = -1  # купленный предмет больше не «следующая награда»
	save_progress()
	return true

# Самый ценный предмет, на который уже хватает монет: {"type", "id", "price"} или {}.
# Когда новых предметов по карману нет — самое ценное улучшение ({"upgrade": ступень}).
func best_affordable_item() -> Dictionary:
	var best = {}
	for item in get_all_items():
		var price = get_price(item["type"], item["id"])
		if price > 0 and price <= total_coins and price > int(best.get("price", 0)):
			best = {"type": item["type"], "id": item["id"], "price": price}
	if not best.is_empty():
		return best
	for item_type in UPGRADABLE:
		var ids = ItemsDB.get_avatar_ids() if item_type == "avatar" else ItemsDB.get_frame_ids()
		for item_id in ids:
			var price = get_upgrade_price(item_type, item_id)
			if price > 0 and price <= total_coins and price > int(best.get("price", 0)):
				best = {"type": item_type, "id": item_id, "price": price, "upgrade": get_item_tier(item_type, item_id) + 1}
	return best

# Покупает то, что вернул best_affordable_item (предмет или улучшение)
func buy_offer(offer: Dictionary) -> bool:
	if offer.has("upgrade"):
		return upgrade_item(offer["type"], offer["id"])
	return buy_item(offer["type"], offer["id"])

func get_offer_label(offer: Dictionary) -> String:
	if offer.has("upgrade"):
		return get_upgraded_label(offer["type"], offer["id"], int(offer["upgrade"]))
	return get_item_label(offer["type"], offer["id"])

# === УЛУЧШЕННЫЕ ВЕРСИИ: СИЯЮЩАЯ И ЗОЛОТАЯ ===
# Открытую аватарку или рамку можно улучшить: блик (×2 цены редкости), потом золото с искрами (×4).
# Новых картинок не нужно — эффект рисует шейдер ui/item_shine.gdshader.

const UPGRADABLE = ["avatar", "frame"]
const UPGRADE_BASE = {"COMMON": 300, "UNCOMMON": 600, "RARE": 1200, "EPIC": 2500, "LEGENDARY": 5000, "MYTHIC": 8000}
const UPGRADE_MULTIPLIERS = [2, 4]
const TIER_NAMES = ["", "Сияющая", "Золотая"]

func get_item_tier(item_type: String, item_id) -> int:
	return int(item_tiers.get("%s:%d" % [item_type, int(item_id)], 0))

func get_upgrade_price(item_type: String, item_id) -> int:
	if not item_type in UPGRADABLE or not is_unlocked(item_type, item_id):
		return 0
	var tier = get_item_tier(item_type, item_id)
	if tier >= UPGRADE_MULTIPLIERS.size():
		return 0
	var base = int(UPGRADE_BASE.get(get_item_rarity(item_type, item_id), 300))
	return base * UPGRADE_MULTIPLIERS[tier]

func upgrade_item(item_type: String, item_id) -> bool:
	var price = get_upgrade_price(item_type, item_id)
	if price <= 0 or not spend_coins(price):
		return false
	var tier = get_item_tier(item_type, item_id) + 1
	item_tiers["%s:%d" % [item_type, int(item_id)]] = tier
	coins_spent += price
	save_progress()
	item_upgraded.emit(item_type, item_id, tier)
	return true

# «Золотая рамка «Магма»»
func get_upgraded_label(item_type: String, item_id, tier: int) -> String:
	var noun = "аватарка" if item_type == "avatar" else "рамка"
	var data = ItemsDB.get_avatar_data(int(item_id)) if item_type == "avatar" else ItemsDB.get_frame_data(int(item_id))
	return "%s %s «%s»" % [TIER_NAMES[clampi(tier, 0, 2)], noun, data.get("name", "?")]

# === ТИТУЛЫ И ОФОРМЛЕНИЕ ИМЕНИ ===
# Подпись под именем: заслуженные приходят сами (по статистике), остальные покупаются.
# Видны в профиле и рядом с аватаркой на экране игры. Только текст — расширять можно бесконечно.

const TITLES = [
	{"id": "challenge_1", "name": "Испытатель", "stat": "challenge_days", "value": 1},
	{"id": "challenge_7", "name": "Неделя испытаний", "stat": "challenge_days", "value": 7},
	{"id": "challenge_30", "name": "Месяц испытаний", "stat": "challenge_days", "value": 30},
	{"id": "challenge_100", "name": "Сто испытаний", "stat": "challenge_days", "value": 100},
	{"id": "streak_10", "name": "Неудержимый", "stat": "max_streak", "value": 10},
	{"id": "perfect_10", "name": "Чистое поле", "stat": "perfect_clears", "value": 10},
	{"id": "clean_3000", "name": "Без единого бонуса", "stat": "best_clean_score", "value": 3000},
	{"id": "score_10000", "name": "Пятизначный", "stat": "best_score", "value": 10000},
	{"id": "zen_50", "name": "Дзен-мастер", "stat": "zen_games", "value": 50},
	{"id": "games_500", "name": "Старожил", "stat": "games_played", "value": 500},
	{"id": "puzzler", "name": "Любитель головоломок", "price": 500},
	{"id": "quiet", "name": "Тихий гений", "price": 1000},
	{"id": "corners", "name": "Мастер углов", "price": 1500},
	{"id": "tamer", "name": "Укротитель фигур", "price": 2000},
	{"id": "collector", "name": "Собиратель линий", "price": 2500},
	{"id": "night", "name": "Ночной стратег", "price": 3500},
	{"id": "calm", "name": "Невозмутимый", "price": 5000},
	{"id": "void", "name": "Архитектор пустоты", "price": 7500},
	{"id": "storm", "name": "Гроза рекордов", "price": 10000},
	{"id": "lord", "name": "Лорд линий", "price": 15000},
	{"id": "emperor", "name": "Император блоков", "price": 25000},
	{"id": "living", "name": "Живая легенда", "price": 40000},
	{"id": "infinite", "name": "Бесконечность", "price": 60000},
]
const NAME_COLORS = [
	{"id": "white", "name": "Белый", "color": Color(1, 1, 1), "price": 0},
	{"id": "gold", "name": "Золотой", "color": Color(1, 0.82, 0.3), "price": 1500},
	{"id": "rose", "name": "Розовый", "color": Color(1, 0.62, 0.8), "price": 1500},
	{"id": "mint", "name": "Мятный", "color": Color(0.55, 1, 0.8), "price": 1500},
	{"id": "sky", "name": "Небесный", "color": Color(0.55, 0.82, 1), "price": 1500},
	{"id": "lavender", "name": "Лавандовый", "color": Color(0.8, 0.68, 1), "price": 2500},
	{"id": "fire", "name": "Огненный", "color": Color(1, 0.55, 0.25), "price": 3500},
	{"id": "ice", "name": "Ледяной", "color": Color(0.75, 0.97, 1), "price": 3500},
	{"id": "rainbow", "name": "Радужный", "color": Color(1, 1, 1), "price": 12000, "rainbow": true},
]
const NAME_GLOW_PRICE = 6000

func get_title_def(title_id: String) -> Dictionary:
	for def in TITLES:
		if def["id"] == title_id:
			return def
	return {}

func get_title_name(title_id: String) -> String:
	return get_title_def(title_id).get("name", "")

func has_title(title_id: String) -> bool:
	return owned_titles.has(title_id)

# Заслуженные титулы, условие которых уже выполнено. Возвращает новые id (и сообщает о каждом).
func check_titles() -> Array:
	var fresh = []
	for def in TITLES:
		if not def.has("stat") or owned_titles.has(def["id"]):
			continue
		if get_stat(def["stat"]) >= int(def["value"]):
			owned_titles.append(def["id"])
			fresh.append(def["id"])
	if not fresh.is_empty():
		request_save()
		for title_id in fresh:
			title_unlocked.emit(title_id)
	return fresh

func buy_title(title_id: String) -> bool:
	var def = get_title_def(title_id)
	if def.is_empty() or not def.has("price") or owned_titles.has(title_id):
		return false
	if not spend_coins(int(def["price"])):
		return false
	owned_titles.append(title_id)
	coins_spent += int(def["price"])
	player_title = title_id
	save_progress()
	name_style_changed.emit()
	return true

func set_title(title_id: String) -> void:
	if title_id == "" or owned_titles.has(title_id):
		player_title = title_id
		request_save()
		name_style_changed.emit()

func get_name_color_def(color_id: String) -> Dictionary:
	for def in NAME_COLORS:
		if def["id"] == color_id:
			return def
	return NAME_COLORS[0]

func buy_name_color(color_id: String) -> bool:
	var def = get_name_color_def(color_id)
	if def["id"] != color_id or owned_name_colors.has(color_id) or not spend_coins(int(def["price"])):
		return false
	owned_name_colors.append(color_id)
	coins_spent += int(def["price"])
	name_color = color_id
	save_progress()
	name_style_changed.emit()
	return true

func set_name_color(color_id: String) -> void:
	if owned_name_colors.has(color_id):
		name_color = color_id
		request_save()
		name_style_changed.emit()

func buy_name_glow() -> bool:
	if name_glow_owned or not spend_coins(NAME_GLOW_PRICE):
		return false
	name_glow_owned = true
	name_glow = true
	coins_spent += NAME_GLOW_PRICE
	save_progress()
	name_style_changed.emit()
	return true

func set_name_glow(enabled: bool) -> void:
	name_glow = enabled and name_glow_owned
	request_save()
	name_style_changed.emit()

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
		"skin":
			return unlocked_skins.has(int(item_id))
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
		"skin":
			unlocked_skins.append(int(item_id))
			category = "skins"
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
	for skin_id in ItemsDB.get_skin_ids():
		items.append({"type": "skin", "id": skin_id, "unlock": ItemsDB.get_skin_data(skin_id).get("unlock", {})})
	return items

# Сколько предметов собрано из всех: аватарки, рамки, темы, эффекты, цвета
func get_collection_progress() -> Dictionary:
	var total = ItemsDB.get_avatar_ids().size() + ItemsDB.get_frame_ids().size() + ThemeManager.themes.size() \
		+ ItemsDB.get_effect_ids().size() + ItemsDB.get_color_ids().size() + ItemsDB.get_skin_ids().size()
	var have = unlocked_avatars.size() + unlocked_frames.size() + unlocked_themes.size() \
		+ unlocked_effects.size() + unlocked_colors.size() + unlocked_skins.size()
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
	if player_skin != 0 and not is_unlocked("skin", player_skin):
		player_skin = 0
	# В слотах могут стоять только открытые цвета
	var allowed_colors = []
	for color_index in active_colors:
		if is_unlocked("color", color_index):
			allowed_colors.append(color_index)
	active_colors = allowed_colors if not allowed_colors.is_empty() else [0, 1, 2, 3]
	max_color_slots = maxi(max_color_slots, get_color_slots_for_level(current_level))

# Подпись предмета для наград: «Аватарка «Космонавт»». Без эмодзи: в шрифтах игры их нет,
# а поиск запасного системного шрифта замедлял длинные списки в 10 раз (замер в Godot)
func get_item_label(item_type: String, item_id) -> String:
	match item_type:
		"avatar":
			return "Аватарка «%s»" % ItemsDB.get_avatar_data(int(item_id)).get("name", "?")
		"frame":
			return "Рамка «%s»" % ItemsDB.get_frame_data(int(item_id)).get("name", "?")
		"theme":
			var theme = ThemeManager.get_theme_by_id(str(item_id))
			return "Тема «%s»" % (theme.display_name if theme else str(item_id))
		"effect":
			return "Эффект «%s»" % ItemsDB.get_effect_data(int(item_id)).get("name", "?")
		"skin":
			return "Кубики «%s»" % ItemsDB.get_skin_data(int(item_id)).get("name", "?")
		"color":
			return "Цвет «%s»" % ItemsDB.color_names[int(item_id)]
	return "Награда"

func select_skin(skin_id: int) -> bool:
	if skin_id != 0 and not is_unlocked("skin", skin_id):
		return false
	player_skin = skin_id
	ThemeManager.apply_skin(skin_id)
	request_save()
	return true

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
		"unlocked_skins": unlocked_skins,
		"player_skin": player_skin,
		"unlocked_colors": unlocked_colors,
		"player_effect": player_effect,
		"max_color_slots": max_color_slots,
		"active_colors": active_colors,
		"best_score": best_score,
		"best_zen_score": best_zen_score,
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
		"multi_clears": multi_clears,
		"missions_done": missions_done,
		"full_days": full_days,
		"zen_games": zen_games,
		"coins_spent": coins_spent,
		"item_tiers": item_tiers,
		"owned_titles": owned_titles,
		"player_title": player_title,
		"owned_name_colors": owned_name_colors,
		"name_color": name_color,
		"name_glow_owned": name_glow_owned,
		"name_glow": name_glow,
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
		# Первый запуск: подарок новичку, чтобы сразу попробовать бонусы
		total_coins = STARTER_COINS
		return

	var version = SafeFile.get_int(save_data, "save_version", 1)

	current_level = SafeFile.get_int(save_data, "current_level", 1, 0)
	current_xp = SafeFile.get_int(save_data, "current_xp", 0, 0)
	total_coins = SafeFile.get_int(save_data, "total_coins", 0, 0)
	daily_streak = SafeFile.get_int(save_data, "daily_streak", 0, 0)
	last_claim_date = SafeFile.get_str(save_data, "last_claim_date", "")
	can_claim_daily = SafeFile.get_bool(save_data, "can_claim_daily", true)
	player_avatar = SafeFile.get_int(save_data, "player_avatar", 1, 0)
	player_frame = SafeFile.get_int(save_data, "player_frame", 1, 0)
	player_name = SafeFile.get_str(save_data, "player_name", "Игрок")
	active_theme = SafeFile.get_str(save_data, "active_theme", "classic")
	unlocked_avatars = SafeFile.get_array(save_data, "unlocked_avatars", [])
	unlocked_frames = SafeFile.get_array(save_data, "unlocked_frames", [])
	unlocked_themes = SafeFile.get_array(save_data, "unlocked_themes", [])
	unlocked_music = SafeFile.get_array(save_data, "unlocked_music", [])
	unlocked_effects = SafeFile.get_array(save_data, "unlocked_effects", [])
	unlocked_skins = SafeFile.get_array(save_data, "unlocked_skins", [])
	player_skin = SafeFile.get_int(save_data, "player_skin", 0, 0)
	unlocked_colors = SafeFile.get_array(save_data, "unlocked_colors", [])
	player_effect = SafeFile.get_int(save_data, "player_effect", 1, 0)
	max_color_slots = SafeFile.get_int(save_data, "max_color_slots", 4, 0)
	active_colors = SafeFile.get_array(save_data, "active_colors", [0, 1, 2, 3])

	best_score = maxi(SafeFile.get_int(save_data, "best_score", 0, 0), old_best)
	total_games_played = SafeFile.get_int(save_data, "total_games_played", 0, 0)
	total_lines_cleared = SafeFile.get_int(save_data, "total_lines_cleared", 0, 0)
	total_time_played = SafeFile.get_int(save_data, "total_time_played", 0, 0)
	max_combo_achieved = SafeFile.get_int(save_data, "max_combo_achieved", 0, 0)
	total_score_sum = SafeFile.get_int(save_data, "total_score_sum", 0, 0)
	total_coins_earned = SafeFile.get_int(save_data, "total_coins_earned", 0, 0)
	total_pieces_placed = SafeFile.get_int(save_data, "total_pieces_placed", 0, 0)
	max_streak = SafeFile.get_int(save_data, "max_streak", 0, 0)
	perfect_clears = SafeFile.get_int(save_data, "perfect_clears", 0, 0)
	clutch_clears = SafeFile.get_int(save_data, "clutch_clears", 0, 0)
	best_clean_score = SafeFile.get_int(save_data, "best_clean_score", 0, 0)
	continues_used = SafeFile.get_int(save_data, "continues_used", 0, 0)
	powerups_used = SafeFile.get_int(save_data, "powerups_used", 0, 0)
	theme_games = SafeFile.get_dict(save_data, "theme_games", {})
	total_daily_claims = SafeFile.get_int(save_data, "total_daily_claims", 0, 0)
	best_run_lines = SafeFile.get_int(save_data, "best_run_lines", 0, 0)
	multi_clears = SafeFile.get_int(save_data, "multi_clears", 0, 0)
	missions_done = SafeFile.get_int(save_data, "missions_done", 0, 0)
	full_days = SafeFile.get_int(save_data, "full_days", 0, 0)
	zen_games = SafeFile.get_int(save_data, "zen_games", 0, 0)
	best_zen_score = SafeFile.get_int(save_data, "best_zen_score", 0, 0)
	coins_spent = SafeFile.get_int(save_data, "coins_spent", 0, 0)
	item_tiers = SafeFile.get_dict(save_data, "item_tiers", {})
	owned_titles = SafeFile.get_array(save_data, "owned_titles", [])
	player_title = SafeFile.get_str(save_data, "player_title", "")
	owned_name_colors = SafeFile.get_array(save_data, "owned_name_colors", ["white"])
	name_color = SafeFile.get_str(save_data, "name_color", "white")
	name_glow_owned = SafeFile.get_bool(save_data, "name_glow_owned", false)
	name_glow = SafeFile.get_bool(save_data, "name_glow", false) and name_glow_owned

	var saved_flags = SafeFile.get_dict(save_data, "has_new_items")
	for key in has_new_items.keys():
		has_new_items[key] = SafeFile.get_bool(saved_flags, key, false)

	current_level = clampi(current_level, 1, MAX_LEVEL)
	max_color_slots = clampi(max_color_slots, 1, MAX_COLOR_SLOTS)
	# В слотах цветов — только номера существующих цветов
	var colors_ok = []
	for color_index in active_colors:
		if (color_index is int or color_index is float) and int(color_index) >= 0 and int(color_index) < ItemsDB.block_colors.size():
			colors_ok.append(int(color_index))
	active_colors = colors_ok if not colors_ok.is_empty() else [0, 1, 2, 3]

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

# Только для тестов (tests/persona_bot.gd): «сегодня» сдвигается на N дней, чтобы прогнать
# несколько дней игры за минуту — задания, награда дня и испытание обновляются как в жизни
var debug_day_offset := 0

func get_current_date() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	if debug_day_offset != 0:
		var unix = Time.get_unix_time_from_datetime_dict(datetime) + debug_day_offset * 86400
		datetime = Time.get_datetime_dict_from_unix_time(unix)
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
		"best_zen_score":
			return best_zen_score
		"challenge_days":
			return Challenge.total_done
		"challenge_best_streak":
			return Challenge.best_streak
		"challenge_sundays":
			return Challenge.sundays_done
		"gold_items":
			var gold = 0
			for tier in item_tiers.values():
				if int(tier) >= 2:
					gold += 1
			return gold
		"titles_owned":
			return owned_titles.size()
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
		"multi_clears":
			return multi_clears
		"themes_unlocked":
			return unlocked_themes.size()
		"frames_unlocked":
			return unlocked_frames.size()
		"skins_unlocked":
			return unlocked_skins.size()
		"missions_done":
			return missions_done
		"full_days":
			return full_days
		"powerups_used":
			return powerups_used
		"continues_used":
			return continues_used
		"zen_games":
			return zen_games
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

func update_best_zen_score(score: int) -> bool:
	if score > best_zen_score:
		best_zen_score = score
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

func record_multi_clear():
	multi_clears += 1
	request_save()

func record_mission_done():
	missions_done += 1
	request_save()

func record_full_day():
	full_days += 1
	request_save()

func record_zen_game():
	zen_games += 1
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
