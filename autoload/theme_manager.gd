extends Node

## Темы блоков (автозагрузка ThemeManager).
## Чтобы добавить тему: создайте res://themes/<id>/<id>_theme.tres и допишите путь в THEME_PATHS.
## Список задан явно: в собранной игре .tres могут переименовываться при экспорте, а порядок
## в профиле должен быть предсказуемым.

signal theme_changed(theme: BlockTheme)

const THEME_PATHS = [
	"res://themes/classic/classic_theme.tres",
	"res://themes/space/space_theme.tres",
]

var themes: Array = []
var current: BlockTheme

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
	theme_changed.emit(current)
	Events.theme_changed.emit(theme_id)

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
