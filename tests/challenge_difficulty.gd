extends SceneTree

## Сложность испытания дня: игроки разного навыка (тот же выбор хода, что у tests/persona_bot.gd:
## линии − дыры × навык + случайность) проходят 56 дней подряд по 3 попытки. Печатает долю пройденных
## по навыку и по дню недели и причины неудач. По этим цифрам подобрана ChallengePuzzle.TARGET_SHARE.
##   godot --headless --path . -s tests/challenge_difficulty.gd
## Только считает — сохранения не трогает.

var reasons = {}
var stuck_at = []
func _initialize():
	var skills = [0.3, 0.55, 0.8, 1.0]
	var by_skill = {}
	var by_day = {}
	for skill in skills:
		by_skill[skill] = [0, 0]
	for d in range(7):
		by_day[d] = {}
		for skill in skills:
			by_day[d][skill] = [0, 0]
	var base = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 11, "day": 2, "hour": 12, "minute": 0, "second": 0})
	for i in range(56):
		var dt = Time.get_datetime_dict_from_unix_time(base + i * 86400)
		var date = "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
		var puzzle = ChallengePuzzle.build(date)
		for skill in skills:
			for attempt in range(3):
				var ok = play(puzzle, skill)
				by_skill[skill][0] += int(ok)
				by_skill[skill][1] += 1
				by_day[puzzle["day"]][skill][0] += int(ok)
				by_day[puzzle["day"]][skill][1] += 1
	for skill in skills:
		print("навык %.2f: пройдено %d%%" % [skill, 100 * by_skill[skill][0] / by_skill[skill][1]])
	stuck_at.sort()
	print("причины неудач: ", reasons, " застревал на ходу (медиана): ", stuck_at[stuck_at.size() / 2] if not stuck_at.is_empty() else -1)
	for d in range(7):
		var parts = []
		for skill in skills:
			parts.append("%.2f→%d%%" % [skill, 100 * by_day[d][skill][0] / by_day[d][skill][1]])
		print("%-11s %s" % [ChallengePuzzle.DAY_NAMES[d], "  ".join(parts)])
	quit()

func play(puzzle: Dictionary, skill: float) -> bool:
	var board = Board.new()
	for cell in puzzle["start"]:
		board.cells[cell[1]][cell[0]] = 0
	var scoring = Scoring.new()
	var lines_total = 0
	var score = 0
	var max_streak = 0
	var noise = 1.0 + 14.0 * (1.0 - skill)
	var moves_done = 0
	for shapes in puzzle["sets"]:
		var remaining = shapes.duplicate()
		while not remaining.is_empty():
			var best = []
			var best_value = -INF
			for index in range(remaining.size()):
				var shape = remaining[index]
				for y in range(8):
					for x in range(8):
						if not board.can_place(shape, x, y):
							continue
						var preview = board.duplicate_board()
						preview.place(shape, x, y, 0)
						var full = preview.find_full_lines()
						var n = Board.count_lines(full)
						if n > 0:
							preview.clear_lines(full)
						var value = n * 10.0 - holes(preview) * 1.5 * skill + randf() * noise
						if value > best_value:
							best_value = value
							best = [index, x, y]
			if best.is_empty():
				reasons["burned_sets"] = reasons.get("burned_sets", 0) + 1
				stuck_at.append(moves_done)
				break
			var shape = remaining[best[0]]
			moves_done += 1
			remaining.remove_at(best[0])
			board.place(shape, best[1], best[2], 0)
			var full = board.find_full_lines()
			var n = Board.count_lines(full)
			if n > 0:
				board.clear_lines(full)
			var result = scoring.register_move(shape.size(), n, n > 0 and board.is_board_empty())
			lines_total += n
			score += result["points"]
			max_streak = maxi(max_streak, result["streak"])
			var progress = lines_total
			if puzzle["goal"] == "score":
				progress = score
			elif puzzle["goal"] == "streak":
				progress = max_streak
			if progress >= puzzle["target"]:
				return true
	reasons["short"] = reasons.get("short", 0) + 1
	return false

func holes(board: Board) -> int:
	var count = 0
	for y in range(8):
		for x in range(8):
			if board.get_cell(x, y) != Board.EMPTY:
				continue
			var blocked = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not board.in_bounds(x + d.x, y + d.y) or board.get_cell(x + d.x, y + d.y) != Board.EMPTY:
					blocked += 1
			if blocked >= 3:
				count += blocked - 2
	return count
