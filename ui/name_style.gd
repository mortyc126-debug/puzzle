class_name NameStyle
extends RefCounted

## Оформление имени игрока (Progression.name_color / name_glow) и подпись-титул.
## Одна функция для профиля и экрана игры — имя везде выглядит одинаково.

const RAINBOW_SHADER = preload("res://ui/name_rainbow.gdshader")
static var _rainbow: ShaderMaterial

static func apply(label: Label) -> void:
	if label == null:
		return
	var def = Progression.get_name_color_def(Progression.name_color)
	var color: Color = def["color"]
	label.add_theme_color_override("font_color", color)
	if def.get("rainbow", false):
		if _rainbow == null:
			_rainbow = ShaderMaterial.new()
			_rainbow.shader = RAINBOW_SHADER
		label.material = _rainbow
	else:
		label.material = null
	if Progression.name_glow:
		# Свечение: полупрозрачный контур и мягкая тень того же цвета без сдвига
		# Тонкий ореол: при толстом контуре буквы мутнеют (проверено на скриншотах)
		label.add_theme_color_override("font_outline_color", Color(color, 0.3))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_shadow_color", Color(color, 0.22))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("shadow_outline_size", 12)
	else:
		for name in ["font_outline_color", "font_shadow_color"]:
			label.remove_theme_color_override(name)
		for name in ["outline_size", "shadow_offset_x", "shadow_offset_y", "shadow_outline_size"]:
			label.remove_theme_constant_override(name)

static func title_text() -> String:
	return Progression.get_title_name(Progression.player_title)
