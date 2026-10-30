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

func _on_vibration_toggled(enabled: bool):
	GameSettings.set_vibration(enabled)
	if enabled:
		GameSettings.vibrate(40)

func _on_back_pressed():
	queue_free()
