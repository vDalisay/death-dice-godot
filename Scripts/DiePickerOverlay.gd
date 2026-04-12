class_name DiePickerOverlay
extends ColorRect

signal die_selected(index: int)
signal canceled()

const _UITheme := preload("res://Scripts/UITheme.gd")

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _grid: GridContainer = $CenterContainer/Card/MarginContainer/Content/Grid
@onready var _cancel_button: Button = $CenterContainer/Card/MarginContainer/Content/CancelButton


func _ready() -> void:
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_cancel_button.add_theme_font_override("font", _UITheme.font_display())
	_cancel_button.add_theme_font_size_override("font_size", 12)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func open(dice_pool: Array[DiceData]) -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for i: int in dice_pool.size():
		_grid.add_child(_build_die_card(dice_pool[i], i))
	color = Color(0.0, 0.0, 0.0, 0.0)
	_card.modulate.a = 0.0
	_card.scale = Vector2(1.08, 1.08)
	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", 0.56, 0.18)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_die_card(die: DiceData, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 164)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, die.get_rarity_color_value(), 2)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var name_label := Label.new()
	name_label.text = die.get_display_name()
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(name_label)
	var rarity_label := Label.new()
	rarity_label.text = _rarity_text(die.rarity)
	rarity_label.add_theme_font_override("font", _UITheme.font_mono())
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", die.get_rarity_color_value())
	vbox.add_child(rarity_label)
	var faces_label := Label.new()
	faces_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faces_label.add_theme_font_override("font", _UITheme.font_mono())
	faces_label.add_theme_font_size_override("font_size", 13)
	faces_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_BODY_TEXT)
	var face_texts: Array[String] = []
	for face: DiceFaceData in die.faces:
		face_texts.append(face.get_display_text())
	faces_label.text = ", ".join(face_texts)
	vbox.add_child(faces_label)
	var select_button := Button.new()
	select_button.text = "EMPOWER"
	select_button.add_theme_font_override("font", _UITheme.font_display())
	select_button.add_theme_font_size_override("font_size", 11)
	select_button.pressed.connect(_on_select_pressed.bind(index))
	vbox.add_child(select_button)
	return card


func _on_select_pressed(index: int) -> void:
	die_selected.emit(index)
	queue_free()


func _on_cancel_pressed() -> void:
	canceled.emit()
	queue_free()


func _rarity_text(rarity: DiceData.Rarity) -> String:
	match rarity:
		DiceData.Rarity.GREY:
			return "COMMON"
		DiceData.Rarity.GREEN:
			return "UNCOMMON"
		DiceData.Rarity.BLUE:
			return "RARE"
		DiceData.Rarity.PURPLE:
			return "EPIC"
	return "COMMON"