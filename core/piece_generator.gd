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

func generate_set(board: Board, difficulty: float, count: int = 3) -> Array:
	var attempts = int(round(lerpf(CANDIDATES[0], CANDIDATES[1], difficulty)))
	var best_set = []
	var best_fitting = -1

	for attempt in range(maxi(attempts, 1)):
		var candidate = []
		for i in range(count):
			candidate.append(pick_shape(difficulty))

		var fitting = 0
		for shape in candidate:
			if board.can_place_anywhere(shape):
				fitting += 1

		if fitting == count:
			return candidate
		if fitting > best_fitting:
			best_fitting = fitting
			best_set = candidate

	# Гарантия: если ни одна фигура не помещается — заменяем первую на подходящую
	if best_fitting <= 0:
		best_set[0] = find_fitting_shape(board)
	return best_set

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
