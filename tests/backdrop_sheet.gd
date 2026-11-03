extends SceneTree

## Витрина фонов: все фоны коллекции «Фоны» с полем поверх (как в профиле), через 2,5 секунды анимации.
## Нужен экран:
##   godot --path . --resolution 900x1600 -s tests/backdrop_sheet.gd -- --out=/tmp/backdrops.png
##     [--theme=classic] [--skin=0] [--paint=0] — тема, кубики и окраска поля; [--only=live|static] — какие фоны
var out := ""
var frames := 0
var opts := {}
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.trim_prefix("--").get_slice("=", 0)] = arg.get_slice("=", 1)
	out = opts.get("out", "")
func build():
	var tm = root.get_node("ThemeManager")
	tm.apply_theme(opts.get("theme", "classic"))
	tm.apply_skin(int(opts.get("skin", "0")))
	tm.apply_paint(int(opts.get("paint", "0")))
	var holder = Control.new()
	holder.size = Vector2(900, 1600)
	root.add_child(holder)
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.size = holder.size
	holder.add_child(bg)
	var db = root.get_node("ItemsDB")
	var ids = db.get_backdrop_ids()
	if opts.get("only", "") == "static":
		ids = ids.filter(func(i): return not db.get_backdrop_data(i).get("live", false))
	elif opts.get("only", "") == "live":
		ids = ids.filter(func(i): return db.get_backdrop_data(i).get("live", false))
	for i in range(ids.size()):
		var preview = load("res://ui/backdrop_preview.gd").new()
		preview.position = Vector2(8 + (i % 4) * 223, 8 + (i / 4) * 440)
		preview.size = Vector2(215, 382)
		holder.add_child(preview)
		preview.setup(ids[i], false)
		var label = Label.new()
		label.text = db.get_backdrop_data(ids[i])["name"]
		label.position = preview.position + Vector2(0, 384)
		label.add_theme_font_size_override("font_size", 20)
		holder.add_child(label)
func _process(_d):
	frames += 1
	if frames == 3:
		build()
	if frames == 150:
		root.get_texture().get_image().save_png(out)
		return true
	return false
