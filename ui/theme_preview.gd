class_name ThemePreview
extends Control

## Мини-превью темы для профиля: фон и поле 4×4 с несколькими блоками в стиле темы.

const GRID = 4
const SAMPLE = [
	[-1, -1, 2, -1],
	[0, -1, 2, 3],
	[0, 1, 1, 3],
	[0, -1, 4, 4],
]

var theme_resource: BlockTheme
var locked := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 150)

func set_theme_resource(block_theme: BlockTheme, is_locked: bool) -> void:
	theme_resource = block_theme
	locked = is_locked
	queue_redraw()

func _draw() -> void:
	if theme_resource == null:
		return
	var area = Rect2(Vector2.ZERO, size)
	draw_rect(area, theme_resource.background_color)
	if theme_resource.background_texture:
		draw_texture_rect(theme_resource.background_texture, area, false, Color(1, 1, 1, 0.6))

	var cell = minf(size.x, size.y) * 0.8 / GRID
	var origin = (size - Vector2(cell, cell) * GRID) / 2.0
	BlockRenderer.draw_board(self, Rect2(origin, Vector2(cell, cell) * GRID), theme_resource)
	for y in range(GRID):
		for x in range(GRID):
			var rect = Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var value = SAMPLE[y][x]
			if value < 0:
				BlockRenderer.draw_empty_cell(self, rect, theme_resource)
			else:
				var color = ThemeManager.get_block_color(value, theme_resource)
				BlockRenderer.draw_block(self, rect, color, theme_resource)

	if locked:
		draw_rect(area, Color(0, 0, 0, 0.55))
