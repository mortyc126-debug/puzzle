extends Node

## Достижения (автозагрузка Achievements).
## Каждое достижение смотрит на одну статистику Progression.get_stat() и имеет ступени-пороги.
## Ступени многоступенчатых: Бронза → Серебро → Золото → Платина → Алмаз.
## Предметы за ступени описаны у самих предметов (ItemsDB, темы) через "unlock".
## Как добавить достижение — docs/CONTENT.md.

const SAVE_PATH = "user://achievements.save"

const TIER_NAMES = ["Бронза", "Серебро", "Золото", "Платина", "Алмаз"]
const TIER_COLORS = [
	Color(0.80, 0.50, 0.25),
	Color(0.75, 0.80, 0.88),
	Color(1.00, 0.80, 0.20),
	Color(0.55, 0.95, 0.90),
	Color(0.70, 0.60, 1.00),
]
const TIER_COINS = [20, 50, 100, 200, 500]

# format: "number" — число, "time" — секунды как часы и минуты.
# Ступеней от 1 до 5. Одна ступень — разовое испытание.
const LIST = [
	# Путь игрока
	{"id": "games", "icon": "🎮", "title": "Завсегдатай", "desc": "Сыграйте %s партий",
		"stat": "games_played", "tiers": [5, 25, 100, 250, 1000]},
	{"id": "level", "icon": "📈", "title": "Ветеран", "desc": "Достигните уровня %s",
		"stat": "level", "tiers": [10, 50, 100, 250, 500]},
	{"id": "time", "icon": "⏱️", "title": "Марафонец", "desc": "Проведите в игре %s",
		"stat": "time_played", "tiers": [1800, 10800, 36000, 90000, 360000], "format": "time"},
	{"id": "daily", "icon": "📅", "title": "Каждый день", "desc": "Заберите награду дня %s раз",
		"stat": "daily_claims", "tiers": [3, 7, 30, 100, 365]},
	{"id": "coins", "icon": "💰", "title": "Копилка", "desc": "Заработайте %s монет",
		"stat": "coins_earned", "tiers": [500, 2500, 10000, 50000, 200000]},
	{"id": "collector", "icon": "🗂️", "title": "Коллекционер", "desc": "Откройте %s аватарок",
		"stat": "avatars_unlocked", "tiers": [6, 10, 16]},

	# Поле и линии
	{"id": "lines", "icon": "⭐", "title": "Чистильщик", "desc": "Очистите %s линий",
		"stat": "lines_cleared", "tiers": [25, 250, 1000, 5000, 20000]},
	{"id": "pieces", "icon": "🧱", "title": "Строитель", "desc": "Поставьте %s фигур",
		"stat": "pieces_placed", "tiers": [100, 1000, 5000, 20000, 100000]},
	{"id": "run_lines", "icon": "🏃", "title": "Длинная дистанция", "desc": "Очистите %s линий за одну партию",
		"stat": "best_run_lines", "tiers": [20, 50, 100, 200]},
	{"id": "score", "icon": "🏆", "title": "Рекордсмен", "desc": "Наберите %s очков за партию",
		"stat": "best_score", "tiers": [500, 2000, 5000, 10000, 25000]},
	{"id": "streak", "icon": "🔥", "title": "Без остановки", "desc": "Серия очисток длиной %s",
		"stat": "max_streak", "tiers": [3, 5, 8, 12, 20]},
	{"id": "perfect", "icon": "✨", "title": "Чистое поле", "desc": "Очистите поле полностью %s раз",
		"stat": "perfect_clears", "tiers": [1, 5, 25, 100]},
	{"id": "clutch", "icon": "🛟", "title": "На краю", "desc": "Очистите линию при поле, заполненном на 75%%, %s раз",
		"stat": "clutch_clears", "tiers": [1, 10, 50, 200]},
	{"id": "clean", "icon": "🎯", "title": "Без подсказок", "desc": "Наберите %s очков без бонусов и продолжений",
		"stat": "best_clean_score", "tiers": [1000, 3000, 6000]},
	{"id": "space_games", "icon": "🚀", "title": "Звёздный путь", "desc": "Сыграйте %s партий в теме «Космос»",
		"stat": "theme_games:space", "tiers": [10, 50, 200]},
	{"id": "traveler", "icon": "🗺️", "title": "Путешественник", "desc": "Сыграйте хотя бы партию в %s разных темах",
		"stat": "themes_played", "tiers": [2, 4, 6]},

	# Разовые испытания
	{"id": "double", "icon": "✌️", "title": "Дубль", "desc": "Очистите 2 линии одним ходом",
		"stat": "max_combo", "tiers": [2]},
	# Пять линий одним ходом фигурами до 4 клеток почти не собрать (только палка 1×4 —
	# ряд и четыре столбца сразу), поэтому вершина испытаний — «Квадро», а между — «Трио».
	# Стресс-тест ботом: 3 линии хоть раз за партию — в ~9% партий, 4 линии — в ~0.3%.
	{"id": "triple", "icon": "🎲", "title": "Трио", "desc": "Очистите 3 линии одним ходом",
		"stat": "max_combo", "tiers": [3]},
	{"id": "quad", "icon": "💥", "title": "Квадро", "desc": "Очистите 4 линии одним ходом",
		"stat": "max_combo", "tiers": [4]},
]

var progress = {}  # id -> сколько ступеней получено

func _ready() -> void:
	load_progress()
	# Предметы за уже полученные ступени (на случай, если предмет добавили позже)
	for def in LIST:
		for tier in range(1, get_tier(def["id"]) + 1):
			Progression.grant_achievement_items(def["id"], tier)

	# Достижения засчитываются в конце партии, а не посреди неё
	Events.game_finished.connect(func(_score, _used): check_all())
	Progression.daily_reward_claimed.connect(func(_day, _reward): check_all())
	check_all()

func get_definition(achievement_id: String) -> Dictionary:
	for def in LIST:
		if def["id"] == achievement_id:
			return def
	return {}

func get_title(achievement_id: String) -> String:
	return get_definition(achievement_id).get("title", achievement_id)

func get_tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier - 1, 0, TIER_NAMES.size() - 1)]

func get_tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier - 1, 0, TIER_COLORS.size() - 1)]

func get_tier(achievement_id: String) -> int:
	return int(progress.get(achievement_id, 0))

func get_tier_label(def: Dictionary, tier: int) -> String:
	if def["tiers"].size() == 1:
		return "Выполнено"
	return get_tier_name(tier)

func format_value(def: Dictionary, value: int) -> String:
	if def.get("format", "number") == "time":
		var hours = value / 3600
		var minutes = (value % 3600) / 60
		if hours > 0:
			return "%d ч %d мин" % [hours, minutes] if minutes > 0 else "%d ч" % hours
		return "%d мин" % minutes
	return str(value)

func get_description(def: Dictionary, tier: int) -> String:
	var tiers: Array = def["tiers"]
	var target = tiers[clampi(tier - 1, 0, tiers.size() - 1)]
	var text: String = def["desc"]
	if text.contains("%s"):
		return text % format_value(def, target)
	return text

func get_reward_coins(def: Dictionary, tier: int) -> int:
	if def["tiers"].size() == 1:
		return 100  # разовые испытания
	return TIER_COINS[clampi(tier - 1, 0, TIER_COINS.size() - 1)]

# Данные для интерфейса
func get_info(def: Dictionary) -> Dictionary:
	var tiers: Array = def["tiers"]
	var tier = get_tier(def["id"])
	var value = Progression.get_stat(def["stat"])
	var completed = tier >= tiers.size()
	var next_target = 0 if completed else tiers[tier]
	var prev_target = 0 if tier == 0 else tiers[tier - 1]
	var percent = 100.0
	if not completed:
		var span = maxf(float(next_target - prev_target), 1.0)
		percent = clampf(float(value - prev_target) / span * 100.0, 0.0, 100.0)
	return {
		"tier": tier,
		"max_tier": tiers.size(),
		"value": value,
		"next_target": next_target,
		"percent": percent,
		"completed": completed,
	}

func get_total_progress() -> Dictionary:
	var total = 0
	var unlocked = 0
	for def in LIST:
		total += def["tiers"].size()
		unlocked += mini(get_tier(def["id"]), def["tiers"].size())
	var percent = (float(unlocked) / float(total) * 100.0) if total > 0 else 0.0
	return {"unlocked": unlocked, "total": total, "percent": percent}

func check_all() -> void:
	# Награды одних достижений (монеты, аватарки, уровни) могут выполнить другие —
	# поэтому проходим список, пока что-то меняется
	var changed_any = false
	for pass_index in range(4):
		var changed = false
		for def in LIST:
			var tiers: Array = def["tiers"]
			var value = Progression.get_stat(def["stat"])
			var tier = get_tier(def["id"])
			while tier < tiers.size() and value >= tiers[tier]:
				tier += 1
				_unlock(def, tier)
				changed = true
		if not changed:
			break
		changed_any = true
	if changed_any:
		save_progress()

func _unlock(def: Dictionary, tier: int) -> void:
	progress[def["id"]] = tier
	var coins = get_reward_coins(def, tier)
	Progression.add_coins(coins)
	Progression.record_coins_earned(coins)
	Progression.grant_achievement_items(def["id"], tier)
	Progression.has_new_items["achievements"] = true
	Progression.request_save()
	Events.achievement_unlocked.emit(def["id"], tier)

func save_progress() -> void:
	SafeFile.save_var(SAVE_PATH, progress)

func load_progress() -> void:
	progress = SafeFile.load_dict(SAVE_PATH)
