extends Node

## Темы блоков (автозагрузка ThemeManager).
## Чтобы добавить тему: создайте res://themes/<id>/<id>_theme.tres и допишите путь в THEME_PATHS.
## Список задан явно: в собранной игре .tres могут переименовываться при экспорте, а порядок
## в профиле должен быть предсказуемым.

signal theme_changed(theme: BlockTheme)
signal blocks_changed  # сменились кубики: перерисовать блоки (фон темы при этом не трогаем)
signal backdrop_changed  # сменился фон из коллекции «Фоны»

# Порядок — лестница открытия: от простых тем к самым красивым, «Космос» — венец (уровень 100)
const THEME_PATHS = [
	"res://themes/classic/classic_theme.tres",
	"res://themes/candy/candy_theme.tres",
	"res://themes/wood/wood_theme.tres",
	"res://themes/sakura/sakura_theme.tres",
	"res://themes/ocean/ocean_theme.tres",
	"res://themes/desert/desert_theme.tres",
	"res://themes/retro/retro_theme.tres",
	"res://themes/lava/lava_theme.tres",
	"res://themes/clouds/clouds_theme.tres",
	"res://themes/crystal/crystal_theme.tres",
	"res://themes/forest/forest_theme.tres",
	"res://themes/aurora/aurora_theme.tres",
	"res://themes/gold/gold_theme.tres",
	"res://themes/neon_city/neon_city_theme.tres",
	"res://themes/space/space_theme.tres",
]

var themes: Array = []
var current: BlockTheme
# Чем рисовать блоки: текущая тема, у которой вид блоков заменён выбранными кубиками
# (Progression.player_skin). Фон, поле и цвета — от темы. Без кубиков — сама тема.
var blocks: BlockTheme
var skin_id := 0
var paint_id := 0  # окраска поверх темы (ItemsDB.paints_data), 0 — цвета темы
var backdrop_id := 0  # фон поверх темы (ItemsDB.backdrops_data), 0 — фон самой темы

func _ready() -> void:
	for path in THEME_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("Тема не найдена: " + path)
			continue
		var theme = load(path)
		if theme is BlockTheme:
			themes.append(theme)
		else:
			push_warning("Файл не является BlockTheme: " + path)

	if themes.is_empty():
		# Аварийная тема, чтобы игра не упала без ресурсов
		var fallback = BlockTheme.new()
		fallback.id = "classic"
		fallback.display_name = "Классика"
		fallback.use_player_colors = true
		themes.append(fallback)

	current = themes[0]
	blocks = current

func get_theme_by_id(theme_id: String) -> BlockTheme:
	for theme in themes:
		if theme.id == theme_id:
			return theme
	return null

func get_theme_ids() -> Array:
	var ids = []
	for theme in themes:
		ids.append(theme.id)
	return ids

func apply_theme(theme_id: String) -> void:
	var theme = get_theme_by_id(theme_id)
	if theme == null or theme == current:
		return
	current = theme
	_rebuild_blocks()
	theme_changed.emit(current)
	Events.theme_changed.emit(theme_id)

# Кубики поверх темы: 0 — как в теме
func apply_skin(new_skin_id: int) -> void:
	if new_skin_id == skin_id and blocks != null:
		return
	skin_id = new_skin_id
	_rebuild_blocks()
	blocks_changed.emit()

func _rebuild_blocks() -> void:
	var data = ItemsDB.get_skin_data(skin_id) if skin_id > 0 else {}
	if data.is_empty():
		blocks = current
		return
	blocks = current.duplicate()
	blocks.block_style = data["style"]
	blocks.block_corner_radius = data.get("radius", current.block_corner_radius)
	blocks.glow_strength = data.get("glow", current.glow_strength)

# Тема с выбранными кубиками для превью: как будет выглядеть skin на теме theme
func with_skin(theme: BlockTheme, preview_skin: int) -> BlockTheme:
	var data = ItemsDB.get_skin_data(preview_skin) if preview_skin > 0 else {}
	if data.is_empty():
		return theme
	var copy = theme.duplicate()
	copy.block_style = data["style"]
	copy.block_corner_radius = data.get("radius", theme.block_corner_radius)
	copy.glow_strength = data.get("glow", theme.glow_strength)
	return copy

func apply_paint(new_paint_id: int) -> void:
	if new_paint_id == paint_id:
		return
	paint_id = new_paint_id
	blocks_changed.emit()

func apply_backdrop(new_backdrop_id: int) -> void:
	if new_backdrop_id == backdrop_id:
		return
	backdrop_id = new_backdrop_id
	backdrop_changed.emit()

# Сцена выбранного фона или null — тогда фон берётся из темы
func get_backdrop_scene(preview_backdrop: int = -1) -> PackedScene:
	var use_id = backdrop_id if preview_backdrop < 0 else preview_backdrop
	var path: String = ItemsDB.get_backdrop_data(use_id).get("scene", "") if use_id > 0 else ""
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

# Цвет окраски по индексу: {"color" — средний, "top"/"bottom" — градиент (прозрачные — без него), "rim"}
func paint_entry(paint: int, color_index: int) -> Dictionary:
	var data = ItemsDB.get_paint_data(paint)
	var colors: Array = data.get("colors", [])
	if colors.is_empty():
		return {}
	var item = colors[posmod(color_index, colors.size())]
	var none = Color(0, 0, 0, 0)
	var rim: Color = data.get("rim", none)
	if item is Array:
		return {"color": item[0].lerp(item[1], 0.5), "top": item[0], "bottom": item[1], "rim": rim}
	return {"color": item, "top": none, "bottom": none, "rim": rim}

# Рисует блок по индексу цвета: тема (или кубики), окраска и её градиент.
# paint: -2 — текущая окраска, -1 — цвета самой темы (превью тем), иначе — номер окраски
func draw_cell(canvas: CanvasItem, rect: Rect2, color_index: int, theme: BlockTheme = null, alpha: float = 1.0,
		paint: int = -2) -> void:
	if theme == null:
		theme = blocks
	var use_paint = paint_id if paint == -2 else paint
	if use_paint > 0:
		var entry = paint_entry(use_paint, color_index)
		if not entry.is_empty():
			BlockRenderer.draw_block(canvas, rect, entry["color"], theme, alpha, entry["top"], entry["bottom"], entry["rim"])
			return
	BlockRenderer.draw_block(canvas, rect, get_block_color(color_index, theme, -1), theme, alpha)

# Цвет блока по индексу, сохранённому на поле (для частиц и вспышек — средний цвет окраски)
func get_block_color(color_index: int, theme: BlockTheme = null, paint: int = -2) -> Color:
	var use_paint = paint_id if paint == -2 and theme == null else paint
	if use_paint > 0:
		var entry = paint_entry(use_paint, color_index)
		if not entry.is_empty():
			return entry["color"]
	if theme == null:
		theme = current
	if theme.use_player_colors or theme.palette.is_empty():
		var colors = ItemsDB.block_colors
		return colors[posmod(color_index, colors.size())]
	return theme.palette[posmod(color_index, theme.palette.size())]

# Из каких индексов выбирать цвет новых фигур
func get_spawn_color_indices() -> Array:
	var result = []
	var paint_colors: Array = ItemsDB.get_paint_data(paint_id).get("colors", []) if paint_id > 0 else []
	if not paint_colors.is_empty():
		return range(paint_colors.size())
	if current.use_player_colors or current.palette.is_empty():
		var progression = get_node_or_null("/root/Progression")
		if progression:
			for index in progression.active_colors:
				if index >= 0 and index < ItemsDB.block_colors.size():
					result.append(index)
		if result.is_empty():
			result = [0, 1, 2, 3]
	else:
		for i in range(current.palette.size()):
			result.append(i)
	return result
