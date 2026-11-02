extends Node

## Испытание дня (автозагрузка Challenge): задача на сегодня, попытки и цена повтора,
## пройденные дни и серия. Первая попытка бесплатна, каждая следующая — вдвое дороже
## (100 → 200 → 400 …): так монеты уходят на то, что зависит от мастерства, а не копятся.
## Задачу строит ChallengePuzzle — в фоновом потоке, раз в день; готовая хранится в сохранении,
## поэтому после перезапуска игры начатая попытка продолжается сразу.

signal puzzle_ready
signal state_changed

const SAVE_PATH = "user://challenge.save"
const RETRY_BASE_PRICE = 100
const RETRY_MAX_PRICE = 3200
# Опыт за пройденное испытание по дню недели: воскресное труднее — и щедрее
const XP_REWARD = [100, 110, 120, 140, 160, 180, 220]
# Титулы за пройденные дни (см. Progression.TITLES)
const MILESTONES = [1, 7, 30, 100]

var date := ""
var attempts := 0          # попыток сегодня
var done_today := false
var best_today := 0        # лучший результат сегодняшних попыток (для «почти»)
var total_done := 0        # дней с пройденным испытанием
var streak := 0            # дней подряд
var best_streak := 0
var last_done_date := ""
var active := false        # Game запускает испытание вместо обычной партии
var coins_spent := 0       # всего монет на повторы
var puzzle: Dictionary = {}

var _task_id := -1
var _built: Dictionary = {}

func _ready() -> void:
	set_process(false)
	load_state()
	ensure_today()

# Новый день: счётчики попыток сбрасываются, задача строится заново
func ensure_today() -> void:
	var today = Progression.get_current_date()
	if date != today:
		date = today
		attempts = 0
		done_today = false
		best_today = 0
		# Вчерашняя попытка, начатая до полуночи, сгорает: задача уже другая
		active = false
		save_state()
		state_changed.emit()
	if puzzle.get("date", "") != today and _task_id < 0:
		_task_id = WorkerThreadPool.add_task(_build.bind(today), false, "Испытание дня")
		set_process(true)

func _build(for_date: String) -> void:
	_built = ChallengePuzzle.build(for_date)

func _process(_delta: float) -> void:
	if _task_id < 0 or not WorkerThreadPool.is_task_completed(_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	set_process(false)
	puzzle = _built
	save_state()
	puzzle_ready.emit()
	state_changed.emit()

func is_ready() -> bool:
	return not puzzle.is_empty() and puzzle.get("date", "") == date

# Цена следующей попытки: первая бесплатно
func retry_price() -> int:
	if attempts == 0:
		return 0
	return mini(RETRY_BASE_PRICE * int(pow(2, attempts - 1)), RETRY_MAX_PRICE)

func can_start() -> bool:
	return is_ready() and not done_today and not active

# Начинает попытку, списывая цену. false — нельзя (пройдено, идёт попытка или не хватает монет)
func begin() -> bool:
	ensure_today()
	if not can_start():
		return false
	var price = retry_price()
	if price > 0:
		if not Progression.spend_coins(price):
			return false
		coins_spent += price
	attempts += 1
	active = true
	save_state()
	state_changed.emit()
	return true

# Итог попытки. Возвращает {"success", "xp", "new_streak", "milestone"}
func finish(success: bool, progress: int) -> Dictionary:
	active = false
	best_today = maxi(best_today, progress)
	var result = {"success": success, "xp": 0, "milestone": 0}
	if success and not done_today:
		done_today = true
		total_done += 1
		if last_done_date != "" and Progression.get_days_between(last_done_date, date) == 1:
			streak += 1
		else:
			streak = 1
		best_streak = maxi(best_streak, streak)
		last_done_date = date
		result["xp"] = XP_REWARD[clampi(int(puzzle.get("day", 0)), 0, XP_REWARD.size() - 1)]
		if total_done in MILESTONES:
			result["milestone"] = total_done
	result["streak"] = streak
	save_state()
	state_changed.emit()
	return result

# Попытку нельзя продолжить (сменился день, задача не готова) — она просто закрывается
func abandon() -> void:
	active = false
	save_state()
	state_changed.emit()

# Серия «дней подряд» прерывается, если вчера испытание не пройдено
func current_streak() -> int:
	if last_done_date == "":
		return 0
	var gap = Progression.get_days_between(last_done_date, Progression.get_current_date())
	return streak if gap <= 1 else 0

func save_state() -> void:
	SafeFile.save_var(SAVE_PATH, {
		"date": date, "attempts": attempts, "done_today": done_today, "best_today": best_today,
		"total_done": total_done, "streak": streak, "best_streak": best_streak,
		"last_done_date": last_done_date, "active": active, "coins_spent": coins_spent,
		"puzzle": puzzle,
	})

func load_state() -> void:
	var data = SafeFile.load_dict(SAVE_PATH)
	date = data.get("date", "")
	attempts = data.get("attempts", 0)
	done_today = data.get("done_today", false)
	best_today = data.get("best_today", 0)
	total_done = data.get("total_done", 0)
	streak = data.get("streak", 0)
	best_streak = data.get("best_streak", 0)
	last_done_date = data.get("last_done_date", "")
	active = data.get("active", false)
	coins_spent = data.get("coins_spent", 0)
	var saved = data.get("puzzle", {})
	puzzle = saved if saved is Dictionary else {}
