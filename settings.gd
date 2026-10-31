extends Control

## Экран настроек. Сами настройки хранит и применяет автозагрузка GameSettings.

func _ready():
	$BackButton.pressed.connect(_on_back_pressed)

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

	add_zen_toggle()
	add_links()

# Спокойный режим: переключатель добавляется кодом под остальными
func add_zen_toggle():
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = "🧘 Спокойный режим\nбез проигрыша, со следующей партии"
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
		options.add_child(make_button("⭐ Оценить игру", GameSettings.open_store_page))
	if GameSettings.has_feedback_email():
		options.add_child(make_button("✉️ Написать разработчику", GameSettings.open_feedback_email))

	var version = Label.new()
	version.text = "Версия %s" % GameSettings.get_version()
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 22)
	version.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85))
	options.add_child(version)

func make_button(text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
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
