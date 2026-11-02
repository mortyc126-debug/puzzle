extends Control

## Экран настроек. Сами настройки хранит и применяет автозагрузка GameSettings.

func _ready():
	$BackButton.pressed.connect(_on_back_pressed)
	ScreenStyle.apply_background($Background)
	ScreenStyle.style_back_button($BackButton)
	ScreenStyle.style_title($Background/TitleLabel)

	var sound = $OptionsContainer/SoundOption/SoundCheckbox
	var music = $OptionsContainer/MusicOption/MusicCheckbox
	var vibration = $OptionsContainer/VibrationOption/VibrationCheckbox

	# Сначала выставляем состояние, потом подключаем — иначе сработают обработчики
	sound.button_pressed = GameSettings.sound_enabled
	music.button_pressed = GameSettings.music_enabled
	vibration.button_pressed = GameSettings.vibration_enabled

	sound.toggled.connect(GameSettings.set_sound)
	music.toggled.connect(GameSettings.set_music)
	vibration.toggled.connect(_on_vibration_toggled)

	# Музыки в игре пока нет — переключатель вернётся вместе с ней
	$OptionsContainer/MusicOption.visible = false

	add_zen_toggle()
	add_links()
	make_cards()
	add_section_headers()
	ScreenStyle.fit_to_screen(self, 0.25)
	add_footer()
	center_options.call_deferred()

# Спокойный режим: переключатель добавляется кодом под остальными
func add_zen_toggle():
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = "Спокойный режим\nбез проигрыша, со следующей партии"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 26)
	row.add_child(label)
	var toggle = CheckButton.new()
	toggle.button_pressed = GameSettings.zen_mode
	toggle.toggled.connect(GameSettings.set_zen_mode)
	row.add_child(toggle)
	row.name = "ZenOption"
	$OptionsContainer.add_child(row)

# «Как играть», оценка и обратная связь — добавляются кодом под переключателями
func add_links():
	var options = $OptionsContainer
	var rules = make_button("Как играть", show_rules, "help")
	rules.name = "RulesButton"
	options.add_child(rules)
	var first_more: Button = null
	if GameSettings.has_store_page():
		first_more = make_button("Оценить игру", GameSettings.open_store_page, "star")
		options.add_child(first_more)
	if GameSettings.has_feedback_email():
		var mail = make_button("Написать разработчику", GameSettings.open_feedback_email, "edit")
		options.add_child(mail)
		if first_more == null:
			first_more = mail
	var privacy = make_button("Конфиденциальность", show_privacy, "lock")
	options.add_child(privacy)
	if first_more == null:
		first_more = privacy
	first_more.name = "MoreStart"

# Разделы с подписями: настройки читаются группами, а не списком разнородных кнопок
func add_section_headers():
	var options: VBoxContainer = $OptionsContainer
	var anchors = [
		[options.find_child("SoundOption", true, false), "ЗВУК И ОТКЛИК"],
		[options.find_child("ZenOption", true, false), "ИГРА"],
		[options.find_child("MoreStart", true, false), "ЕЩЁ"],
	]
	for pair in anchors:
		var target: Control = pair[0]
		if target == null:
			continue
		# Переключатели после make_cards() лежат в карточках — заголовок ставится перед карточкой
		var holder: Control = target if target.get_parent() == options else target.get_parent()
		var header = Label.new()
		header.text = pair[1]
		header.theme_type_variation = &"CaptionLabel"
		header.add_theme_font_size_override("font_size", 22)
		header.custom_minimum_size = Vector2(0, 44)
		header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		options.add_child(header)
		options.move_child(header, holder.get_index())

# Блок настроек — по центру между заголовком и подписью внизу, а не прижат к верху
func center_options():
	var options: VBoxContainer = $OptionsContainer
	var height = options.get_combined_minimum_size().y
	var top = $BackButton.position.y + 110.0
	var bottom = get_viewport_rect().size.y - 140.0
	var y = top + maxf((bottom - top - height) * 0.4, 0.0)
	options.offset_top = y
	options.offset_bottom = y + height

# Переключатели — карточками на всю ширину: крупная цель для пальца, ровная сетка
func make_cards():
	var options: VBoxContainer = $OptionsContainer
	options.offset_left = 60
	options.offset_right = 840
	options.add_theme_constant_override("separation", 16)
	for row in options.get_children():
		if not row is HBoxContainer:
			continue
		var index = row.get_index()
		var card = PanelContainer.new()
		card.theme_type_variation = &"HudPanel"
		card.visible = row.visible
		options.remove_child(row)
		card.add_child(row)
		options.add_child(card)
		options.move_child(card, index)
		row.custom_minimum_size = Vector2(0, 84)
		for child in row.get_children():
			if child is Label:
				child.custom_minimum_size = Vector2.ZERO
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# Версия и лицензия шрифтов — внизу экрана, не мешают настройкам
func add_footer():
	var footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -110
	footer.offset_bottom = -36
	footer.offset_left = 40
	footer.offset_right = -40

	var version = Label.new()
	version.text = "Версия %s" % GameSettings.get_version()
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 22)
	version.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85))
	footer.add_child(version)

	var credits = Label.new()
	credits.text = "Шрифты Russo One и Rubik — SIL Open Font License 1.1"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.add_theme_font_size_override("font_size", 20)
	credits.add_theme_color_override("font_color", Color(0.55, 0.58, 0.75))
	footer.add_child(credits)

func make_button(text: String, action: Callable, icon_name: String = "") -> Button:
	var button = Button.new()
	button.text = text
	if icon_name != "":
		button.icon = load("res://assets/ui/icons/%s.svg" % icon_name)
		button.add_theme_constant_override("icon_max_width", 32)
	button.custom_minimum_size = Vector2(0, 84)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	return button

func _on_vibration_toggled(enabled: bool):
	GameSettings.set_vibration(enabled)
	if enabled:
		GameSettings.vibrate(40)

func _on_back_pressed():
	queue_free()

# Кнопка «Назад» на телефоне (вызывает Game): сначала закрывает правила, потом настройки
func handle_back() -> bool:
	if rules_overlay != null and is_instance_valid(rules_overlay):
		close_rules()
		return true
	_on_back_pressed()
	return true

# === КАК ИГРАТЬ ===
# Правила одним экраном: игроки спрашивали, что значат «×3» у счёта, цены на кнопках
# и откуда берутся монеты. [значок, заголовок, текст]
const RULES = [
	["layers", "Фигуры", "Перетащите фигуру из нижнего ряда на поле. Когда поставлены все три, приходят новые. Партия заканчивается, когда ни одна фигура не помещается."],
	["sparkle", "Линии", "Заполненный ряд или столбец исчезает и даёт очки. Несколько линий одним ходом — комбо, очков намного больше. Пустое поле после очистки — ещё +300."],
	["flame", "Серия", "Очищайте линии ход за ходом — очки за линии растут, до ×4. Плашка «Серия ×3» у счёта — третья очистка подряд. Три хода без линий — серия сгорает."],
	["coin", "Монеты", "Монеты дают в конце партии за очки — плашка «Монеты ×2» у счёта показывает множитель. Ещё монеты дают за новые уровни, задания и награду дня."],
	["hammer", "Бонусы за монеты", "Кнопки над нижней строкой. Молоток (10) убирает одну клетку, поворот (15) поворачивает фигуру, новые фигуры (30) меняют весь набор, отмена (20) возвращает последний ход."],
	["tasks", "Задания дня", "Три задания каждый день за монеты и опыт. Прогресс засчитывается в конце партии. Чем выше уровень, тем больше цели и награды."],
	["trophy", "Уровни и награды", "Опыт дают за линии и очки. На новых уровнях открываются аватарки, рамки, темы и эффекты — весь путь наград в профиле. Закрытое можно купить за монеты."],
	["restart", "Продолжить", "Если фигуры не помещаются, партию можно продолжить за монеты — придут новые фигуры. В первых двух партиях — бесплатно."],
	["zen", "Спокойный режим", "Проиграть нельзя: когда фигуры не помещаются, поле освобождается. Монет за очки вдвое меньше, рекорд — свой. Включается здесь, в настройках."],
]

var rules_overlay: Control = null

const PRIVACY = [
	["lock", "Ничего не собираем", "Игра работает без интернета. В ней нет рекламы, аналитики, учётных записей и сторонних сервисов, и никакие данные никуда не отправляются."],
	["user", "Прогресс — на телефоне", "Уровень, монеты, рекорды, предметы и настройки хранятся на вашем устройстве. Если включено резервное копирование Google, Android сохранит их в вашем аккаунте и перенесёт на новый телефон — у разработчика доступа к копии нет."],
	["settings", "Разрешения", "Только вибрация — для отклика в игре. Её можно выключить выше, в разделе «Звук и отклик»."],
]

func show_privacy():
	show_info_page("КОНФИДЕНЦИАЛЬНОСТЬ", PRIVACY, false)

func show_rules():
	show_info_page("КАК ИГРАТЬ", RULES, true)

# Страница поверх настроек: заголовок, «Назад» и карточки [значок, заголовок, текст]
func show_info_page(page_title: String, entries: Array, with_tips_button: bool):
	var overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.13)  # непрозрачно: настройки под страницей не просвечивают
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_overlay = overlay

	var view = get_viewport_rect().size
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.position = Vector2(floorf((view.x - 820) / 2.0), 40)
	column.size = Vector2(820, view.y - 80)
	overlay.add_child(column)

	var header = HBoxContainer.new()
	var back = Button.new()
	ScreenStyle.style_back_button(back)
	back.pressed.connect(close_rules)
	header.add_child(back)
	var title = Label.new()
	title.text = page_title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ScreenStyle.style_title(title, 44 if page_title.length() <= 12 else 32)
	header.add_child(title)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	header.add_child(spacer)
	column.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	for rule in entries:
		var card = PanelContainer.new()
		card.theme_type_variation = &"HudPanel"
		list.add_child(card)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var picture = TextureRect.new()
		picture.texture = load("res://assets/ui/icons/%s.svg" % rule[0])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(44, 44)
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		picture.modulate = Color(1, 0.81, 0.29)
		row.add_child(picture)
		var texts = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 4)
		row.add_child(texts)
		var heading = Label.new()
		heading.text = rule[1]
		heading.theme_type_variation = &"DisplayLabel"
		heading.add_theme_font_size_override("font_size", 28)
		heading.add_theme_color_override("font_color", Color(1, 0.81, 0.29))
		texts.add_child(heading)
		var body = Label.new()
		body.text = rule[2]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(640, 0)
		body.add_theme_font_size_override("font_size", 24)
		body.add_theme_color_override("font_color", Color(0.88, 0.9, 1))
		texts.add_child(body)

	if not with_tips_button:
		return
	var tips = make_button("Показать подсказки снова", func():
		GameSettings.reset_tips()
		tips_done.text = "Подсказки появятся снова во время игры", "sparkle")
	list.add_child(tips)
	tips_done = Label.new()
	tips_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips_done.add_theme_font_size_override("font_size", 22)
	tips_done.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	list.add_child(tips_done)

var tips_done: Label

func close_rules():
	if rules_overlay != null and is_instance_valid(rules_overlay):
		rules_overlay.queue_free()
	rules_overlay = null
