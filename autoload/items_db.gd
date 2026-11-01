extends Node

## Каталог предметов (автозагрузка ItemsDB): цвета блоков, аватарки, рамки.
## Темы блоков описаны отдельными ресурсами в res://themes/ (см. ThemeManager).
##
## Поле "unlock" описывает, как предмет открывается — один источник правды для всей игры:
##   {"type": "default"}                              — доступен сразу
##   {"type": "level", "level": 5}                    — награда за достижение уровня
##   {"type": "achievement", "id": "lines", "tier": 2} — награда ступени достижения (см. Achievements)
## Progression сам выдаёт предметы, когда условие выполнено.

# === ЦВЕТА БЛОКОВ ===
# Индексы из Progression.active_colors указывают на этот список (тема «Классика»)

var block_colors = [
	Color.ROYAL_BLUE, Color.RED, Color.GREEN, Color.YELLOW,
	Color.PURPLE, Color.ORANGE, Color.CYAN, Color.PINK,
	Color.LIME_GREEN, Color.MAGENTA, Color.SADDLE_BROWN, Color.TURQUOISE,
	Color.GOLD, Color.CRIMSON, Color.DARK_GREEN, Color(0, 0, 0.5),
	Color.OLIVE, Color.TEAL, Color.CORAL, Color.INDIGO,
	Color(1.0, 0.6, 0.78), Color(0.55, 0.85, 1.0), Color(0.72, 0.55, 1.0), Color(1.0, 0.45, 0.2), Color(0.45, 0.95, 0.65),
]

var color_names = [
	"Синий", "Красный", "Зелёный", "Жёлтый", "Фиолетовый", "Оранжевый", "Голубой", "Розовый",
	"Лайм", "Пурпурный", "Шоколадный", "Бирюзовый", "Золотой", "Малиновый", "Хвойный", "Тёмно-синий",
	"Оливковый", "Морской", "Коралловый", "Индиго",
	"Сакуровый", "Небесный", "Лавандовый", "Лавовый", "Мятный",
]

# Цвета 0–5 доступны сразу, остальные — награды ранних уровней (индекс цвета → уровень)
const COLOR_UNLOCK_LEVELS = {
	6: 2, 7: 4, 8: 6, 9: 9, 10: 11, 11: 13, 12: 14, 13: 16, 14: 19, 15: 21, 16: 22, 17: 23, 18: 27, 19: 29,
	20: 31, 21: 32, 22: 36, 23: 37, 24: 39,
}

# === ЭФФЕКТЫ ОЧИСТКИ ===
# kind — как выглядят частицы, см. ui/effect_painter.gd

var effects_data = {
	1: {"name": "Искры", "rarity": "COMMON", "kind": "sparks",
		"description": "Брызги в цвет темы. С них всё начинается.", "unlock": {"type": "default"}},
	2: {"name": "Конфетти", "rarity": "UNCOMMON", "kind": "confetti",
		"description": "Разноцветные бумажки разлетаются от каждой линии — маленький праздник.", "unlock": {"type": "level", "level": 8}},
	3: {"name": "Звёздочки", "rarity": "UNCOMMON", "kind": "stars",
		"description": "Золотые звёзды поднимаются над полем и мерцают.", "unlock": {"type": "level", "level": 17}},
	4: {"name": "Пузыри", "rarity": "RARE", "kind": "bubbles",
		"description": "Линия растворяется пузырями, как в морской глубине.", "unlock": {"type": "level", "level": 24}},
	5: {"name": "Сердечки", "rarity": "RARE", "kind": "hearts",
		"description": "Каждая очищенная линия — немного любви.", "unlock": {"type": "level", "level": 40}},
	6: {"name": "Пиксели", "rarity": "EPIC", "kind": "pixels",
		"description": "Блоки рассыпаются на крупные пиксели, как в старых играх.", "unlock": {"type": "level", "level": 55}},
	7: {"name": "Радуга", "rarity": "EPIC", "kind": "rainbow",
		"description": "Искры переливаются всеми цветами радуги.", "unlock": {"type": "level", "level": 90}},
	8: {"name": "Фейерверк", "rarity": "LEGENDARY", "kind": "fireworks",
		"description": "Залпы салюта за длинные серии. Для тех, кто не останавливается.",
		"unlock": {"type": "achievement", "id": "streak", "tier": 4}},
	9: {"name": "Лепестки", "rarity": "UNCOMMON", "kind": "petals",
		"description": "Линия осыпается лепестками сакуры.", "unlock": {"type": "level", "level": 14}},
	10: {"name": "Угольки", "rarity": "RARE", "kind": "embers",
		"description": "Раскалённые искры взлетают над полем, как над вулканом.", "unlock": {"type": "level", "level": 47}},
	11: {"name": "Снежинки", "rarity": "EPIC", "kind": "snow",
		"description": "Очищенные клетки рассыпаются снегом.", "unlock": {"type": "level", "level": 72}},
}

# === РАМКИ ===

var frames_data = {
	1: {
		"name": "Бронза",
		"rarity": "COMMON",
		"description": "Простая бронзовая рамка. Отличное начало для каждого новичка!",
		"texture": "res://assets/frames/frame_1.svg",
		"unlock": {"type": "default"},
	},
	2: {
		"name": "Серебро",
		"rarity": "UNCOMMON",
		"description": "Холодный блеск серебра для тех, кто уже освоился на поле.",
		"texture": "res://assets/frames/frame_2.svg",
		"unlock": {"type": "level", "level": 12},
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
	5: {
		"name": "Изумруд",
		"rarity": "UNCOMMON",
		"description": "Зелёный камень для тех, кто уверенно держит поле в порядке.",
		"texture": "res://assets/frames/frame_5.svg",
		"unlock": {"type": "level", "level": 35},
	},
	6: {
		"name": "Рубин",
		"rarity": "RARE",
		"description": "Горячий красный блеск. Видно, что игрок не новичок.",
		"texture": "res://assets/frames/frame_6.svg",
		"unlock": {"type": "level", "level": 60},
	},
	7: {
		"name": "Сапфир",
		"rarity": "RARE",
		"description": "Глубокий синий камень на сотом уровне — серьёзная заявка.",
		"texture": "res://assets/frames/frame_7.svg",
		"unlock": {"type": "level", "level": 100},
	},
	8: {
		"name": "Аметист",
		"rarity": "EPIC",
		"description": "Фиолетовая огранка для настоящих виртуозов.",
		"texture": "res://assets/frames/frame_8.svg",
		"unlock": {"type": "level", "level": 150},
	},
	9: {
		"name": "Обсидиан",
		"rarity": "EPIC",
		"description": "Тёмное вулканическое стекло. Холодно, строго, красиво.",
		"texture": "res://assets/frames/frame_9.svg",
		"unlock": {"type": "level", "level": 250},
	},
	10: {
		"name": "Радуга",
		"rarity": "LEGENDARY",
		"description": "Все цвета блоков сразу. Для тех, кто прошёл больше половины пути.",
		"texture": "res://assets/frames/frame_10.svg",
		"unlock": {"type": "level", "level": 350},
	},
	11: {
		"name": "Алмаз",
		"rarity": "MYTHIC",
		"description": "Высшая награда: 500-й уровень. Таких рамок почти ни у кого нет.",
		"texture": "res://assets/frames/frame_11.svg",
		"unlock": {"type": "level", "level": 500},
	},
	12: {
		"name": "Карамель",
		"rarity": "UNCOMMON",
		"description": "Полосатая, как леденцовая трость. Сладкая награда.",
		"texture": "res://assets/frames/frame_12.svg",
		"unlock": {"type": "level", "level": 26},
	},
	13: {
		"name": "Волна",
		"rarity": "RARE",
		"description": "Морская рамка с гребнями волн.",
		"texture": "res://assets/frames/frame_13.svg",
		"unlock": {"type": "level", "level": 48},
	},
	14: {
		"name": "Дубовая",
		"rarity": "RARE",
		"description": "Крепкая резная рамка из старого дуба.",
		"texture": "res://assets/frames/frame_14.svg",
		"unlock": {"type": "level", "level": 85},
	},
	15: {
		"name": "Пиксельная",
		"rarity": "EPIC",
		"description": "Восемь бит, неоновые грани — привет из аркадного зала.",
		"texture": "res://assets/frames/frame_15.svg",
		"unlock": {"type": "level", "level": 130},
	},
	16: {
		"name": "Сакура",
		"rarity": "UNCOMMON",
		"description": "Розовое кольцо в цветах вишни.",
		"texture": "res://assets/frames/frame_16.svg",
		"unlock": {"type": "level", "level": 16},
	},
	17: {
		"name": "Медовая",
		"rarity": "UNCOMMON",
		"description": "Тёплое золото и соты по краю.",
		"texture": "res://assets/frames/frame_17.svg",
		"unlock": {"type": "level", "level": 24},
	},
	18: {
		"name": "Неон",
		"rarity": "RARE",
		"description": "Две светящиеся трубки, как на вывеске ночного города.",
		"texture": "res://assets/frames/frame_18.svg",
		"unlock": {"type": "level", "level": 34},
	},
	19: {
		"name": "Магма",
		"rarity": "EPIC",
		"description": "Чёрный камень, раскалённые трещины и огненный герб.",
		"texture": "res://assets/frames/frame_19.svg",
		"unlock": {"type": "level", "level": 44},
	},
	20: {
		"name": "Кристальная",
		"rarity": "EPIC",
		"description": "Гранёное кольцо с аметистами и аквамаринами.",
		"texture": "res://assets/frames/frame_20.svg",
		"unlock": {"type": "level", "level": 62},
	},
	21: {
		"name": "Сияние",
		"rarity": "LEGENDARY",
		"description": "Все переливы северного неба в одной рамке.",
		"texture": "res://assets/frames/frame_21.svg",
		"unlock": {"type": "level", "level": 78},
	},
	22: {
		"name": "Огненная",
		"rarity": "EPIC",
		"description": "Языки пламени для мастера бонусов: двести использований.",
		"texture": "res://assets/frames/frame_22.svg",
		"unlock": {"type": "achievement", "id": "bonus", "tier": 3},
	},
	23: {
		"name": "Королевская",
		"rarity": "LEGENDARY",
		"description": "Пурпур, золото и корона. Сто двадцатый уровень — это уже титул.",
		"texture": "res://assets/frames/frame_23.svg",
		"unlock": {"type": "level", "level": 120},
	},
	24: {
		"name": "Галактика",
		"rarity": "MYTHIC",
		"description": "Звёздная россыпь и своя планета. Двухсотый уровень.",
		"texture": "res://assets/frames/frame_24.svg",
		"unlock": {"type": "level", "level": 200},
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
		"description": "Три линии за один ход — и она проносится по небу.",
		"unlock": {"type": "achievement", "id": "triple", "tier": 1},
	},
	13: {
		"name": "Сова",
		"rarity": "UNCOMMON",
		"description": "Не спит по ночам и считает линии. Мудрая птица для мудрых ходов.",
		"unlock": {"type": "level", "level": 20},
	},
	14: {
		"name": "Пингвин",
		"rarity": "RARE",
		"description": "Скользит по полю так же ловко, как по льду.",
		"unlock": {"type": "level", "level": 45},
	},
	15: {
		"name": "Призрак",
		"rarity": "EPIC",
		"description": "Появляется там, где только что исчезла линия. Бу!",
		"unlock": {"type": "level", "level": 80},
	},
	16: {
		"name": "Король блоков",
		"rarity": "LEGENDARY",
		"description": "Корона по праву: триста уровней на поле.",
		"unlock": {"type": "level", "level": 300},
	},
	17: {
		"name": "Кексик",
		"rarity": "UNCOMMON",
		"description": "Пышный крем и вишенка сверху. Сладкоежка со стажем.",
		"unlock": {"type": "level", "level": 25},
	},
	18: {
		"name": "Леденец",
		"rarity": "RARE",
		"description": "Крутится-вертится и всегда в хорошем настроении.",
		"unlock": {"type": "level", "level": 65},
	},
	19: {
		"name": "Рыбка",
		"rarity": "UNCOMMON",
		"description": "Плавает между блоками и ищет свободную клетку.",
		"unlock": {"type": "level", "level": 28},
	},
	20: {
		"name": "Осьминог",
		"rarity": "EPIC",
		"description": "Восемь щупалец — восемь способов выбраться из безнадёжной позиции.",
		"unlock": {"type": "achievement", "id": "clutch", "tier": 2},
	},
	21: {
		"name": "Бобр",
		"rarity": "RARE",
		"description": "Строит плотины из блоков. Аккуратно, ряд к ряду.",
		"unlock": {"type": "level", "level": 42},
	},
	22: {
		"name": "Жёлудь",
		"rarity": "UNCOMMON",
		"description": "Маленький, но упрямый. Из него вырастет дуб.",
		"unlock": {"type": "level", "level": 18},
	},
	23: {
		"name": "Пиксельный пришелец",
		"rarity": "EPIC",
		"description": "Прилетел прямо из игрового автомата.",
		"unlock": {"type": "level", "level": 52},
	},
	24: {
		"name": "Джойстик",
		"rarity": "LEGENDARY",
		"description": "Для тех, кто сыграл двести пятьдесят партий и не собирается останавливаться.",
		"unlock": {"type": "achievement", "id": "games", "tier": 4},
	},
	25: {
		"name": "Панда",
		"rarity": "UNCOMMON",
		"description": "Спокойная, как спокойный режим. Любит бамбук и ровные ряды.",
		"unlock": {"type": "level", "level": 5},
	},
	26: {
		"name": "Пчёлка",
		"rarity": "COMMON",
		"description": "Строит соты так же аккуратно, как вы — линии.",
		"unlock": {"type": "level", "level": 9},
	},
	27: {
		"name": "Грибок",
		"rarity": "UNCOMMON",
		"description": "Вырос после дождя из очищенных линий.",
		"unlock": {"type": "level", "level": 12},
	},
	28: {
		"name": "Дракончик",
		"rarity": "RARE",
		"description": "Пока маленький, но уже умеет пускать искры.",
		"unlock": {"type": "level", "level": 33},
	},
	29: {
		"name": "Ниндзя",
		"rarity": "RARE",
		"description": "Ставит фигуры быстро и бесшумно.",
		"unlock": {"type": "level", "level": 38},
	},
	30: {
		"name": "Снеговик",
		"rarity": "RARE",
		"description": "Пришёл вместе с северным сиянием. Не тает от серий.",
		"unlock": {"type": "level", "level": 58},
	},
	31: {
		"name": "Феникс",
		"rarity": "EPIC",
		"description": "Возрождается после каждой двойной очистки. За сотню комбо из двух и больше линий.",
		"unlock": {"type": "achievement", "id": "multi", "tier": 2},
	},
	32: {
		"name": "Единорог",
		"rarity": "EPIC",
		"description": "Встречается только у очень упорных игроков.",
		"unlock": {"type": "level", "level": 75},
	},
	33: {
		"name": "Волшебник",
		"rarity": "EPIC",
		"description": "Знает, где появится следующая фигура. Почти всегда.",
		"unlock": {"type": "level", "level": 90},
	},
	34: {
		"name": "Самоцвет",
		"rarity": "EPIC",
		"description": "Живой кристалл — для того, кто собрал шесть тем.",
		"unlock": {"type": "achievement", "id": "themes", "tier": 2},
	},
	35: {
		"name": "Манэки-нэко",
		"rarity": "LEGENDARY",
		"description": "Кошка удачи машет лапкой тем, кто неделю выполнял все задания дня.",
		"unlock": {"type": "achievement", "id": "full_day", "tier": 2},
	},
	36: {
		"name": "Астрокот",
		"rarity": "LEGENDARY",
		"description": "Покоритель космоса: приходит вместе с самой красивой темой на сотом уровне.",
		"unlock": {"type": "level", "level": 100},
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

func get_effect_ids() -> Array:
	var ids = effects_data.keys()
	ids.sort()
	return ids

func get_effect_data(effect_id: int) -> Dictionary:
	return effects_data.get(effect_id, effects_data[1])

func get_color_ids() -> Array:
	return range(block_colors.size())

func get_color_unlock(color_index: int) -> Dictionary:
	if COLOR_UNLOCK_LEVELS.has(color_index):
		return {"type": "level", "level": COLOR_UNLOCK_LEVELS[color_index]}
	return {"type": "default"}

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
				var def = achievements.get_definition(unlock.get("id", ""))
				var text = "Достижение «%s»" % def.get("title", "?")
				if def.get("tiers", []).size() > 1:
					text += ", ступень «%s»" % achievements.get_tier_name(unlock.get("tier", 1))
				return text
			return "Награда за достижение"
	return ""

const RARITY_NAMES = {
	"COMMON": "Обычная", "UNCOMMON": "Необычная", "RARE": "Редкая",
	"EPIC": "Эпическая", "LEGENDARY": "Легендарная", "MYTHIC": "Мифическая",
}

func get_rarity_name(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, rarity)

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
