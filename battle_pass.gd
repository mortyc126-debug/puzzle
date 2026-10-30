extends Control

## Экран Battle Pass: награды за уровни. Монеты и слоты задаёт Progression.level_rewards,
## предметы за уровень — поле "unlock" у аватарок, рамок и тем.

const LEVELS_SHOWN = 50

var progression = null

func _ready():
	progression = Progression
	$BackButton.pressed.connect(_on_back_pressed)
	update_ui()
	populate_rewards()

func update_ui():
	$ProgressLabel.text = "Level %d • %d / %d XP • 💰 %d" % [
		progression.current_level,
		progression.current_xp,
		progression.get_xp_for_next_level(),
		progression.total_coins
	]

func populate_rewards():
	for child in $RewardsScroll/RewardsList.get_children():
		child.queue_free()
	for level in range(1, LEVELS_SHOWN + 1):
		create_reward_item(level)

func create_reward_item(level: int):
	var lines = progression.get_level_reward_lines(level)
	if lines.is_empty():
		return

	var is_unlocked = level <= progression.current_level
	var has_item = lines.size() > 1 or not (lines[0].begins_with("💰") or lines[0].begins_with("⭐"))

	var item = HBoxContainer.new()
	item.custom_minimum_size = Vector2(760, 64)

	var level_label = Label.new()
	level_label.custom_minimum_size = Vector2(80, 64)
	level_label.text = str(level)
	level_label.add_theme_font_size_override("font_size", 32)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if is_unlocked else Color(0.5, 0.5, 0.5))
	item.add_child(level_label)

	var reward_label = Label.new()
	reward_label.custom_minimum_size = Vector2(560, 64)
	reward_label.text = "\n".join(lines)
	reward_label.add_theme_font_size_override("font_size", 24)
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reward_color = Color.WHITE if is_unlocked else Color(0.7, 0.7, 0.7)
	if has_item:
		reward_color = Color(1, 0.84, 0) if is_unlocked else Color(0.85, 0.75, 0.4)
	reward_label.add_theme_color_override("font_color", reward_color)
	item.add_child(reward_label)

	var status_label = Label.new()
	status_label.custom_minimum_size = Vector2(80, 64)
	status_label.text = "✓" if is_unlocked else "🔒"
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_child(status_label)

	$RewardsScroll/RewardsList.add_child(item)
	$RewardsScroll/RewardsList.add_child(HSeparator.new())

func _on_back_pressed():
	queue_free()
