extends Node

## Каталог предметов (автозагрузка ItemsDB): цвета блоков, аватарки, рамки.
## Темы блоков описаны отдельными ресурсами в res://themes/ (см. ThemeManager).
##
## Поле "unlock" описывает, как предмет открывается — один источник правды для всей игры:
##   {"type": "default"}                              — доступен сразу
##   {"type": "level", "level": 5}                    — награда уровня Battle Pass
##   {"type": "achievement", "id": "lines", "tier": 2} — награда ступени достижения (см. Achievements)
## Progression сам выдаёт предметы, когда условие выполнено.

# === ЦВЕТА БЛОКОВ ===
# Индексы из Progression.active_colors указывают на этот список (тема «Классика»)

var block_colors = [
	Color.ROYAL_BLUE, Color.RED, Color.GREEN, Color.YELLOW,
	Color.PURPLE, Color.ORANGE, Color.CYAN, Color.PINK,
	Color.LIME_GREEN, Color.MAGENTA, Color.SADDLE_BROWN, Color.TURQUOISE,
	Color.GOLD, Color.CRIMSON, Color.DARK_GREEN, Color(0, 0, 0.5),
	Color.OLIVE, Color.TEAL, Color.CORAL, Color.INDIGO
]

# === РАМКИ ===

var frames_data = {
	1: {
		"name": "Бронза",
		"rarity": "COMMON",
		"description": "Простая бронзовая рамка. Отличное начало для каждого новичка!",
		"texture": "res://assets/frames/frame_1.png",
		"unlock": {"type": "default"},
	},
	2: {
		"name": "Серебро",
		"rarity": "UNCOMMON",
		"description": "Холодный блеск серебра для тех, кто уже освоился на поле.",
		"texture": "res://assets/frames/frame_2.svg",
		"unlock": {"type": "level", "level": 8},
	},
	3: {
		"name": "Золото",
		"rarity": "EPIC",
		"description": "Награда за сотню сыгранных партий. Такую рамку видно издалека.",
		"texture": "res://assets/frames/frame_3.svg",
		"unlock": {"type": "achievement", "id": "games", "tier": 3},
	},
	4: {
		"name": "Туманность",
		"rarity": "LEGENDARY",
		"description": "Светится, как облако звёздного газа. Для мастеров очистки линий.",
		"texture": "res://assets/frames/frame_4.svg",
		"unlock": {"type": "achievement", "id": "lines", "tier": 4},
	},
}

# === АВАТАРКИ ===
# Картинки: res://assets/avatars/avatar_<id>.svg, квадрат 256×256.
# Нижнюю четверть закрывает плашка рамки с именем — важное держим выше.

var avatars_data = {
	1: {
		"name": "Кубик",
		"rarity": "COMMON",
		"description": "Самый первый блок на поле. Добродушный, квадратный и всегда готов встать в ряд.",
		"unlock": {"type": "default"},
	},
	2: {
		"name": "Котоблок",
		"rarity": "COMMON",
		"description": "Кот, который любит, когда всё сложено ровно. Особенно коробки.",
		"unlock": {"type": "default"},
	},
	3: {
		"name": "Робо",
		"rarity": "COMMON",
		"description": "Считает свободные клетки быстрее, чем вы моргнёте.",
		"unlock": {"type": "default"},
	},
	4: {
		"name": "Лисёнок",
		"rarity": "COMMON",
		"description": "Хитро подбирает место для каждой фигуры.",
		"unlock": {"type": "default"},
	},
	5: {
		"name": "Космонавт",
		"rarity": "UNCOMMON",
		"description": "Готов к межгалактическим рейдам! Не выпускает фигуры даже в невесомости.",
		"unlock": {"type": "level", "level": 3},
	},
	6: {
		"name": "Ракета",
		"rarity": "UNCOMMON",
		"description": "Стартует с первой очищенной линии и уже не останавливается.",
		"unlock": {"type": "level", "level": 7},
	},
	7: {
		"name": "Планета",
		"rarity": "RARE",
		"description": "Кольца вокруг неё — это очищенные линии. Говорят, их уже тысячи.",
		"unlock": {"type": "achievement", "id": "space_games", "tier": 1},
	},
	8: {
		"name": "Пришелец",
		"rarity": "RARE",
		"description": "Прилетел посмотреть на чистое поле. Увидел — и остался.",
		"unlock": {"type": "achievement", "id": "perfect", "tier": 1},
	},
	9: {
		"name": "НЛО",
		"rarity": "EPIC",
		"description": "Появляется, когда серия очисток не прерывается слишком долго.",
		"unlock": {"type": "achievement", "id": "streak", "tier": 3},
	},
	10: {
		"name": "Чёрная дыра",
		"rarity": "LEGENDARY",
		"description": "Затягивает очки. Только для тех, кто набирал по-настоящему много.",
		"unlock": {"type": "achievement", "id": "score", "tier": 4},
	},
	11: {
		"name": "Луна",
		"rarity": "UNCOMMON",
		"description": "Спокойная и терпеливая. Каждый кратер — сыгранная партия.",
		"unlock": {"type": "level", "level": 15},
	},
	12: {
		"name": "Комета",
		"rarity": "EPIC",
		"description": "Четыре линии за один ход — и она проносится по небу.",
		"unlock": {"type": "achievement", "id": "quad", "tier": 1},
	},
}

# === ФОНЫ И МУЗЫКА ===
# Фоны теперь часть тем блоков. Музыка — заготовка на будущее.

var music_data = {}

# === ДОСТУП ===

func get_avatar_ids() -> Array:
	var ids = avatars_data.keys()
	ids.sort()
	return ids

func get_frame_ids() -> Array:
	var ids = frames_data.keys()
	ids.sort()
	return ids

func get_avatar_data(avatar_id: int) -> Dictionary:
	return avatars_data.get(avatar_id, {})

func get_frame_data(frame_id: int) -> Dictionary:
	return frames_data.get(frame_id, {})

func get_music_data(music_id: int) -> Dictionary:
	return music_data.get(music_id, {})

func get_avatar_texture(avatar_id: int) -> Texture2D:
	var data = get_avatar_data(avatar_id)
	var path = data.get("texture", "res://assets/avatars/avatar_%d.svg" % avatar_id)
	return _load_texture(path)

func get_frame_texture(frame_id: int) -> Texture2D:
	var data = get_frame_data(frame_id)
	var path = data.get("texture", "res://assets/frames/frame_%d.png" % frame_id)
	return _load_texture(path)

func _load_texture(path: String) -> Texture2D:
	# ResourceLoader.exists работает и в собранном APK, где исходных картинок нет
	if ResourceLoader.exists(path):
		return load(path)
	return null

# Текст условия открытия для карточек предметов
func get_unlock_text(unlock: Dictionary) -> String:
	match unlock.get("type", "default"):
		"default":
			return "Доступно сразу"
		"level":
			return "Откроется на уровне %d" % unlock.get("level", 1)
		"achievement":
			var achievements = get_node_or_null("/root/Achievements")
			if achievements:
				return "Достижение «%s», ступень «%s»" % [
					achievements.get_title(unlock.get("id", "")),
					achievements.get_tier_name(unlock.get("tier", 1)),
				]
			return "Награда за достижение"
	return ""

# Получить цвет редкости
func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"COMMON":
			return Color(0.7, 0.7, 0.7)
		"UNCOMMON":
			return Color(0.3, 1, 0.3)
		"RARE":
			return Color(0.2, 0.5, 1)
		"EPIC":
			return Color(0.8, 0.2, 1)
		"LEGENDARY":
			return Color(1, 0.6, 0)
		"MYTHIC":
			return Color(1, 0.84, 0)
		_:
			return Color.WHITE

# Получить звёздочки редкости
func get_rarity_stars(rarity: String) -> String:
	match rarity:
		"COMMON":
			return "⭐"
		"UNCOMMON":
			return "⭐⭐"
		"RARE":
			return "⭐⭐⭐"
		"EPIC":
			return "⭐⭐⭐⭐"
		"LEGENDARY":
			return "⭐⭐⭐⭐⭐"
		"MYTHIC":
			return "⭐⭐⭐⭐⭐⭐"
		_:
			return ""
