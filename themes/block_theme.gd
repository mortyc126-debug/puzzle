class_name BlockTheme
extends Resource

## Тема оформления поля и блоков. Каждая тема — отдельный файл .tres в res://themes/<id>/.
## Редактируется в инспекторе Godot. Как добавить новую тему — docs/CONTENT.md.

enum BlockStyle {
	FLAT,     ## Плоский скруглённый квадрат
	BEVEL,    ## Классика: тень, светлая верхняя половина, белая обводка
	GLOSSY,   ## Глянец: блик сверху, тень снизу
	GLOW,     ## Неон: тёмная сердцевина, яркая обводка и свечение
	TEXTURE,  ## Картинка block_texture, окрашенная в цвет блока
	CANDY,    ## Конфета-желейка: светлая середина, белый блик, тень снизу
	GLASS,    ## Стекло: полупрозрачная заливка, светлая кромка, косой блик, пузырёк
	WOOD,     ## Дерево: волокна, сучок, мягкая фаска
	PIXEL,    ## Пиксели: квадрат без скругления, 8-битная фаска
}

@export_group("Описание")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC") var rarity: String = "COMMON"
## Условие открытия, формат как у предметов ItemsDB: {"type": "default"}, {"type": "level", "level": 5},
## {"type": "achievement", "id": "lines", "tier": 2}
@export var unlock: Dictionary = {"type": "default"}

@export_group("Фон")
@export var background_color: Color = Color(0.08, 0.09, 0.16)
## Картинка фона (растягивается на весь экран с сохранением пропорций)
@export var background_texture: Texture2D
## Сцена фона (анимированный фон: звёзды, частицы). Рисуется под полем.
@export var background_scene: PackedScene

@export_group("Поле")
@export var board_color: Color = Color(0.2, 0.2, 0.25)
@export var cell_color: Color = Color(0.25, 0.25, 0.31)
@export var board_corner_radius: float = 12.0
@export var board_padding: float = 6.0
@export var line_highlight_color: Color = Color(1, 1, 1, 0.12)

@export_group("Блоки")
@export var block_style: BlockStyle = BlockStyle.BEVEL
## true — цвета берутся из выбора игрока (вкладка «Цвета» в профиле), иначе из palette
@export var use_player_colors: bool = false
@export var palette: PackedColorArray = PackedColorArray()
@export var block_texture: Texture2D
## Радиус скругления для клетки 80 px (масштабируется под размер)
@export var block_corner_radius: float = 8.0
@export_range(0.0, 1.0) var glow_strength: float = 0.6

@export_group("Эффекты")
@export var ghost_invalid_color: Color = Color(1, 0.25, 0.3, 0.35)
@export var flash_color: Color = Color.WHITE
@export var particle_color: Color = Color(1, 0.95, 0.4)
@export var accent_color: Color = Color(1, 0.84, 0)

@export_group("Звуки")
## Необязательно: свой звук постановки и очистки для темы
@export var sound_place: AudioStream
@export var sound_clear: AudioStream

func get_palette_size() -> int:
	return palette.size()
