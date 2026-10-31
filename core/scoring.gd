class_name Scoring
extends RefCounted

## Подсчёт очков за ход.
## - За каждую поставленную клетку — POINTS_PER_CELL.
## - За очистку: 10 × линии × линии (как было), умноженное на множитель серии.
## - Серия растёт, когда линии очищаются ход за ходом. Ход без очистки серию не рвёт сразу:
##   после STREAK_GRACE_MOVES пустых ходов подряд она сбрасывается.
## - Чистое поле после очистки — бонус PERFECT_CLEAR_BONUS.

const POINTS_PER_CELL = 1
const POINTS_PER_LINE = 10
const PERFECT_CLEAR_BONUS = 300
const STREAK_GRACE_MOVES = 2
const STREAK_STEP = 0.5
const STREAK_MAX_MULTIPLIER = 4.0

var streak := 0
var moves_without_clear := 0

func reset() -> void:
	streak = 0
	moves_without_clear = 0

static func streak_multiplier(value: int) -> float:
	return minf(1.0 + STREAK_STEP * maxi(value - 1, 0), STREAK_MAX_MULTIPLIER)

# Регистрирует ход и возвращает разбивку очков:
# {"points", "placement", "clear", "streak", "multiplier", "perfect"}
func register_move(cells_placed: int, lines: int, board_empty_after: bool) -> Dictionary:
	var placement = cells_placed * POINTS_PER_CELL
	var clear = 0
	var multiplier = 1.0
	var perfect = false

	if lines > 0:
		streak += 1
		moves_without_clear = 0
		multiplier = streak_multiplier(streak)
		clear = int(POINTS_PER_LINE * lines * lines * multiplier)
		if board_empty_after:
			perfect = true
			clear += PERFECT_CLEAR_BONUS
	else:
		moves_without_clear += 1
		if moves_without_clear > STREAK_GRACE_MOVES:
			streak = 0

	return {
		"points": placement + clear,
		"placement": placement,
		"clear": clear,
		"streak": streak,
		"multiplier": multiplier,
		"perfect": perfect,
	}

# Для отмены хода
func get_state() -> Dictionary:
	return {"streak": streak, "moves_without_clear": moves_without_clear}

func set_state(state: Dictionary) -> void:
	streak = state.get("streak", 0)
	moves_without_clear = state.get("moves_without_clear", 0)
