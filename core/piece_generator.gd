class_name PieceGenerator
extends RefCounted

## Генератор наборов фигур.
## - Фигуры выбираются по группам размера: в начале партии чаще маленькие, с ростом сложности — крупные.
## - Перебирается несколько наборов-кандидатов, предпочтение — набору, где каждая фигура помещается.
## - Жёсткая гарантия: хотя бы одна фигура набора помещается на поле (иначе игрок проиграл бы без хода).

# Вероятность группы по числу клеток: [в начале, на максимальной сложности]
const GROUP_WEIGHTS = {
	1: [0.10, 0.04],
	2: [0.20, 0.10],
	3: [0.35, 0.30],
	4: [0.35, 0.56],
}

# Сколько наборов-кандидатов перебирать: [в начале, на максимальной сложности].
# Меньше попыток — выше шанс получить неудобный набор.
const CANDIDATES = [12, 3]

var rng := RandomNumberGenerator.new()
var _groups: Dictionary = Shapes.by_cell_count()

func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

# Сложность 0..1 по счёту партии
static func difficulty_for_score(score: int) -> float:
	return clampf(float(score) / 4000.0, 0.0, 1.0)

func pick_shape(difficulty: float) -> Array:
	var total = 0.0
	var weights = {}
	for count in GROUP_WEIGHTS.keys():
		if not _groups.has(count):
			continue
		var pair = GROUP_WEIGHTS[count]
		var weight = lerpf(pair[0], pair[1], difficulty)
		weights[count] = weight
		total += weight

	var roll = rng.randf() * total
	var chosen = 4
	for count in weights.keys():
		roll -= weights[count]
		if roll <= 0.0:
			chosen = count
			break

	var group: Array = _groups[chosen]
	return group[rng.randi() % group.size()]

# assist 0..1 — помощь новичку в первых партиях (Game передаёт её по числу сыгранных партий):
# - кандидатов перебирается больше;
# - когда поле заполнено больше чем наполовину (игрок «тонет»), выбирается набор, который может закрыть линию;
# - при assist ≥ 0.5 каждая фигура набора помещается на поле (а не хотя бы одна).
func generate_set(board: Board, difficulty: float, count: int = 3, assist: float = 0.0) -> Array:
	var attempts = int(round(lerpf(CANDIDATES[0], CANDIDATES[1], difficulty) * (1.0 + assist)))
	var helpful = assist > 0.0 and board.fill_ratio() > 0.5
	var best_set = []
	var best_value = -1.0
	var best_fitting = -1

	for attempt in range(maxi(attempts, 1)):
		var candidate = []
		for i in range(count):
			candidate.append(pick_shape(difficulty))

		var fitting = 0
		for shape in candidate:
			if board.can_place_anywhere(shape):
				fitting += 1

		if fitting == count and not helpful:
			return candidate
		var value = float(fitting) * 10.0
		if helpful and fitting > 0:
			value += best_line_clear(board, candidate) * 3.0 * assist
		if value > best_value:
			best_value = value
			best_fitting = fitting
			best_set = candidate

	if assist >= 0.5:
		# Новичку — все фигуры с местом на поле
		for i in range(best_set.size()):
			if not board.can_place_anywhere(best_set[i]):
				best_set[i] = find_fitting_shape(board)
	elif best_fitting <= 0:
		# Гарантия: если ни одна фигура не помещается — заменяем первую на подходящую
		best_set[0] = find_fitting_shape(board)
	return best_set

# Сколько линий одним ходом может закрыть лучшая фигура набора
func best_line_clear(board: Board, shapes: Array) -> int:
	var best = 0
	for shape in shapes:
		for y in range(Board.SIZE):
			for x in range(Board.SIZE):
				if not board.can_place(shape, x, y):
					continue
				var preview = board.duplicate_board()
				preview.place(shape, x, y, 0)
				best = maxi(best, Board.count_lines(preview.find_full_lines()))
	return best

# Случайная фигура, которая точно помещается. Перебор от маленьких к большим не нужен:
# одиночная клетка помещается всегда, когда на поле есть хоть одна пустая клетка.
func find_fitting_shape(board: Board) -> Array:
	var shuffled = Shapes.LIST.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for shape in shuffled:
		if board.can_place_anywhere(shape):
			return shape
	return Shapes.LIST[0]
