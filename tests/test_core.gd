extends SceneTree

## Тесты чистой логики (Board, PieceGenerator, Scoring, SafeFile).
## Запуск (один раз перед этим откройте проект в редакторе или выполните --import):
##   godot --headless --path . -s tests/test_core.gd

var failures := 0
var checks := 0

func _init() -> void:
	test_board_place_and_lines()
	test_board_clear_cross()
	test_board_fits_and_bounds()
	test_generator_guarantee()
	test_generator_difficulty_bias()
	test_scoring_streak()
	test_scoring_perfect()
	test_rotation()
	test_safe_file()

	print("")
	print("Проверок: %d, ошибок: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: ", message)

func test_board_place_and_lines() -> void:
	var board = Board.new()
	var line4 = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]
	check(board.can_place(line4, 0, 0), "линия 4 ставится в угол")
	board.place(line4, 0, 0, 1)
	check(not board.can_place(line4, 0, 0), "занятые клетки нельзя занять снова")
	board.place(line4, 4, 0, 2)
	var lines = board.find_full_lines()
	check(lines["rows"] == [0], "заполненный ряд 0 найден")
	check(lines["cols"].is_empty(), "колонок нет")
	var cleared = board.clear_lines(lines)
	check(cleared.size() == 8, "очищено 8 клеток")
	check(board.is_board_empty(), "поле пустое после очистки")

func test_board_clear_cross() -> void:
	var board = Board.new()
	for i in range(Board.SIZE):
		board.cells[3][i] = 0
		board.cells[i][5] = 0
	var lines = board.find_full_lines()
	check(Board.count_lines(lines) == 2, "крест: 2 линии")
	var cleared = board.clear_lines(lines)
	check(cleared.size() == 15, "крест: пересечение не считается дважды (15 клеток)")

func test_board_fits_and_bounds() -> void:
	var board = Board.new()
	var line4 = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]
	check(board.fits(line4, 4, 0), "линия 4 влезает с x=4")
	check(not board.fits(line4, 5, 0), "линия 4 не влезает с x=5")
	check(not board.can_place(line4, -1, 0), "отрицательные координаты недопустимы")

func test_generator_guarantee() -> void:
	# Поле заполнено, кроме одной клетки: набор обязан содержать фигуру, которая помещается
	var board = Board.new()
	for y in range(Board.SIZE):
		for x in range(Board.SIZE):
			board.cells[y][x] = 0
	board.cells[0][0] = Board.EMPTY
	board.cells[7][7] = Board.EMPTY
	var generator = PieceGenerator.new(42)
	for i in range(50):
		var pieces = generator.generate_set(board, 1.0)
		var any_fits = false
		for shape in pieces:
			if board.can_place_anywhere(shape):
				any_fits = true
		check(any_fits, "в наборе есть фигура, которая помещается (попытка %d)" % i)

func test_generator_difficulty_bias() -> void:
	var generator = PieceGenerator.new(7)
	var big_easy = 0
	var big_hard = 0
	for i in range(2000):
		if generator.pick_shape(0.0).size() == 4:
			big_easy += 1
		if generator.pick_shape(1.0).size() == 4:
			big_hard += 1
	check(big_hard > big_easy, "на высокой сложности крупных фигур больше (%d > %d)" % [big_hard, big_easy])

func test_scoring_streak() -> void:
	var scoring = Scoring.new()
	var first = scoring.register_move(4, 1, false)
	check(first["points"] == 4 + 10, "1 линия без серии: 4 + 10")
	var second = scoring.register_move(3, 1, false)
	check(second["streak"] == 2, "серия 2")
	check(second["clear"] == 15, "серия 2: 10 × 1.5 = 15")
	scoring.register_move(2, 0, false)
	scoring.register_move(2, 0, false)
	check(scoring.streak == 2, "два пустых хода серию не рвут")
	scoring.register_move(2, 0, false)
	check(scoring.streak == 0, "третий пустой ход рвёт серию")
	var double = scoring.register_move(4, 2, false)
	check(double["clear"] == 40, "2 линии: 10 × 2 × 2 = 40")

func test_rotation() -> void:
	var line3 = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]
	var vertical = Shapes.rotate_cw(line3)
	check(Shapes.get_size(vertical) == Vector2i(1, 3), "горизонтальная линия становится вертикальной")
	for shape in Shapes.LIST:
		var full_turn = Shapes.rotate_cw(Shapes.rotate_cw(Shapes.rotate_cw(Shapes.rotate_cw(shape))))
		var same = full_turn.size() == shape.size()
		for cell in shape:
			if not full_turn.has(cell):
				same = false
		check(same, "четыре поворота возвращают фигуру %s" % [shape])
		var turned = Shapes.rotate_cw(shape)
		var min_x = 99
		var min_y = 99
		for cell in turned:
			min_x = mini(min_x, int(cell.x))
			min_y = mini(min_y, int(cell.y))
		check(min_x == 0 and min_y == 0, "повёрнутая фигура начинается с (0, 0)")

func test_scoring_perfect() -> void:
	var scoring = Scoring.new()
	var result = scoring.register_move(4, 1, true)
	check(result["perfect"], "чистое поле отмечено")
	check(result["clear"] == 10 + Scoring.PERFECT_CLEAR_BONUS, "бонус за чистое поле")

# Сохранение переживает обрезанный основной файл (телефон выключился во время записи)
func test_safe_file() -> void:
	var path = "user://test_safe_file.save"
	SafeFile.remove(path)
	check(SafeFile.load_dict(path).is_empty(), "нет файла — пустой словарь")
	check(SafeFile.save_var(path, {"coins": 10}), "первая запись")
	check(SafeFile.save_var(path, {"coins": 20}), "вторая запись")
	check(int(SafeFile.load_dict(path).get("coins", 0)) == 20, "читается последняя запись")

	# Портим основной файл: оставляем 3 байта
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	check(int(SafeFile.load_dict(path).get("coins", 0)) == 10, "испорченный файл — берётся резервная копия")

	SafeFile.remove(path)
	check(not SafeFile.exists(path), "remove убирает основной файл и копии")
