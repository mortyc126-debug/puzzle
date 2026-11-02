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
	6: 3, 7: 4, 8: 6, 9: 9, 10: 11, 11: 13, 12: 14, 13: 16, 14: 19, 15: 21, 16: 22, 17: 23, 18: 27, 19: 29,
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
	12: {"name": "Монетки", "rarity": "UNCOMMON", "kind": "coins",
		"description": "Из каждой клетки выпрыгивает крутящаяся монетка. Звенит даже без звука.", "unlock": {"type": "level", "level": 29}},
	13: {"name": "Ударная волна", "rarity": "RARE", "kind": "shockwave",
		"description": "От клеток разбегаются кольца, как от удара по воде.", "unlock": {"type": "level", "level": 38}},
	14: {"name": "Осколки", "rarity": "RARE", "kind": "shards",
		"description": "Блоки раскалываются на треугольные осколки, и те кувыркаясь падают.", "unlock": {"type": "level", "level": 66}},
	15: {"name": "Молнии", "rarity": "EPIC", "kind": "lightning",
		"description": "Ветвистые разряды бьют из каждой клетки — линия уходит с треском.", "unlock": {"type": "level", "level": 105}},
	16: {"name": "Ноты", "rarity": "UNCOMMON", "kind": "notes",
		"description": "Линия звучит: вверх улетают разноцветные ноты.", "unlock": {"type": "level", "level": 125}},
	17: {"name": "Бабочки", "rarity": "EPIC", "kind": "butterflies",
		"description": "Из очищенных клеток вспархивают бабочки и улетают, помахивая крыльями.", "unlock": {"type": "level", "level": 155}},
	18: {"name": "Чёрная дыра", "rarity": "LEGENDARY", "kind": "blackhole",
		"description": "Клетку затягивает в крошечную воронку: искры закручиваются по спирали и исчезают.",
		"unlock": {"type": "level", "level": 400}},
	19: {"name": "Золотая пыль", "rarity": "LEGENDARY", "kind": "golddust",
		"description": "Королевская награда: клетки рассыпаются золотыми блёстками. Только за «Золотую коллекцию».",
		"unlock": {"type": "achievement", "id": "golden", "tier": 3}},
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
	# Только за достижения — не продаются: цель для тех, кто уже собрал всё остальное
	25: {
		"name": "Лавровая",
		"rarity": "LEGENDARY",
		"description": "Золото и лавры за тридцать пройденных испытаний дня. Купить нельзя — только заслужить.",
		"texture": "res://assets/frames/frame_25.svg",
		"unlock": {"type": "achievement", "id": "challenge_days", "tier": 3},
	},
	26: {
		"name": "Сокровищница",
		"rarity": "EPIC",
		"description": "Корона и россыпь камней для того, кто довёл до золота пять аватарок или рамок.",
		"texture": "res://assets/frames/frame_26.svg",
		"unlock": {"type": "achievement", "id": "golden", "tier": 2},
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
		"unlock": {"type": "level", "level": 2},
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
	37: {
		"name": "Чемпион",
		"rarity": "EPIC",
		"description": "Кубок для победителя пяти воскресных испытаний — самых трудных за неделю.",
		"unlock": {"type": "achievement", "id": "sunday", "tier": 2},
	},
	38: {
		"name": "Календарик",
		"rarity": "RARE",
		"description": "Семь зелёных точек подряд: неделя испытаний дня без единого пропуска.",
		"unlock": {"type": "achievement", "id": "challenge_streak", "tier": 2},
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

# Кубики: вид блоков поверх любой темы (фон и поле остаются от темы). 0 — «Как в теме».
# style — BlockTheme.BlockStyle, radius — скругление для клетки 80 px, glow — сила свечения.
# Цвета берутся из темы (в «Классике» — из вкладки «Цвета»).
var skins_data = {
	1: {"name": "Желе", "rarity": "UNCOMMON", "style": BlockTheme.BlockStyle.JELLY, "radius": 12.0, "glow": 0.5,
		"description": "Полупрозрачные и упругие на вид, с пузырьками внутри.", "unlock": {"type": "level", "level": 18}},
	2: {"name": "Аниме", "rarity": "RARE", "style": BlockTheme.BlockStyle.ANIME, "radius": 9.0, "glow": 0.5,
		"description": "Как в мультфильме: чёткий контур, тень ячейкой, блик и искорка.", "unlock": {"type": "level", "level": 33}},
	3: {"name": "Неон", "rarity": "RARE", "style": BlockTheme.BlockStyle.NEON, "radius": 10.0, "glow": 0.9,
		"description": "Светящиеся трубки, как вывески ночью. Лучше всего — на тёмных темах.", "unlock": {"type": "level", "level": 48}},
	4: {"name": "Объём", "rarity": "UNCOMMON", "style": BlockTheme.BlockStyle.CUBE3D, "radius": 0.0, "glow": 0.5,
		"description": "Настоящие кубики с гранями: свет сверху и слева, тень справа и снизу.", "unlock": {"type": "level", "level": 64}},
	5: {"name": "Милашки", "rarity": "RARE", "style": BlockTheme.BlockStyle.KAWAII, "radius": 12.0, "glow": 0.5,
		"description": "У каждого кубика глазки, улыбка и румянец. Убирать линии немного жалко.", "unlock": {"type": "level", "level": 110}},
	6: {"name": "Киберпанк", "rarity": "EPIC", "style": BlockTheme.BlockStyle.CYBER, "radius": 6.0, "glow": 0.6,
		"description": "Тёмные панели со срезанными углами, неоновая кромка и дорожки микросхем.", "unlock": {"type": "level", "level": 120}},
	7: {"name": "Конструктор", "rarity": "UNCOMMON", "style": BlockTheme.BlockStyle.BRICK, "radius": 8.0, "glow": 0.5,
		"description": "Детальки с круглой кнопкой — так и хочется собрать из них домик.", "unlock": {"type": "level", "level": 140}},
	8: {"name": "Лёд", "rarity": "EPIC", "style": BlockTheme.BlockStyle.FROST, "radius": 8.0, "glow": 0.5,
		"description": "Холодные прозрачные блоки с инеем в уголке и тонкими трещинками.", "unlock": {"type": "level", "level": 175}},
	9: {"name": "Голограмма", "rarity": "LEGENDARY", "style": BlockTheme.BlockStyle.HOLO, "radius": 8.0, "glow": 0.7,
		"description": "Блоки из света: просвечивают, мерцают строками развёртки и отливают голубым и розовым.",
		"unlock": {"type": "level", "level": 225}},
	10: {"name": "Звёздные", "rarity": "LEGENDARY", "style": BlockTheme.BlockStyle.GALAXY, "radius": 10.0, "glow": 0.6,
		"description": "В каждом кубике — кусочек космоса: туманность и звёзды.", "unlock": {"type": "level", "level": 300}},
}

# Окраски: цвета блоков поверх темы. Элемент colors — цвет или [верх, низ] (градиент внутри блока),
# rim — кайма (золотая у «Королевской»). Палитры собраны по модным и классическим наборам:
# королевские камни (аметист, рубин #DC143C, сапфир #0F52BA, изумруд #50C878, золото #D4AF37),
# «авроровые» градиенты (бирюза #06B6D4 → индиго #6366F1 → маджента #EC4899), закатные (#FF6B6B, #FF9F68, #FFD56B).
var paints_data = {
	1: {"name": "Пастель", "rarity": "UNCOMMON", "unlock": {"type": "level", "level": 21},
		"description": "Мягкие пастельные тона: розовый, мятный, персиковый, лавандовый.",
		"colors": [Color(1.000, 0.702, 0.776), Color(0.627, 0.906, 0.898), Color(1.000, 0.855, 0.757), Color(0.710, 0.725, 1.000), Color(0.992, 0.992, 0.588), Color(0.765, 0.694, 0.882)]},
	2: {"name": "Закат", "rarity": "RARE", "unlock": {"type": "level", "level": 36},
		"description": "Градиенты заката: коралл в персик, мандарин в розу, сирень в фуксию.",
		"colors": [[Color(1.000, 0.420, 0.420), Color(1.000, 0.624, 0.408)], [Color(1.000, 0.624, 0.408), Color(1.000, 0.835, 0.420)], [Color(0.976, 0.271, 0.353), Color(0.710, 0.090, 0.620)], [Color(0.941, 0.502, 0.149), Color(0.969, 0.373, 0.290)], [Color(1.000, 0.835, 0.420), Color(1.000, 0.420, 0.420)], [Color(0.780, 0.490, 1.000), Color(1.000, 0.561, 0.671)]]},
	3: {"name": "Неоновая", "rarity": "RARE", "unlock": {"type": "level", "level": 44},
		"description": "Кислотные цвета вывесок: зелёный, розовый, синий, жёлтый, оранжевый, фиолетовый.",
		"colors": [Color(0.224, 1.000, 0.078), Color(1.000, 0.063, 0.941), Color(0.122, 0.318, 1.000), Color(1.000, 1.000, 0.200), Color(1.000, 0.373, 0.122), Color(0.737, 0.075, 0.996)]},
	4: {"name": "Северное сияние", "rarity": "EPIC", "unlock": {"type": "level", "level": 57},
		"description": "Модные «авроровые» градиенты: бирюза в индиго, индиго в маджента, мята в бирюзу.",
		"colors": [[Color(0.133, 0.827, 0.933), Color(0.388, 0.400, 0.945)], [Color(0.388, 0.400, 0.945), Color(0.925, 0.282, 0.600)], [Color(0.655, 0.953, 0.816), Color(0.133, 0.827, 0.933)], [Color(0.427, 0.259, 0.780), Color(0.925, 0.282, 0.600)], [Color(0.024, 0.714, 0.831), Color(0.063, 0.725, 0.506)], [Color(0.545, 0.361, 0.965), Color(0.231, 0.510, 0.965)]]},
	5: {"name": "Королевская", "rarity": "LEGENDARY", "unlock": {"type": "level", "level": 82}, "rim": Color(0.831, 0.686, 0.216),
		"description": "Камни короны в золотой оправе: аметист, рубин, сапфир, изумруд, золото и жемчуг.",
		"colors": [[Color(0.608, 0.420, 0.878), Color(0.294, 0.102, 0.478)], [Color(0.949, 0.251, 0.373), Color(0.545, 0.039, 0.133)], [Color(0.239, 0.482, 0.910), Color(0.039, 0.180, 0.451)], [Color(0.369, 0.839, 0.561), Color(0.055, 0.361, 0.227)], [Color(1.000, 0.898, 0.541), Color(0.722, 0.525, 0.043)], [Color(1.000, 0.965, 0.902), Color(0.831, 0.769, 0.659)]]},
	6: {"name": "Мороженое", "rarity": "UNCOMMON", "unlock": {"type": "level", "level": 96},
		"description": "Сливочные градиенты: клубника, фисташка, черника, манго, мята, ваниль.",
		"colors": [[Color(1.000, 0.820, 0.863), Color(1.000, 0.561, 0.671)], [Color(0.890, 0.976, 0.788), Color(0.576, 0.773, 0.447)], [Color(0.839, 0.894, 1.000), Color(0.482, 0.612, 1.000)], [Color(1.000, 0.945, 0.722), Color(1.000, 0.702, 0.278)], [Color(0.835, 1.000, 0.941), Color(0.361, 0.839, 0.690)], [Color(1.000, 0.992, 0.949), Color(0.953, 0.878, 0.710)]]},
	7: {"name": "Металлы", "rarity": "EPIC", "unlock": {"type": "level", "level": 135}, "rim": Color(1.000, 1.000, 1.000),
		"description": "Полированные слитки: золото, серебро, бронза, розовое золото, медь и платина.",
		"colors": [[Color(1.000, 0.945, 0.659), Color(0.788, 0.604, 0.118)], [Color(0.957, 0.965, 0.980), Color(0.604, 0.639, 0.698)], [Color(0.941, 0.698, 0.478), Color(0.549, 0.353, 0.169)], [Color(0.969, 0.784, 0.753), Color(0.718, 0.431, 0.475)], [Color(0.969, 0.635, 0.420), Color(0.639, 0.314, 0.165)], [Color(0.910, 0.941, 0.973), Color(0.561, 0.635, 0.722)]]},
	8: {"name": "Океанская", "rarity": "RARE", "unlock": {"type": "level", "level": 165},
		"description": "Все оттенки моря: от отмели до глубины.",
		"colors": [[Color(0.498, 0.859, 1.000), Color(0.000, 0.455, 0.851)], [Color(0.224, 0.800, 0.800), Color(0.000, 0.427, 0.467)], [Color(0.702, 0.898, 0.988), Color(0.310, 0.765, 0.969)], [Color(0.565, 0.878, 0.937), Color(0.000, 0.467, 0.714)], [Color(0.282, 0.792, 0.894), Color(0.012, 0.016, 0.369)], [Color(0.180, 0.769, 0.714), Color(0.043, 0.235, 0.365)]]},
	9: {"name": "Осенняя", "rarity": "UNCOMMON", "unlock": {"type": "level", "level": 185},
		"description": "Тёплая осень: ржавчина, горчица, олива, бордо, терракота и тыква.",
		"colors": [Color(0.718, 0.278, 0.165), Color(0.882, 0.678, 0.004), Color(0.439, 0.510, 0.220), Color(0.502, 0.000, 0.125), Color(0.886, 0.447, 0.357), Color(1.000, 0.459, 0.094)]},
	10: {"name": "Радужная", "rarity": "EPIC", "unlock": {"type": "level", "level": 200},
		"description": "Каждый блок — переход между соседними цветами радуги.",
		"colors": [[Color(1.000, 0.231, 0.231), Color(1.000, 0.624, 0.110)], [Color(1.000, 0.624, 0.110), Color(1.000, 0.882, 0.302)], [Color(1.000, 0.882, 0.302), Color(0.239, 0.863, 0.518)], [Color(0.239, 0.863, 0.518), Color(0.133, 0.827, 0.933)], [Color(0.231, 0.510, 0.965), Color(0.545, 0.361, 0.965)], [Color(0.545, 0.361, 0.965), Color(1.000, 0.310, 0.722)]]},
	11: {"name": "Нуар", "rarity": "RARE", "unlock": {"type": "level", "level": 450},
		"description": "Чёрно-белое кино и один алый акцент.",
		"colors": [[Color(0.353, 0.353, 0.353), Color(0.102, 0.102, 0.102)], [Color(0.604, 0.604, 0.604), Color(0.290, 0.290, 0.290)], [Color(0.878, 0.878, 0.878), Color(0.541, 0.541, 0.541)], [Color(1.000, 0.180, 0.302), Color(0.545, 0.000, 0.086)], [Color(0.227, 0.227, 0.227), Color(0.000, 0.000, 0.000)], [Color(0.784, 0.784, 0.784), Color(0.431, 0.431, 0.431)]]},
}

# Фоны: живой фон поверх любой темы (поле, блоки и цвета остаются от темы). 0 — «Как в теме».
# scene — сцена фона (res://backdrops/<id>/), color — цвет под фоном и в превью, пока сцена грузится.
# Идеи взяты из трендов: меш-градиенты (размытые пятна, «аврора»), королевский пурпур с золотом,
# изумруд с золотом в стиле ар-деко, ретро-синтвейв.
var backdrops_data = {
	1: {"name": "Тёплый градиент", "rarity": "UNCOMMON", "unlock": {"type": "level", "level": 27},
		"description": "Модный меш-градиент: коралл, персик, золото и капля неба медленно перетекают друг в друга.",
		"scene": "res://backdrops/mesh_warm/mesh_warm.tscn", "color": Color(0.85, 0.4, 0.5)},
	2: {"name": "Аврора", "rarity": "RARE", "unlock": {"type": "level", "level": 50},
		"description": "Светящиеся пятна бирюзы, индиго и мадженты дрейфуют по ночному небу.",
		"scene": "res://backdrops/mesh_aurora/mesh_aurora.tscn", "color": Color(0.07, 0.07, 0.18)},
	3: {"name": "Лава-лампа", "rarity": "UNCOMMON", "unlock": {"type": "level", "level": 68},
		"description": "Тёплые капли неторопливо всплывают и опускаются — как в лампе из семидесятых.",
		"scene": "res://backdrops/lava_lamp/lava_lamp.tscn", "color": Color(0.32, 0.06, 0.19)},
	4: {"name": "Синтвейв", "rarity": "EPIC", "unlock": {"type": "level", "level": 88},
		"description": "Ретро-закат: полосатое солнце и неоновая сетка, бегущая к горизонту.",
		"scene": "res://backdrops/synthwave/synthwave.tscn", "color": Color(0.12, 0.0, 0.22)},
	5: {"name": "Фонарики", "rarity": "RARE", "unlock": {"type": "level", "level": 115},
		"description": "Бумажные фонарики поднимаются в ночное небо и отражаются в воде.",
		"scene": "res://backdrops/lanterns/lanterns.tscn", "color": Color(0.1, 0.08, 0.2)},
	6: {"name": "Изумрудный зал", "rarity": "EPIC", "unlock": {"type": "level", "level": 145},
		"description": "Глубокий изумруд и золотые веера ар-деко, по стене скользит блик.",
		"scene": "res://backdrops/emerald/emerald.tscn", "color": Color(0.07, 0.3, 0.24)},
	7: {"name": "Чёрный мрамор", "rarity": "RARE", "unlock": {"type": "level", "level": 190},
		"description": "Тёмный полированный камень с белыми и золотыми прожилками.",
		"scene": "res://backdrops/marble/marble.tscn", "color": Color(0.07, 0.07, 0.08)},
	8: {"name": "Королевский бархат", "rarity": "LEGENDARY", "unlock": {"type": "level", "level": 275},
		"description": "Пурпурный бархат, золотая решётка с жемчугом, корона и оседающие блёстки.",
		"scene": "res://backdrops/royal/royal.tscn", "color": Color(0.25, 0.05, 0.37)},
}

func get_backdrop_ids() -> Array:
	var ids = backdrops_data.keys()
	ids.sort()
	return ids

func get_backdrop_data(backdrop_id: int) -> Dictionary:
	return backdrops_data.get(backdrop_id, {})

func get_paint_ids() -> Array:
	var ids = paints_data.keys()
	ids.sort()
	return ids

func get_paint_data(paint_id: int) -> Dictionary:
	return paints_data.get(paint_id, {})

func get_skin_ids() -> Array:
	var ids = skins_data.keys()
	ids.sort()
	return ids

func get_skin_data(skin_id: int) -> Dictionary:
	return skins_data.get(skin_id, {})

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

# === УЛУЧШЕННЫЕ ВЕРСИИ (СИЯЮЩАЯ / ЗОЛОТАЯ) ===

const SHINE_SHADER = preload("res://ui/item_shine.gdshader")
var _shine_materials = {}

# Блеск для картинки аватарки или рамки по её ступени (Progression.item_tiers).
# Материалы общие для всех картинок одной ступени — сотня карточек не создаёт сотню материалов.
# phase сдвигает блик, чтобы аватарка и рамка не мигали строго одновременно.
func style_item_rect(rect: CanvasItem, item_type: String, item_id: int, tier: int = -1) -> void:
	if rect == null:
		return
	if tier < 0:
		tier = Progression.get_item_tier(item_type, item_id)
	if tier <= 0:
		rect.material = null
		return
	var key = "%s:%d" % [item_type, tier]
	if not _shine_materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = SHINE_SHADER
		material.set_shader_parameter("tier", float(tier))
		# Рамка уходит в золото сильно, аватарка — только теплеет: лицо должно остаться узнаваемым
		var gold = 0.0
		if tier >= 2:
			gold = 0.75 if item_type == "frame" else 0.28
		material.set_shader_parameter("gold_mix", gold)
		material.set_shader_parameter("phase", 0.0 if item_type == "frame" else 0.5)
		_shine_materials[key] = material
	rect.material = _shine_materials[key]
