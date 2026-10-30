class_name Board
extends RefCounted

## Модель поля без отрисовки. Клетка хранит индекс цвета блока, EMPTY — пусто.
## Цвет по индексу берёт текущая тема, поэтому при смене темы поле перекрашивается.

const SIZE = 8
const EMPTY = -1

var cells: Array = []  # cells[y][x] -> int

func _init() -> void:
	clear()

func clear() -> void:
	cells = []
	for y in range(SIZE):
		var row = []
		row.resize(SIZE)
		row.fill(EMPTY)
		cells.append(row)

func duplicate_board() -> Board:
	var copy = Board.new()
	for y in range(SIZE):
		copy.cells[y] = cells[y].duplicate()
	return copy

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE

func is_empty(x: int, y: int) -> bool:
	return in_bounds(x, y) and cells[y][x] == EMPTY

func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return EMPTY
	return cells[y][x]

# Помещается ли фигура в границы поля (без учёта занятых клеток)
func fits(shape: Array, x: int, y: int) -> bool:
	for cell in shape:
		if not in_bounds(x + int(cell.x), y + int(cell.y)):
			return false
	return true

# Можно ли поставить фигуру: все клетки в поле и свободны
func can_place(shape: Array, x: int, y: int) -> bool:
	for cell in shape:
		if not is_empty(x + int(cell.x), y + int(cell.y)):
			return false
	return true

func can_place_anywhere(shape: Array) -> bool:
	for y in range(SIZE):
		for x in range(SIZE):
			if can_place(shape, x, y):
				return true
	return false

# Ставит фигуру и возвращает занятые клетки (Vector2i). Проверку делает вызывающий.
func place(shape: Array, x: int, y: int, color_index: int) -> Array:
	var placed = []
	for cell in shape:
		var px = x + int(cell.x)
		var py = y + int(cell.y)
		cells[py][px] = color_index
		placed.append(Vector2i(px, py))
	return placed

# Заполненные ряды и колонки: {"rows": [y...], "cols": [x...]}
func find_full_lines() -> Dictionary:
	var rows = []
	var cols = []
	for i in range(SIZE):
		var row_full = true
		var col_full = true
		for j in range(SIZE):
			if cells[i][j] == EMPTY:
				row_full = false
			if cells[j][i] == EMPTY:
				col_full = false
		if row_full:
			rows.append(i)
		if col_full:
			cols.append(i)
	return {"rows": rows, "cols": cols}

static func count_lines(lines: Dictionary) -> int:
	return lines["rows"].size() + lines["cols"].size()

# Очищает линии. Возвращает очищенные клетки: [{"pos": Vector2i, "color": int}], без повторов.
func clear_lines(lines: Dictionary) -> Array:
	var cleared = {}
	for y in lines["rows"]:
		for x in range(SIZE):
			cleared[Vector2i(x, y)] = cells[y][x]
	for x in lines["cols"]:
		for y in range(SIZE):
			cleared[Vector2i(x, y)] = cells[y][x]

	var result = []
	for pos in cleared.keys():
		result.append({"pos": pos, "color": cleared[pos]})
		cells[pos.y][pos.x] = EMPTY
	return result

# Убирает одну клетку (молоток). Возвращает её цвет или EMPTY.
func remove_cell(x: int, y: int) -> int:
	var color = get_cell(x, y)
	if color != EMPTY:
		cells[y][x] = EMPTY
	return color

func filled_count() -> int:
	var count = 0
	for row in cells:
		for value in row:
			if value != EMPTY:
				count += 1
	return count

func fill_ratio() -> float:
	return float(filled_count()) / float(SIZE * SIZE)

func is_board_empty() -> bool:
	return filled_count() == 0

# Для сохранения партии
func to_array() -> Array:
	var data = []
	for row in cells:
		data.append(row.duplicate())
	return data

func from_array(data: Array) -> void:
	clear()
	if data.size() != SIZE:
		return
	for y in range(SIZE):
		if data[y] is Array and data[y].size() == SIZE:
			cells[y] = data[y].duplicate()
