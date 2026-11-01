extends Node

## Звуки интерфейса и наград (автозагрузка Sfx): клик кнопок, монетки, уровень, награда, комбо,
## чистое поле, рекорд, бонусы. Файлы — assets/sounds/<имя>.wav (синтезирует tools/make_sounds.py).
## Всё играет на шине SFX — переключатель «Звуки» в настройках выключает и их.
## Звуки постановки и очистки линий по-прежнему у Game (тема может их подменить).

const NAMES = ["click", "coin", "level_up", "reward", "combo", "perfect", "record",
	"hammer", "rotate", "undo", "shuffle", "invalid"]
const VOICES = 8  # одновременно звучащих звуков

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last_played: Dictionary = {}  # имя -> мс: одинаковые звуки не накладываются в одном кадре

func _ready() -> void:
	for sound_name in NAMES:
		var path = "res://assets/sounds/%s.wav" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
	for i in range(VOICES):
		var player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	# Клик для каждой кнопки игры — без подключения вручную в каждом окне
	get_tree().node_added.connect(_on_node_added)

func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream = _streams.get(sound_name)
	if stream == null:
		return
	var now = Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -1000)) < 40:
		return
	_last_played[sound_name] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

func _on_node_added(node: Node) -> void:
	# Узел может войти в дерево повторно (перенос в другой контейнер) — подключаем один раз
	if node is BaseButton and not node.has_meta("silent") and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play("click", randf_range(0.96, 1.04), -6.0)
