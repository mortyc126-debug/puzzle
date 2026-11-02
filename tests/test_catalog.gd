extends SceneTree

## Проверка каталога наград: все предметы подписаны и открываются на допустимом уровне или за
## существующее достижение; фоны грузятся и рисуются; у окрасок хватает цветов для фигур; каждый
## эффект очистки даёт частицы; пороги достижений «Откройте N …» достижимы.
## Только читает — сохранения игрока не меняет:
##   godot --headless --path . --fixed-fps 60 -s tests/test_catalog.gd
## В конце печатает «CATALOG: OK» или список проблем (и выходит с кодом 1).

var problems: Array = []
var checks := 0
var frames := 0
var backdrops: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		problems.append(message)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		check_items()
		check_achievements()
		check_paints()
		check_effects()
		start_backdrops()
	if frames == 60:
		for node in backdrops:
			check(is_instance_valid(node) and node.time > 0.5, "фон %s не анимируется" % node.name)
		for node in backdrops:
			node.queue_free()
		print("Проверок: %d" % checks)
		for problem in problems:
			print("  ✗ ", problem)
		print("CATALOG: OK" if problems.is_empty() else "CATALOG: %d проблем" % problems.size())
		quit(0 if problems.is_empty() else 1)
	return false

func check_items() -> void:
	var prog = root.get_node("Progression")
	var achievements = root.get_node("Achievements")
	var rarities = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]
	var names = {}
	for item in prog.get_all_items():
		var key = "%s:%s" % [item["type"], item["id"]]
		var label: String = prog.get_item_label(item["type"], item["id"])
		check(label != "Награда" and not label.contains("«?»"), "%s без названия (%s)" % [key, label])
		check(not names.has(label), "два предмета с одной подписью «%s»" % label)
		names[label] = true
		check(rarities.has(prog.get_item_rarity(item["type"], item["id"])), "%s: неизвестная редкость" % key)
		var unlock: Dictionary = item["unlock"]
		match unlock.get("type", "default"):
			"default":
				pass
			"level":
				var level = int(unlock.get("level", 0))
				check(level >= 2 and level <= prog.MAX_LEVEL, "%s открывается на уровне %d" % [key, level])
			"achievement":
				var def: Dictionary = achievements.get_definition(unlock.get("id", ""))
				check(not def.is_empty(), "%s: нет достижения «%s»" % [key, unlock.get("id", "")])
				check(int(unlock.get("tier", 0)) >= 1 and int(unlock.get("tier", 0)) <= def.get("tiers", []).size(),
					"%s: у достижения нет ступени %s" % [key, unlock.get("tier", 0)])
			_:
				check(false, "%s: неизвестное условие %s" % [key, unlock])

# «Откройте N фонов» не может требовать больше, чем есть в игре
func check_achievements() -> void:
	var db = root.get_node("ItemsDB")
	var tm = root.get_node("ThemeManager")
	var sizes = {"skins_unlocked": db.get_skin_ids().size(), "paints_unlocked": db.get_paint_ids().size(),
		"backdrops_unlocked": db.get_backdrop_ids().size(), "themes_unlocked": tm.themes.size(),
		"frames_unlocked": db.get_frame_ids().size()}
	for def in root.get_node("Achievements").LIST:
		var stat = def.get("stat", "")
		if sizes.has(stat):
			var tiers: Array = def.get("tiers", [])
			check(int(tiers[-1]) <= sizes[stat], "достижение «%s» просит %d, а в игре %d" % [def["title"], tiers[-1], sizes[stat]])

func check_paints() -> void:
	var db = root.get_node("ItemsDB")
	var tm = root.get_node("ThemeManager")
	for paint_id in db.get_paint_ids():
		var colors: Array = db.get_paint_data(paint_id).get("colors", [])
		check(colors.size() >= 5, "окраска %d: всего %d цветов" % [paint_id, colors.size()])
		for i in range(colors.size()):
			var entry: Dictionary = tm.paint_entry(paint_id, i)
			check(entry.has("color") and entry["color"].a > 0.9, "окраска %d, цвет %d прозрачный" % [paint_id, i])

func check_effects() -> void:
	var db = root.get_node("ItemsDB")
	var canvas = Node2D.new()
	root.add_child(canvas)
	for effect_id in db.get_effect_ids():
		var kind: String = db.get_effect_data(effect_id).get("kind", "")
		var particles: Array = []
		EffectPainter.burst(particles, kind, Vector2(200, 200), Color(0.4, 0.7, 1), 8, 80.0)
		check(not particles.is_empty(), "эффект «%s» (%s) не дал частиц" % [db.get_effect_data(effect_id)["name"], kind])
		for i in range(90):
			EffectPainter.update(particles, 1.0 / 60.0)
		check(particles.size() < 400, "эффект %s: частицы не исчезают (%d)" % [kind, particles.size()])
	canvas.queue_free()

func start_backdrops() -> void:
	var db = root.get_node("ItemsDB")
	for backdrop_id in db.get_backdrop_ids():
		var data: Dictionary = db.get_backdrop_data(backdrop_id)
		var path: String = data.get("scene", "")
		check(ResourceLoader.exists(path), "фон %d: нет сцены %s" % [backdrop_id, path])
		check(data.has("color") and data.has("description"), "фон %d: нет цвета или описания" % backdrop_id)
		if not ResourceLoader.exists(path):
			continue
		var node = load(path).instantiate()
		check(node is BackdropBase, "фон %d не наследует BackdropBase" % backdrop_id)
		node.name = "Backdrop%d" % backdrop_id
		root.add_child(node)
		backdrops.append(node)
