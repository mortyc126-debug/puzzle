extends SceneTree

## Витрина эффектов очистки: строки — эффекты, столбцы — моменты 0,1, 0,3 и 0,6 с после очистки
## линии из 4 клеток. Нужен экран:
##   godot --path . --resolution 1340x2200 -s tests/effect_sheet.gd -- --out=/tmp/effects.png [--kinds=coins,notes]
var out := ""
var kinds: Array = []  # пусто — все эффекты из ItemsDB
var frames := 0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--kinds="): kinds = Array(arg.trim_prefix("--kinds=").split(","))
	var canvas = Node2D.new()
	canvas.draw.connect(func(): draw_sheet(canvas))
	root.add_child(canvas)
func draw_sheet(c: Node2D):
	if kinds.is_empty():
		var db = root.get_node("ItemsDB")
		for effect_id in db.get_effect_ids():
			kinds.append(db.get_effect_data(effect_id)["kind"])
	c.draw_rect(Rect2(0, 0, 2000, 2400), Color(0.08, 0.09, 0.16))
	var font = ThemeDB.fallback_font
	var colors = [Color(0.3, 0.5, 1), Color(1, 0.3, 0.35), Color(0.3, 0.85, 0.4), Color(1, 0.8, 0.2)]
	for row in range(kinds.size()):
		c.draw_string(font, Vector2(10, 60 + row * 112), kinds[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		for col in range(3):
			var t = [0.1, 0.3, 0.6][col]
			seed(row * 10 + 3)
			var particles: Array = []
			var origin = Vector2(170 + col * 380, 8 + row * 112)
			c.draw_rect(Rect2(origin, Vector2(360, 104)), Color(0.12, 0.13, 0.22))
			for k in range(4):
				var center = origin + Vector2(60 + k * 80, 52)
				EffectPainter.burst(particles, kinds[row], center, colors[k], 6, 80.0)
			var steps = int(t * 60)
			for i in range(steps):
				EffectPainter.update(particles, 1.0 / 60.0)
			EffectPainter.draw(c, particles)
func _process(_d):
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png(out)
		return true
	return false
