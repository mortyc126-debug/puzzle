class_name ChallengePuzzle
extends RefCounted

## Испытание дня: одинаковая для всех задача на дату — стартовое поле, 12 наборов фигур (36 ходов),
## цель (линии, очки или серия) и сложность по дню недели (понедельник легче, воскресенье труднее).
##
## Проходимость гарантирована: задачу проигрывает решатель в трёх стилях, цель ставится не выше того,
## что он реально набрал. Наборы фигур не зависят от ходов игрока — у всех одна и та же задача.
## Если ни одна фигура набора не помещается, набор сгорает вместе с его ходами и приходит следующий:
## попытка кончается только когда ходы вышли. Иначе 85% неудач были «застрял на 17-м ходу» — лотерея
## на выживание вместо гонки за целью (замер ботами разного навыка).
## Решатель работает на массиве 8×8 со счётчиками рядов и колонок: генерация занимает десятки
## миллисекунд, и автозагрузка Challenge всё равно делит её на шаги по кадрам (Builder).

const SIZE = 8
const SETS = 12
const MOVES = SETS * 3
const GOALS = ["lines", "score", "streak"]
const MIN_TARGET = {"lines": 5, "score": 300, "streak": 3}
const DAY_NAMES = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]

# Задача на дату "ГГГГ-ММ-ДД" целиком (тесты). Игра строит её по шагам — см. Builder ниже.
static func build(date: String) -> Dictionary:
	var builder = Builder.new(date)
	while not builder.step():
		pass
	return builder.result

# Построение по шагам: один шаг — три набора одного прогона решателя (~5 мс на компьютере). Автозагрузка
# Challenge делает по шагу в кадр на основном потоке: фоновый поток при первой загрузке классов
# мог зависнуть навсегда (замечено в Godot), а пауза в полсекунды при открытии окна заметна.
class Builder:
	var date: String
	var day: int
	var goal: String
	var attempt := 0
	var style := 0
	var start: Array = []
	var sets: Array = []
	var results: Array = []
	var fallback: Dictionary = {}
	var result: Dictionary = {}
	var sim = null  # текущий прогон решателя

	func _init(for_date: String) -> void:
		date = for_date
		day = ChallengePuzzle.weekday_index(date)
		goal = ChallengePuzzle.GOALS[posmod(hash("goal:" + date), ChallengePuzzle.GOALS.size())]

	# true — задача готова (в result)
	func step() -> bool:
		if not result.is_empty():
			return true
		if attempt >= 12:
			result = fallback
			return true
		if sim == null:
			if style == 0:
				var rng = RandomNumberGenerator.new()
				rng.seed = hash("challenge:%s:%d" % [date, attempt])
				start = ChallengePuzzle.make_start(rng, day)
				sets = ChallengePuzzle.make_sets(rng, day)
				results = []
			sim = ChallengePuzzle.Sim.new(start, sets, style)
		# Шаг — три набора: на слабом телефоне это единицы миллисекунд за кадр
		if not sim.advance(3):
			return false
		results.append(sim.stats)
		sim = null
		style += 1
		if style < 3:
			return false
		style = 0
		attempt += 1
		var type = goal
		if type == "streak" and ChallengePuzzle.best_of(results, "streak") < ChallengePuzzle.MIN_TARGET["streak"]:
			type = "lines"
		var value = ChallengePuzzle.best_of(results, type)
		var played = ChallengePuzzle.best_of(results, "placed")
		var puzzle = {
			"date": date, "day": day, "goal": type, "moves": ChallengePuzzle.MOVES,
			"start": start, "sets": sets, "solver": value,
			"target": ChallengePuzzle.target_for(type, value, day),
		}
		if fallback.is_empty() and value > 0:
			fallback = puzzle
		# Решатель должен поставить большую часть фигур: задача — про цель, а не про выживание
		if played >= ChallengePuzzle.MOVES * 3 / 4 and value >= ChallengePuzzle.MIN_TARGET[type]:
			result = puzzle
			return true
		return false

# Цель — доля от результата решателя по дню недели (подобрано замером ботами разного навыка,
# tests/challenge_difficulty.gd): с понедельника по субботу проходят 75–90% попыток, в воскресенье ~35%
const TARGET_SHARE = [0.55, 0.60, 0.66, 0.72, 0.78, 0.84, 0.90]

static func target_for(type: String, value: int, day: int) -> int:
	var share = TARGET_SHARE[clampi(day, 0, 6)]
	var target = int(floor(value * share))
	if type == "score":
		target = int(floor(target / 10.0)) * 10
	return clampi(target, mini(MIN_TARGET[type], value), value)

# Задача из сохранения пригодна для игры: Game читает её поля без проверок
static func is_valid(puzzle: Dictionary) -> bool:
	if not puzzle.get("date") is String or not puzzle.get("goal") in GOALS or not puzzle.get("target") is int \
			or not puzzle.get("moves") is int or not puzzle.get("day") is int or not puzzle.get("start") is Array:
		return false
	var sets = puzzle.get("sets")
	if not sets is Array or sets.size() != SETS:
		return false
	for shapes in sets:
		if not shapes is Array or shapes.size() != 3:
			return false
		for shape in shapes:
			if not shape is Array or shape.is_empty():
				return false
			for cell in shape:
				if not cell is Vector2:
					return false
	for cell in puzzle["start"]:
		if not cell is Array or cell.size() != 3:
			return false
	return true

static func best_of(results: Array, key: String) -> int:
	var best = 0
	for result in results:
		best = maxi(best, int(result[key]))
	return best

# 0 = понедельник … 6 = воскресенье
static func weekday_index(date: String) -> int:
	var parts = date.split("-")
	if parts.size() != 3:
		return 0
	var unix = Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]),
		"day": int(parts[2]), "hour": 12, "minute": 0, "second": 0})
	var weekday = int(Time.get_datetime_dict_from_unix_time(unix)["weekday"])  # 0 = воскресенье
	return (weekday + 6) % 7

# Стартовое поле — симметричный узор: выглядит задуманным, а не случайным. [[x, y, слот цвета], …]
static func make_start(rng: RandomNumberGenerator, day: int) -> Array:
	var cells = {}
	var row_count = []
	row_count.resize(SIZE)
	row_count.fill(0)
	var pairs = 3 + day
	var guard = 0
	while cells.size() < pairs * 2 and guard < 200:
		guard += 1
		var x = rng.randi_range(0, SIZE / 2 - 1)
		var y = rng.randi_range(1, SIZE - 1)
		var mirror = Vector2i(SIZE - 1 - x, y)
		if cells.has(Vector2i(x, y)) or row_count[y] >= SIZE - 2:
			continue
		var slot = rng.randi_range(0, 2)
		cells[Vector2i(x, y)] = slot
		cells[mirror] = slot
		row_count[y] += 2
	var result = []
	for pos in cells.keys():
		result.append([pos.x, pos.y, cells[pos]])
	return result

static func make_sets(rng: RandomNumberGenerator, day: int) -> Array:
	var generator = PieceGenerator.new(rng.randi() & 0x7fffffff)
	var difficulty = 0.15 + 0.07 * day
	var sets = []
	for i in range(SETS):
		var shapes = []
		for j in range(3):
			shapes.append(generator.pick_shape(difficulty))
		sets.append(shapes)
	return sets

# === РЕШАТЕЛЬ ===
# Жадный игрок: ставит фигуры набора по одной, выбирая лучший ход по оценке своего стиля.
# style 0 — «линии» (чистит сразу), 1 — «комбо» (копит под несколько линий), 2 — «аккуратный» (без дыр).
# Возвращает {"lines", "score", "streak", "combos", "placed"}; очки и серию считает тот же Scoring, что и игра.
# Правило как в игре: набор, из которого ничего не помещается, сгорает — дальше следующий.
static func simulate(start: Array, sets: Array, style: int) -> Dictionary:
	var sim = Sim.new(start, sets, style)
	sim.advance(sets.size())
	return sim.stats

# Прогон решателя, который можно продвигать по нескольку наборов (Builder делает так по кадрам)
class Sim:
	var grid := PackedByteArray()
	var rows := PackedInt32Array()
	var cols := PackedInt32Array()
	var scoring := Scoring.new()
	var stats = {"lines": 0, "score": 0, "streak": 0, "combos": 0, "placed": 0}
	var sets: Array
	var style: int
	var set_index := 0

	func _init(start: Array, sets_to_play: Array, play_style: int) -> void:
		sets = sets_to_play
		style = play_style
		grid.resize(ChallengePuzzle.SIZE * ChallengePuzzle.SIZE)
		rows.resize(ChallengePuzzle.SIZE)
		cols.resize(ChallengePuzzle.SIZE)
		for cell in start:
			grid[cell[1] * ChallengePuzzle.SIZE + cell[0]] = 1
			rows[cell[1]] += 1
			cols[cell[0]] += 1

	# Играет до count наборов. true — все наборы сыграны
	func advance(count: int) -> bool:
		for k in range(count):
			if set_index >= sets.size():
				return true
			play_set(sets[set_index])
			set_index += 1
		return set_index >= sets.size()

	func play_set(shapes: Array) -> void:
		var size = ChallengePuzzle.SIZE
		var remaining = []
		for shape in shapes:
			var offsets = []
			for c in shape:
				offsets.append(Vector2i(int(c.x), int(c.y)))
			remaining.append(offsets)
		while not remaining.is_empty():
			var best_value = -INF
			var best = []
			for index in range(remaining.size()):
				var offsets: Array = remaining[index]
				for y in range(size):
					for x in range(size):
						if not ChallengePuzzle._fits(grid, offsets, x, y):
							continue
						var value = ChallengePuzzle._evaluate(grid, rows, cols, offsets, x, y, style)
						if value > best_value:
							best_value = value
							best = [index, x, y]
			if best.is_empty():
				return  # ничего не помещается — набор сгорает
			var placed: Array = remaining[best[0]]
			remaining.remove_at(best[0])
			var lines = ChallengePuzzle._apply(grid, rows, cols, placed, best[1], best[2])
			var empty = true
			for v in grid:
				if v != 0:
					empty = false
					break
			var result = scoring.register_move(placed.size(), lines, lines > 0 and empty)
			stats["placed"] += 1
			stats["lines"] += lines
			stats["score"] += result["points"]
			stats["streak"] = maxi(stats["streak"], result["streak"])
			if lines >= 2:
				stats["combos"] += 1

static func _fits(grid: PackedByteArray, offsets: Array, x: int, y: int) -> bool:
	for o in offsets:
		var px = x + o.x
		var py = y + o.y
		if px >= SIZE or py >= SIZE or grid[py * SIZE + px] != 0:
			return false
	return true

# Оценка хода без копирования поля: ставим, смотрим счётчики, считаем «соседей» и дыры, убираем
static func _evaluate(grid: PackedByteArray, rows: PackedInt32Array, cols: PackedInt32Array,
		offsets: Array, x: int, y: int, style: int) -> float:
	var touched_rows = {}
	var touched_cols = {}
	for o in offsets:
		grid[(y + o.y) * SIZE + x + o.x] = 2
		touched_rows[y + o.y] = touched_rows.get(y + o.y, 0) + 1
		touched_cols[x + o.x] = touched_cols.get(x + o.x, 0) + 1
	var lines = 0
	for r in touched_rows.keys():
		if rows[r] + touched_rows[r] == SIZE:
			lines += 1
	for c in touched_cols.keys():
		if cols[c] + touched_cols[c] == SIZE:
			lines += 1
	var contact = 0
	var holes = 0
	for o in offsets:
		var px = x + o.x
		var py = y + o.y
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx = px + d.x
			var ny = py + d.y
			if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
				contact += 1
				continue
			var v = grid[ny * SIZE + nx]
			if v == 1:
				contact += 1
			elif v == 0 and _enclosed(grid, nx, ny):
				holes += 1
	for o in offsets:
		grid[(y + o.y) * SIZE + x + o.x] = 0

	match style:
		0:
			return lines * 100.0 + contact * 3.0 - holes * 25.0
		1:
			var line_value = 0.0
			if lines == 1:
				line_value = 35.0
			elif lines >= 2:
				line_value = 140.0 * lines
			return line_value + contact * 4.0 - holes * 30.0 + _fullness(rows, cols, touched_rows, touched_cols) * 2.0
		_:
			return lines * 80.0 + contact * 6.0 - holes * 45.0

# Пустая клетка, со всех сторон закрытая блоками или краем — будущая «дыра»
static func _enclosed(grid: PackedByteArray, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx = x + d.x
		var ny = y + d.y
		if nx >= 0 and ny >= 0 and nx < SIZE and ny < SIZE and grid[ny * SIZE + nx] == 0:
			return false
	return true

# Насколько ход «докладывает» почти полные линии — стиль «комбо» копит их
static func _fullness(rows: PackedInt32Array, cols: PackedInt32Array, touched_rows: Dictionary, touched_cols: Dictionary) -> float:
	var total = 0.0
	for r in touched_rows.keys():
		total += rows[r] + touched_rows[r]
	for c in touched_cols.keys():
		total += cols[c] + touched_cols[c]
	return total

static func _apply(grid: PackedByteArray, rows: PackedInt32Array, cols: PackedInt32Array,
		offsets: Array, x: int, y: int) -> int:
	for o in offsets:
		grid[(y + o.y) * SIZE + x + o.x] = 1
		rows[y + o.y] += 1
		cols[x + o.x] += 1
	var full_rows = []
	var full_cols = []
	for i in range(SIZE):
		if rows[i] == SIZE:
			full_rows.append(i)
		if cols[i] == SIZE:
			full_cols.append(i)
	for r in full_rows:
		for i in range(SIZE):
			if grid[r * SIZE + i] != 0:
				grid[r * SIZE + i] = 0
				rows[r] -= 1
				cols[i] -= 1
	for c in full_cols:
		for i in range(SIZE):
			if grid[i * SIZE + c] != 0:
				grid[i * SIZE + c] = 0
				rows[i] -= 1
				cols[c] -= 1
	return full_rows.size() + full_cols.size()

# Описание цели для интерфейса
static func goal_text(puzzle: Dictionary) -> String:
	var target = int(puzzle.get("target", 0))
	var moves = int(puzzle.get("moves", MOVES))
	match puzzle.get("goal", "lines"):
		"score":
			return "Наберите %d очков за %d ходов" % [target, moves]
		"streak":
			return "Доведите серию до ×%d за %d ходов" % [target, moves]
		_:
			return "Очистите %d линий за %d ходов" % [target, moves]

static func goal_short(goal: String) -> String:
	match goal:
		"score":
			return "Очки"
		"streak":
			return "Серия"
		_:
			return "Линии"
