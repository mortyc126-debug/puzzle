extends Node

## Ежедневные задания (автозагрузка Missions).
## Каждый день — три задания: лёгкое, среднее и трудное. Набор выбирается по дате, поэтому
## не меняется при перезапуске игры. Прогресс засчитывается в конце партии (record_run),
## награды выдаются сразу и попадают в итоги партии.

signal mission_completed(text: String, coins: int, xp: int)
signal all_missions_completed(bonus_coins: int)

const SAVE_PATH = "user://missions.save"
const ALL_DONE_BONUS = 100

# Награда по сложности: 0 — лёгкое, 1 — среднее, 2 — трудное
const REWARD_COINS = [30, 60, 100]
const REWARD_XP = [60, 120, 200]

# Виды заданий. stat — что считаем, mode — "sum" (копится за день) или "best" (лучшее за партию).
# targets — цель для лёгкого, среднего и трудного варианта.
# zen — засчитывать ли партии спокойного режима (очки там не ограничены — не засчитываем).
# desc: {n} — цель, {word} — слово в нужной форме из forms (1, 2–4, 5+)
const POOL = [
	{"kind": "lines", "desc": "Очистите {n} {word}", "forms": ["линию", "линии", "линий"],
		"stat": "lines", "mode": "sum", "targets": [15, 30, 50], "zen": true},
	{"kind": "pieces", "desc": "Поставьте {n} {word}", "forms": ["фигуру", "фигуры", "фигур"],
		"stat": "pieces", "mode": "sum", "targets": [40, 80, 140], "zen": true},
	{"kind": "games", "desc": "Сыграйте {n} {word}", "forms": ["партию", "партии", "партий"],
		"stat": "games", "mode": "sum", "targets": [2, 3, 5], "zen": true},
	{"kind": "score", "desc": "Наберите {n} {word} за одну партию", "forms": ["очко", "очка", "очков"],
		"stat": "score", "mode": "best", "targets": [300, 700, 1500], "zen": false},
	{"kind": "streak", "desc": "Соберите серию ×{n}", "forms": ["", "", ""],
		"stat": "streak", "mode": "best", "targets": [2, 3, 5], "zen": true},
	{"kind": "combo", "desc": "Очистите {n} {word} одним ходом", "forms": ["линию", "линии", "линий"],
		"stat": "combo", "mode": "best", "targets": [2, 2, 3], "zen": true},
	{"kind": "clean", "desc": "Наберите {n} {word} без бонусов", "forms": ["очко", "очка", "очков"],
		"stat": "clean_score", "mode": "best", "targets": [200, 500, 900], "zen": false},
]

var date := ""
var missions: Array = []  # [{"kind", "difficulty", "target", "progress", "done"}]
var bonus_given := false

func _ready() -> void:
	load_state()
	ensure_today()

# Новый день — новые задания
func ensure_today() -> void:
	var today = Progression.get_current_date()
	if date == today and missions.size() == 3:
		return
	date = today
	bonus_given = false
	missions = []

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(today)
	var kinds = range(POOL.size())
	for difficulty in range(3):
		var pick = kinds[rng.randi() % kinds.size()]
		kinds.erase(pick)
		var def = POOL[pick]
		var scale = level_scale(Progression.current_level)
		missions.append({
			"kind": def["kind"],
			"difficulty": difficulty,
			"target": scaled_target(def, difficulty, scale),
			"coins": int(round(REWARD_COINS[difficulty] * reward_scale(scale) / 5.0)) * 5,
			"xp": int(round(REWARD_XP[difficulty] * reward_scale(scale) / 10.0)) * 10,
			"progress": 0,
			"done": false,
		})
	save_state()

# Задания растут вместе с игроком: на 1–5 уровне цели как есть, на 30-м — вдвое, к 60-му — втрое.
# Иначе сильный игрок закрывал все три в первой же партии дня (симуляция плейтеста).
static func level_scale(level: int) -> float:
	return 1.0 + clampf(level - 5, 0, 55) / 25.0

# Награда растёт вполовину медленнее сложности, но растёт — задание остаётся выгодным
static func reward_scale(scale: float) -> float:
	return 1.0 + (scale - 1.0) * 0.5

static func scaled_target(def: Dictionary, difficulty: int, scale: float) -> int:
	var base: int = def["targets"][difficulty]
	match def["stat"]:
		"games", "combo":
			return base  # число партий и линий за ход не масштабируем
		"streak":
			return base + int((scale - 1.0) * 1.5)  # +1 к серии примерно на каждые 20 уровней
	var value = base * scale
	var step = 50 if value >= 300 else (10 if value >= 60 else 5)
	return int(round(value / step)) * step

func get_definition(kind: String) -> Dictionary:
	for def in POOL:
		if def["kind"] == kind:
			return def
	return {}

func get_text(mission: Dictionary) -> String:
	var def = get_definition(mission["kind"])
	var n: int = mission["target"]
	return def["desc"].format({"n": n, "word": plural(n, def["forms"])})

# Форма слова для числа: 1 линию, 2 линии, 5 линий, 21 линию, 11 линий
static func plural(n: int, forms: Array) -> String:
	var mod100 = n % 100
	var mod10 = n % 10
	if mod100 >= 11 and mod100 <= 14:
		return forms[2]
	if mod10 == 1:
		return forms[0]
	if mod10 >= 2 and mod10 <= 4:
		return forms[1]
	return forms[2]

func get_reward_text(mission: Dictionary) -> String:
	return "+%d монет · +%d XP" % [mission_coins(mission), mission_xp(mission)]

# Награда хранится в задании (с учётом уровня); у старых сохранений — по сложности
func mission_coins(mission: Dictionary) -> int:
	return int(mission.get("coins", REWARD_COINS[mission["difficulty"]]))

func mission_xp(mission: Dictionary) -> int:
	return int(mission.get("xp", REWARD_XP[mission["difficulty"]]))

func count_done() -> int:
	var done = 0
	for mission in missions:
		if mission["done"]:
			done += 1
	return done

func has_unfinished() -> bool:
	ensure_today()
	return count_done() < missions.size()

# Засчитать партию. run: {"lines", "pieces", "score", "streak", "combo", "used_powerups", "zen"}
func record_run(run: Dictionary) -> void:
	ensure_today()
	var values = {
		"lines": run.get("lines", 0),
		"pieces": run.get("pieces", 0),
		"games": 1,
		"score": run.get("score", 0),
		"streak": run.get("streak", 0),
		"combo": run.get("combo", 0),
		"clean_score": 0 if run.get("used_powerups", true) else run.get("score", 0),
	}
	var zen = run.get("zen", false)

	for mission in missions:
		if mission["done"]:
			continue
		var def = get_definition(mission["kind"])
		if zen and not def.get("zen", true):
			continue
		var value = int(values.get(def["stat"], 0))
		if def["mode"] == "sum":
			mission["progress"] = mini(mission["progress"] + value, mission["target"])
		else:
			mission["progress"] = mini(maxi(mission["progress"], value), mission["target"])
		if mission["progress"] >= mission["target"]:
			mission["done"] = true
			_reward(mission)

	if count_done() == missions.size() and not bonus_given:
		bonus_given = true
		Progression.record_full_day()
		Progression.add_coins(ALL_DONE_BONUS)
		Progression.record_coins_earned(ALL_DONE_BONUS)
		all_missions_completed.emit(ALL_DONE_BONUS)
	save_state()

func _reward(mission: Dictionary) -> void:
	var coins = mission_coins(mission)
	var xp = mission_xp(mission)
	Progression.add_coins(coins)
	Progression.record_coins_earned(coins)
	Progression.gain_xp(xp)
	Progression.record_mission_done()
	mission_completed.emit(get_text(mission), coins, xp)

func save_state() -> void:
	SafeFile.save_var(SAVE_PATH, {"date": date, "missions": missions, "bonus_given": bonus_given})

func load_state() -> void:
	var data = SafeFile.load_dict(SAVE_PATH)
	date = data.get("date", "")
	missions = data.get("missions", [])
	bonus_given = data.get("bonus_given", false)
