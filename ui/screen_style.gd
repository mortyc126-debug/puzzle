class_name ScreenStyle
extends RefCounted

## Общий вид полноэкранных меню (профиль, настройки): градиентный фон и кнопка «Назад».

const DESIGN_SIZE = Vector2(900, 1600)
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

# Экран телефона обычно длиннее макета 900×1600 (project.godot: stretch aspect = expand).
# Элементы макета сдвигаются: по горизонтали — к центру, по вертикали — на долю top_share
# от лишней высоты. stretch (вкладки профиля) вытягивается вниз на освободившееся место.
static func fit_to_screen(root: Control, top_share: float = 0.5, stretch: Control = null) -> void:
	var view_size = root.get_viewport_rect().size
	var extra = Vector2(maxf(view_size.x - DESIGN_SIZE.x, 0.0), maxf(view_size.y - DESIGN_SIZE.y, 0.0))
	var shift = Vector2(floorf(extra.x / 2.0), floorf(extra.y * top_share))
	for child in root.get_children():
		if child is Control and child.name != "Background":
			child.position += shift
	var background = root.get_node_or_null("Background")
	if background:
		for child in background.get_children():
			if child is Control and not child is TextureRect:
				child.position += shift
	if stretch:
		stretch.size.y += extra.y * (1.0 - 2.0 * top_share)

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
