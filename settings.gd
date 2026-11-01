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
	ScreenStyle.fit_to_screen(self, 0.25)
	add_footer()

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
	$OptionsContainer.add_child(row)

# Оценка, обратная связь и версия — добавляются кодом под переключателями
func add_links():
	var options = $OptionsContainer
	if GameSettings.has_store_page():
		options.add_child(make_button("Оценить игру", GameSettings.open_store_page, "star"))
	if GameSettings.has_feedback_email():
		options.add_child(make_button("Написать разработчику", GameSettings.open_feedback_email, "edit"))

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
		row.custom_minimum_size = Vector2(0, 76)
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
	credits.add_theme_font_size_override("font_size", 18)
	credits.add_theme_color_override("font_color", Color(0.55, 0.58, 0.75))
	footer.add_child(credits)

func make_button(text: String, action: Callable, icon_name: String = "") -> Button:
	var button = Button.new()
	button.text = text
	if icon_name != "":
		button.icon = load("res://assets/ui/icons/%s.svg" % icon_name)
		button.add_theme_constant_override("icon_max_width", 32)
	button.custom_minimum_size = Vector2(0, 80)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	return button

func _on_vibration_toggled(enabled: bool):
	GameSettings.set_vibration(enabled)
	if enabled:
		GameSettings.vibrate(40)

func _on_back_pressed():
	queue_free()

# Кнопка «Назад» на телефоне (вызывает Game)
func handle_back() -> bool:
	_on_back_pressed()
	return true
