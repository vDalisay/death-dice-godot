class_name ArchetypePicker
extends ColorRect
## Modal picker for run mode + archetype selection.

signal selection_confirmed(run_mode: int, archetype: int)

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const PrestigePanelScene: PackedScene = preload("res://Scenes/PrestigePanel.tscn")

const PANEL_MIN_SIZE: Vector2 = Vector2(860, 420)
const CARD_MIN_SIZE: Vector2 = Vector2(220, 180)
const CARD_ROW_SPACING: int = 24
const MODE_ROW_SPACING: int = 12
const CONTENT_SPACING: int = 16
const INTRO_DURATION: float = 0.24
const CARD_REVEAL_STAGGER: float = 0.08
const CARD_REVEAL_DURATION: float = 0.18
const MODE_PULSE_SCALE: float = 1.06

@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _classic_button: Button = $CenterContainer/Card/MarginContainer/Content/ModeRow/ClassicButton
@onready var _gauntlet_button: Button = $CenterContainer/Card/MarginContainer/Content/ModeRow/GauntletButton
@onready var _mode_description: Label = $CenterContainer/Card/MarginContainer/Content/ModeDescription
@onready var _archetype_row: HBoxContainer = $CenterContainer/Card/MarginContainer/Content/ArchetypeRow
@onready var _content: VBoxContainer = $CenterContainer/Card/MarginContainer/Content

var _selected_mode: int = int(GameManager.RunMode.CLASSIC)
var _mode_buttons: Array[Button] = []
var _prestige_button: Button = null
var _transition_tween: Tween = null
var _interaction_locked: bool = false


func _ready() -> void:
	_apply_theme()
	_add_prestige_button()
	_classic_button.pressed.connect(func() -> void: _set_mode(int(GameManager.RunMode.CLASSIC)))
	_gauntlet_button.pressed.connect(func() -> void: _set_mode(int(GameManager.RunMode.GAUNTLET)))
	_mode_buttons = [_classic_button, _gauntlet_button]
	_set_mode(_selected_mode)
	_rebuild_archetype_cards(true)
	_play_intro()


func open(initial_mode: int) -> void:
	_selected_mode = initial_mode
	_interaction_locked = false
	_set_mode(_selected_mode)
	_rebuild_archetype_cards(true)
	_play_intro()


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
	_mode_description.add_theme_font_override("font", _UITheme.font_mono())
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
	var selected_button: Button = _classic_button if classic_selected else _gauntlet_button
	_play_mode_pulse(selected_button)


func _rebuild_archetype_cards(animate_cards: bool = false) -> void:
	for child: Node in _archetype_row.get_children():
		child.queue_free()

	var archetypes: Array[GameManager.Archetype] = [
		GameManager.Archetype.CAUTION,
		GameManager.Archetype.RISK_IT,
		GameManager.Archetype.BLANK_SLATE,
	]
	if SaveManager.has_prestige_unlock("new_archetype"):
		archetypes.append(GameManager.Archetype.FORTUNE_FOOL)
	for arch: GameManager.Archetype in archetypes:
		_archetype_row.add_child(_build_archetype_card(arch))
	if animate_cards:
		_prepare_cards_for_intro()
	else:
		_show_cards_immediately()


func _build_archetype_card(archetype: GameManager.Archetype) -> PanelContainer:
	var unlock_req: int = GameManager.ARCHETYPE_UNLOCK_LOOPS[archetype]
	var unlocked: bool = SaveManager.max_loops_completed >= unlock_req
	if archetype == GameManager.Archetype.FORTUNE_FOOL:
		unlocked = SaveManager.has_prestige_unlock("new_archetype")

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
	if unlocked:
		description_label.text = GameManager.ARCHETYPE_DESCRIPTIONS[archetype]
	elif archetype == GameManager.Archetype.FORTUNE_FOOL:
		description_label.text = "Locked - buy New Archetype in Prestige Shop"
	else:
		description_label.text = "Locked - complete %d loop(s)" % unlock_req
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
	select_button.pressed.connect(_confirm_selection.bind(int(archetype)))
	card_box.add_child(select_button)
	return card


func _confirm_selection(archetype: int) -> void:
	if _interaction_locked:
		return
	_interaction_locked = true
	_set_interaction_enabled(false)
	await _play_close_transition()
	selection_confirmed.emit(_selected_mode, archetype)
	queue_free()

func _prepare_cards_for_intro() -> void:
	for child: Node in _archetype_row.get_children():
		var card: PanelContainer = child as PanelContainer
		if card == null:
			continue
		card.modulate.a = 0.0
		card.position.y += 12.0
		card.scale = Vector2(0.96, 0.96)


func _show_cards_immediately() -> void:
	for child: Node in _archetype_row.get_children():
		var card: PanelContainer = child as PanelContainer
		if card == null:
			continue
		card.modulate.a = 1.0
		card.scale = Vector2.ONE


func _play_intro() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_enter(self, _card_panel, INTRO_DURATION, self, Vector2(1.04, 1.04))
	var reveal_index: int = 0
	for child: Node in _archetype_row.get_children():
		var card: PanelContainer = child as PanelContainer
		if card == null:
			continue
		_transition_tween.tween_callback(_reveal_archetype_card_by_index.bind(reveal_index)).set_delay(CARD_REVEAL_STAGGER * reveal_index)
		reveal_index += 1



func _reveal_archetype_card_by_index(index: int) -> void:
	if index < 0 or index >= _archetype_row.get_child_count():
		return
	var card: PanelContainer = _archetype_row.get_child(index) as PanelContainer
	if card == null or not is_instance_valid(card):
		return
	var tween: Tween = create_tween()
	var end_y: float = card.position.y - 12.0
	tween.tween_property(card, "modulate:a", 1.0, CARD_REVEAL_DURATION)
	tween.parallel().tween_property(card, "position:y", end_y, CARD_REVEAL_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, CARD_REVEAL_DURATION).set_ease(Tween.EASE_OUT)


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _card_panel, INTRO_DURATION, self)
	await _transition_tween.finished


func _play_mode_pulse(button: Button) -> void:
	if button == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(MODE_PULSE_SCALE, MODE_PULSE_SCALE), 0.09).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN)


func _add_prestige_button() -> void:
	_prestige_button = Button.new()
	_prestige_button.text = "Prestige Shop"
	_prestige_button.custom_minimum_size = Vector2(220, 42)
	_prestige_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prestige_button.add_theme_font_override("font", _UITheme.font_display())
	_prestige_button.add_theme_font_size_override("font_size", 14)
	_prestige_button.pressed.connect(_open_prestige_panel)
	_content.add_child(_prestige_button)
	_content.move_child(_prestige_button, 3)


func _open_prestige_panel() -> void:
	if _interaction_locked:
		return
	var panel: Node = PrestigePanelScene.instantiate()
	add_child(panel)
	panel.connect("closed", Callable(self, "_on_prestige_panel_closed"))


func _on_prestige_panel_closed() -> void:
	_rebuild_archetype_cards(false)


func _set_interaction_enabled(enabled: bool) -> void:
	for button: Button in _mode_buttons:
		button.disabled = not enabled
	if _prestige_button != null:
		_prestige_button.disabled = not enabled
	for child: Node in _archetype_row.get_children():
		var card: PanelContainer = child as PanelContainer
		if card == null or card.get_child_count() == 0:
			continue
		var margin: MarginContainer = card.get_child(0) as MarginContainer
		if margin == null or margin.get_child_count() == 0:
			continue
		var card_box: VBoxContainer = margin.get_child(0) as VBoxContainer
		if card_box == null or card_box.get_child_count() < 3:
			continue
		var select_button: Button = card_box.get_child(card_box.get_child_count() - 1) as Button
		if select_button != null:
			select_button.disabled = not enabled or select_button.text == "Locked"
