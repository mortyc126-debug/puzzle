extends Node

# === ЦВЕТА БЛОКОВ ===
# Индексы из progression.active_colors указывают на этот список

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
		"name": "Bronze Basic",
		"rarity": "COMMON",
		"description": "Простая бронзовая рамка. Отличное начало для каждого новичка!",
		"stars": 1,
		"unlock_level": 0
	}
	# Остальные рамки (2-18) будут добавлены позже через Battle Pass
}

# === АВАТАРКИ ===

# Файл картинки: res://assets/avatars/avatar_<id>.png
# Пример записи:
# 1: {
# 	"name": "Название",
# 	"rarity": "COMMON",
# 	"description": "Описание",
# 	"stars": 1,
# 	"unlock_level": 0
# }
var avatars_data = {
	# Новые аватарки добавим позже
}

# === ФОНЫ ===

var backgrounds_data = {
	# Добавим позже
}

# === МУЗЫКА ===

var music_data = {
	# Добавим позже
}

# Получить данные предмета
func get_frame_data(frame_id: int) -> Dictionary:
	return frames_data.get(frame_id, {})

func get_avatar_data(avatar_id: int) -> Dictionary:
	return avatars_data.get(avatar_id, {})

func get_background_data(bg_id: int) -> Dictionary:
	return backgrounds_data.get(bg_id, {})

func get_music_data(music_id: int) -> Dictionary:
	return music_data.get(music_id, {})

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
