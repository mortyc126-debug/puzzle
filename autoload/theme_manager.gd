extends Node

## Темы блоков (автозагрузка ThemeManager).
## Чтобы добавить тему: создайте res://themes/<id>/<id>_theme.tres и допишите путь в THEME_PATHS.
## Список задан явно: в собранной игре .tres могут переименовываться при экспорте, а порядок
## в профиле должен быть предсказуемым.

signal theme_changed(theme: BlockTheme)
signal blocks_changed  # сменились кубики: перерисовать блоки (фон темы при этом не трогаем)

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

# Цвет блока по индексу, сохранённому на поле
func get_block_color(color_index: int, theme: BlockTheme = null) -> Color:
	if theme == null:
		theme = current
	if theme.use_player_colors or theme.palette.is_empty():
		var colors = ItemsDB.block_colors
		return colors[posmod(color_index, colors.size())]
	return theme.palette[posmod(color_index, theme.palette.size())]

# Из каких индексов выбирать цвет новых фигур
func get_spawn_color_indices() -> Array:
	var result = []
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
