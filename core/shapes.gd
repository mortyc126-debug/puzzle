class_name Shapes
extends RefCounted

## Библиотека форм блоков. Каждая форма — список клеток Vector2(x, y) от левого верхнего угла.

const LIST = [
	# === ОДИНОЧНЫЕ И МАЛЕНЬКИЕ ===
	[Vector2(0, 0)],

	# === ЛИНИИ ===
	[Vector2(0, 0), Vector2(1, 0)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)],
	[Vector2(0, 0), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(0, 3)],

	# === КВАДРАТ 2x2 ===
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],

	# === L-ФОРМЫ (4 поворота) ===
	[Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 2)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(1, 2)],
	[Vector2(2, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],

	# === ОБРАТНАЯ L (4 поворота) ===
	[Vector2(1, 0), Vector2(1, 1), Vector2(1, 2), Vector2(0, 2)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 2)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(2, 1)],

	# === T-ФОРМЫ (4 поворота) ===
	[Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1)],
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2)],
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)],

	# === Z и S ===
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)],
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)],
	[Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(1, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 2)],

	# === УГОЛКИ 2x2 из 3 клеток ===
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
	[Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
]

# Размер фигуры в клетках (ширина, высота)
static func get_size(shape: Array) -> Vector2i:
	var max_x = 0
	var max_y = 0
	for cell in shape:
		max_x = maxi(max_x, int(cell.x))
		max_y = maxi(max_y, int(cell.y))
	return Vector2i(max_x + 1, max_y + 1)

# Поворот на 90° по часовой стрелке; результат снова начинается с (0, 0)
static func rotate_cw(shape: Array) -> Array:
	var height = get_size(shape).y
	var rotated = []
	for cell in shape:
		rotated.append(Vector2(height - 1 - int(cell.y), int(cell.x)))
	return rotated

# Формы, сгруппированные по числу клеток: {1: [...], 2: [...], 3: [...], 4: [...]}
static func by_cell_count() -> Dictionary:
	var groups = {}
	for shape in LIST:
		var count = shape.size()
		if not groups.has(count):
			groups[count] = []
		groups[count].append(shape)
	return groups
