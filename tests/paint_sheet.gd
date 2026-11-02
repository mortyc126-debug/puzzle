extends SceneTree

## Витрина окрасок: строки — окраски (первая — цвета темы), столбцы — темы и кубики, в том числе
## светлые и тёмные. Нужна, чтобы проверить новую окраску на всех видах блоков. Нужен экран:
##   godot --path . --resolution 1400x1500 -s tests/paint_sheet.gd -- --out=/tmp/paints.png
var out := ""
var frames := 0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	var canvas = Node2D.new()
	canvas.draw.connect(func(): draw_sheet(canvas))
	root.add_child(canvas)
func draw_sheet(c: Node2D):
	var tm = root.get_node("ThemeManager")
	var db = root.get_node("ItemsDB")
	c.draw_rect(Rect2(0, 0, 2000, 2400), Color(0.1, 0.1, 0.13))
	var font = ThemeDB.fallback_font
	var columns = [["classic", 0], ["classic", 2], ["classic", 5], ["candy", 0], ["space", 4], ["wood", 8]]
	var cell = 40.0
	for row in range(db.get_paint_ids().size() + 1):
		var paint = 0 if row == 0 else db.get_paint_ids()[row - 1]
		var name = "тема" if paint == 0 else db.get_paint_data(paint)["name"]
		c.draw_string(font, Vector2(8, 34 + row * 120 + cell), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		for col in range(columns.size()):
			var theme = tm.get_theme_by_id(columns[col][0])
			var t = tm.with_skin(theme, columns[col][1])
			var origin = Vector2(150 + col * 200, 14 + row * 120)
			c.draw_rect(Rect2(origin - Vector2(6, 6), Vector2(cell * 4 + 12, cell * 2 + 12)), theme.background_color)
			BlockRenderer.draw_board(c, Rect2(origin, Vector2(cell * 4, cell * 2)), theme)
			for i in range(8):
				var rect = Rect2(origin + Vector2((i % 4) * cell, (i / 4) * cell), Vector2(cell, cell))
				tm.draw_cell(c, rect, i % 6, t, 1.0, paint if paint > 0 else -1)
func _process(_d):
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png(out)
		return true
	return false
