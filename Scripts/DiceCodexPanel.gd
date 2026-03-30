class_name DiceCodexPanel
extends PanelContainer
## Dice Codex: shows all known dice with rarity colors.
## Discovered dice show full info; undiscovered dice show silhouettes.

signal closed()

@onready var _grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var _completion_label: Label = $MarginContainer/VBoxContainer/CompletionLabel
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)


func open_panel() -> void:
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()

	var all_dice: Array[DiceData] = DiceData.get_all_known_dice()
	var discovered_count: int = 0
	var total_count: int = all_dice.size()

	for die: DiceData in all_dice:
		var discovered: bool = SaveManager.is_die_discovered(die.dice_name)
		if discovered:
			discovered_count += 1
		_grid.add_child(_build_entry(die, discovered))

	var pct: int = 0
	if total_count > 0:
		pct = int(float(discovered_count) / float(total_count) * 100.0)
	_completion_label.text = "Discovered: %d / %d (%d%%)" % [discovered_count, total_count, pct]


func _build_entry(die: DiceData, discovered: bool) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.custom_minimum_size = Vector2(200, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	if discovered:
		style.border_color = die.get_rarity_color_value()
	else:
		style.border_color = Color(0.3, 0.3, 0.3)

	entry.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	entry.add_child(vbox)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	if discovered:
		name_label.text = die.dice_name
		name_label.modulate = die.get_rarity_color_value()
	else:
		name_label.text = "???"
		name_label.modulate = Color(0.4, 0.4, 0.4)
	vbox.add_child(name_label)

	var faces_label := Label.new()
	faces_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faces_label.add_theme_font_size_override("font_size", 12)
	if discovered:
		var parts: Array[String] = []
		for face: DiceFaceData in die.faces:
			parts.append(face.get_display_text())
		faces_label.text = " | ".join(parts)
		faces_label.modulate = Color(0.8, 0.8, 0.8)
	else:
		faces_label.text = "? | ? | ? | ? | ? | ?"
		faces_label.modulate = Color(0.3, 0.3, 0.3)
	vbox.add_child(faces_label)

	var rarity_label := Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	if discovered:
		var rarity_names: Array[String] = ["Common", "Uncommon", "Rare", "Epic"]
		rarity_label.text = rarity_names[die.rarity]
		rarity_label.modulate = die.get_rarity_color_value()
	else:
		rarity_label.text = ""
	vbox.add_child(rarity_label)

	return entry
