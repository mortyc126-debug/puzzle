extends SceneTree

## Витрина кубиков: строки — виды кубиков (первая — «как в теме»), столбцы — темы.
## Нужна, чтобы проверить новый вид блоков сразу на светлых и тёмных темах. Нужен экран:
##   godot --path . --resolution 1340x1600 -s tests/skin_sheet.gd -- --out=/tmp/skins.png --themes=classic,candy,wood,ocean,space
var out := ""
var themes_arg := "classic,candy,wood,ocean,space"
var frames := 0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--themes="): themes_arg = arg.trim_prefix("--themes=")
	var canvas = Node2D.new()
	canvas.draw.connect(func(): draw_sheet(canvas))
	root.add_child(canvas)
func draw_sheet(c: Node2D):
	var theme_ids = themes_arg.split(",")
	var cell = 54.0
	var col_w = cell * 4 + 30
	var row_h = cell * 2 + 34
	c.draw_rect(Rect2(0, 0, 2000, 2000), Color(0.1, 0.1, 0.12))
	var font = ThemeDB.fallback_font
	for col in range(theme_ids.size()):
		var theme = root.get_node("ThemeManager").get_theme_by_id(theme_ids[col])
		for row in range(11):
			var skin = row
			var t = root.get_node("ThemeManager").with_skin(theme, skin)
			var origin = Vector2(150 + col * col_w, 20 + row * row_h)
			c.draw_rect(Rect2(origin - Vector2(10, 10), Vector2(cell * 4 + 20, cell * 2 + 20)), theme.background_color)
			BlockRenderer.draw_board(c, Rect2(origin, Vector2(cell * 4, cell * 2)), theme)
			for i in range(8):
				var rect = Rect2(origin + Vector2((i % 4) * cell, (i / 4) * cell), Vector2(cell, cell))
				if i == 5:
					BlockRenderer.draw_empty_cell(c, rect, theme)
				else:
					BlockRenderer.draw_block(c, rect, root.get_node("ThemeManager").get_block_color(i, theme), t)
			if col == 0:
				var name = "тема" if skin == 0 else root.get_node("ItemsDB").get_skin_data(skin)["name"]
				c.draw_string(font, Vector2(8, origin.y + cell), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
func _process(_d):
	frames += 1
	if frames == 10:
		var img = root.get_texture().get_image()
		img.save_png(out)
		return true
	return false
