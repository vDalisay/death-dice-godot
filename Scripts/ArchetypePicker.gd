class_name ArchetypePicker
extends ColorRect
## Modal picker for run mode + archetype selection.

signal selection_confirmed(run_mode: int, archetype: int)

const _UITheme := preload("res://Scripts/UITheme.gd")

const PANEL_MIN_SIZE: Vector2 = Vector2(860, 420)
const CARD_MIN_SIZE: Vector2 = Vector2(220, 180)
const CARD_ROW_SPACING: int = 24
const MODE_ROW_SPACING: int = 12
const CONTENT_SPACING: int = 16

@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _classic_button: Button = $CenterContainer/Card/MarginContainer/Content/ModeRow/ClassicButton
@onready var _gauntlet_button: Button = $CenterContainer/Card/MarginContainer/Content/ModeRow/GauntletButton
@onready var _mode_description: Label = $CenterContainer/Card/MarginContainer/Content/ModeDescription
@onready var _archetype_row: HBoxContainer = $CenterContainer/Card/MarginContainer/Content/ArchetypeRow

var _selected_mode: int = int(GameManager.RunMode.CLASSIC)


func _ready() -> void:
	_apply_theme()
	_classic_button.pressed.connect(func() -> void: _set_mode(int(GameManager.RunMode.CLASSIC)))
	_gauntlet_button.pressed.connect(func() -> void: _set_mode(int(GameManager.RunMode.GAUNTLET)))
	_set_mode(_selected_mode)
	_rebuild_archetype_cards()


func open(initial_mode: int) -> void:
	_selected_mode = initial_mode
	_set_mode(_selected_mode)
	_rebuild_archetype_cards()


func _apply_theme() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.1, 0.1, 0.15, 0.92)
	_card_panel.custom_minimum_size = PANEL_MIN_SIZE
	_card_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.SCORE_GOLD, 2)
	)
	_title_label.text = "Choose Your Archetype"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	_mode_description.text = "Gauntlet: steeper stage scaling, separate records"
	_mode_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_description.add_theme_font_override("font", _UITheme.font_body())
	_mode_description.add_theme_font_size_override("font_size", 14)
	_mode_description.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_archetype_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_archetype_row.add_theme_constant_override("separation", CARD_ROW_SPACING)
	var mode_row: HBoxContainer = _classic_button.get_parent() as HBoxContainer
	if mode_row != null:
		mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
		mode_row.add_theme_constant_override("separation", MODE_ROW_SPACING)
	var content: VBoxContainer = _title_label.get_parent() as VBoxContainer
	if content != null:
		content.add_theme_constant_override("separation", CONTENT_SPACING)


func _set_mode(mode: int) -> void:
	_selected_mode = mode
	var classic_selected: bool = _selected_mode == int(GameManager.RunMode.CLASSIC)
	_classic_button.modulate = Color(1.0, 0.9, 0.35) if classic_selected else Color(0.8, 0.8, 0.8)
	_gauntlet_button.modulate = Color(1.0, 0.35, 0.35) if not classic_selected else Color(0.8, 0.8, 0.8)


func _rebuild_archetype_cards() -> void:
	for child: Node in _archetype_row.get_children():
		child.queue_free()

	var archetypes: Array[GameManager.Archetype] = [
		GameManager.Archetype.CAUTION,
		GameManager.Archetype.RISK_IT,
		GameManager.Archetype.BLANK_SLATE,
	]
	for arch: GameManager.Archetype in archetypes:
		_archetype_row.add_child(_build_archetype_card(arch))


func _build_archetype_card(archetype: GameManager.Archetype) -> PanelContainer:
	var unlock_req: int = GameManager.ARCHETYPE_UNLOCK_LOOPS[archetype]
	var unlocked: bool = SaveManager.max_loops_completed >= unlock_req

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.ACTION_CYAN, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var card_box := VBoxContainer.new()
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.add_theme_constant_override("separation", 8)
	margin.add_child(card_box)

	var name_label := Label.new()
	name_label.text = GameManager.ARCHETYPE_NAMES[archetype]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT if unlocked else _UITheme.MUTED_TEXT)
	card_box.add_child(name_label)

	var description_label := Label.new()
	description_label.text = GameManager.ARCHETYPE_DESCRIPTIONS[archetype] if unlocked else "Locked - complete %d loop(s)" % unlock_req
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_override("font", _UITheme.font_body())
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT if unlocked else _UITheme.MUTED_TEXT)
	card_box.add_child(description_label)

	var select_button := Button.new()
	select_button.text = "Select" if unlocked else "Locked"
	select_button.disabled = not unlocked
	select_button.add_theme_font_override("font", _UITheme.font_display())
	select_button.add_theme_font_size_override("font_size", 18)
	select_button.pressed.connect(func() -> void:
		selection_confirmed.emit(_selected_mode, int(archetype))
		queue_free()
	)
	card_box.add_child(select_button)
	return card
