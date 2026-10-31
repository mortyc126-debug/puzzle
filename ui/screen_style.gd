class_name ScreenStyle
extends RefCounted

## Общий вид полноэкранных меню (профиль, настройки): градиентный фон и кнопка «Назад».

const TOP_COLOR = Color(0.11, 0.15, 0.38)
const BOTTOM_COLOR = Color(0.035, 0.045, 0.13)

# Заменяет плоскую заливку фона мягким вертикальным градиентом
static func apply_background(background: ColorRect) -> void:
	if background == null:
		return
	background.color = BOTTOM_COLOR
	var gradient = Gradient.new()
	gradient.set_color(0, TOP_COLOR)
	gradient.set_color(1, BOTTOM_COLOR)
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 0.7)
	texture.width = 64
	texture.height = 256
	var rect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(rect)

static func style_back_button(button: Button) -> void:
	if button == null:
		return
	button.text = "Назад"
	button.icon = load("res://assets/ui/icons/back.svg")
	button.theme_type_variation = &"IconButton"
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_font_size_override("font_size", 24)
	button.custom_minimum_size = Vector2(150, 64)

static func style_title(label: Label, font_size: int = 48) -> void:
	if label == null:
		return
	label.theme_type_variation = &"TitleLabel"
	label.add_theme_font_size_override("font_size", font_size)
