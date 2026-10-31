class_name EffectPreview
extends Control

## Превью эффекта очистки для профиля и итогов: раз в секунду «взрыв» в центре.

var kind := "sparks"
var color := Color(0.4, 0.6, 1)
var particles: Array = []
var _timer := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)
	clip_contents = true

func setup(effect_kind: String, base_color: Color) -> void:
	kind = effect_kind
	color = base_color
	_timer = 1.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		EffectPainter.burst(particles, kind, size / 2.0, color, 6, minf(size.x, size.y) * 0.45)
	EffectPainter.update(particles, delta)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.16, 0.9))
	EffectPainter.draw(self, particles)
