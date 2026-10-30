extends Control

# Настройки (загружаются/сохраняются)
var sound_enabled = true
var music_enabled = true
var vibration_enabled = true

func _ready():
	# Загружаем настройки
	load_settings()
	
	# Подключаем кнопки
	$BackButton.pressed.connect(_on_back_pressed)
	
	# Подключаем чекбоксы
	$OptionsContainer/SoundOption/SoundCheckbox.toggled.connect(_on_sound_toggled)
	$OptionsContainer/MusicOption/MusicCheckbox.toggled.connect(_on_music_toggled)
	$OptionsContainer/VibrationOption/VibrationCheckbox.toggled.connect(_on_vibration_toggled)
	
	# Обновляем UI
	update_ui()

func update_ui():
	$OptionsContainer/SoundOption/SoundCheckbox.button_pressed = sound_enabled
	$OptionsContainer/MusicOption/MusicCheckbox.button_pressed = music_enabled
	$OptionsContainer/VibrationOption/VibrationCheckbox.button_pressed = vibration_enabled

func _on_sound_toggled(enabled: bool):
	sound_enabled = enabled
	print("🔊 Звуки: ", "ВКЛ" if enabled else "ВЫКЛ")
	save_settings()
	apply_settings()

func _on_music_toggled(enabled: bool):
	music_enabled = enabled
	print("🎵 Музыка: ", "ВКЛ" if enabled else "ВЫКЛ")
	save_settings()
	apply_settings()

func _on_vibration_toggled(enabled: bool):
	vibration_enabled = enabled
	print("📳 Вибрация: ", "ВКЛ" if enabled else "ВЫКЛ")
	save_settings()

func apply_settings():
	# Применяем настройки звука
	var sound_buses = ["Master", "SFX", "Music"]
	for bus_name in sound_buses:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			if bus_name == "Music":
				AudioServer.set_bus_mute(bus_idx, not music_enabled)
			elif bus_name == "SFX":
				AudioServer.set_bus_mute(bus_idx, not sound_enabled)
			elif bus_name == "Master":
				AudioServer.set_bus_mute(bus_idx, not (sound_enabled or music_enabled))

func save_settings():
	var save_data = {
		"sound": sound_enabled,
		"music": music_enabled,
		"vibration": vibration_enabled
	}
	
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("Настройки сохранены")

func load_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()
			
			sound_enabled = save_data.get("sound", true)
			music_enabled = save_data.get("music", true)
			vibration_enabled = save_data.get("vibration", true)
			
			print("Настройки загружены")
			apply_settings()
	else:
		print("Файл настроек не найден, используются значения по умолчанию")

func _on_back_pressed():
	queue_free()
