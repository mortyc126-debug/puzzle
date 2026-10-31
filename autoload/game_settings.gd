extends Node

## Настройки игрока (автозагрузка GameSettings): звук, музыка, вибрация.
## Шины SFX и Music описаны в default_bus_layout.tres.

const SAVE_PATH = "user://settings.save"

# === ДАННЫЕ ДЛЯ ВЫПУСКА — заполните перед публикацией ===
# Страница игры в магазине (кнопка «Оценить»). Пусто — кнопка не показывается.
const STORE_URL = "https://play.google.com/store/apps/details?id=com.mortyc126.blockpuzzle"
# Почта для отзывов (кнопка «Написать разработчику»). Пусто — кнопка не показывается.
const FEEDBACK_EMAIL = ""

var sound_enabled := true
var music_enabled := true
var vibration_enabled := true
var rated := false  # Игрок уже нажимал «Оценить»

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = file.get_var()
	file.close()
	if data is Dictionary:
		sound_enabled = data.get("sound", true)
		music_enabled = data.get("music", true)
		vibration_enabled = data.get("vibration", true)
		rated = data.get("rated", false)

func save_settings() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({
		"sound": sound_enabled,
		"music": music_enabled,
		"vibration": vibration_enabled,
		"rated": rated,
	})
	file.close()

func apply() -> void:
	_set_bus_mute("SFX", not sound_enabled)
	_set_bus_mute("Music", not music_enabled)

func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	save_settings()
	apply()

func set_music(enabled: bool) -> void:
	music_enabled = enabled
	save_settings()
	apply()

func set_vibration(enabled: bool) -> void:
	vibration_enabled = enabled
	save_settings()

# Короткая вибрация на телефоне. Для Android в настройках экспорта нужно разрешение VIBRATE.
func vibrate(duration_ms: int) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func get_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

func has_store_page() -> bool:
	return STORE_URL != ""

func open_store_page() -> void:
	if not has_store_page():
		return
	rated = true
	save_settings()
	OS.shell_open(STORE_URL)

func has_feedback_email() -> bool:
	return FEEDBACK_EMAIL != ""

func open_feedback_email() -> void:
	if has_feedback_email():
		var subject = "Block Puzzle %s" % get_version()
		OS.shell_open("mailto:%s?subject=%s" % [FEEDBACK_EMAIL, subject.uri_encode()])

func _set_bus_mute(bus_name: String, mute: bool) -> void:
	var index = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_mute(index, mute)
