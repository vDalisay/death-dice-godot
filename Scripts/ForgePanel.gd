class_name ForgePanel
extends PanelContainer
## Dice Forge: sacrifice 2 dice to create a new die of higher rarity.
## Self-contained panel — call open() and listen for forge_closed signal.

signal forge_closed()

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const MIN_DICE_FOR_FORGE: int = 4
const FORGE_CHANCE: float = 0.25
const _UITheme := preload("res://Scripts/UITheme.gd")

const DICE_BUTTON_WIDTH: int = 208
const DICE_BUTTON_HEIGHT: int = 76
const MODAL_INTRO_DURATION: float = 0.22
const MODAL_EXIT_DURATION: float = 0.16

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic"]

@onready var _backdrop: ColorRect = $Backdrop
@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _cost_badge: PanelContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CostBadge
@onready var _cost_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CostBadge/CostMargin/CostLabel
@onready var _instruction_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/InstructionLabel
@onready var _grid: HFlowContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/DiceFlow
@onready var _result_card: PanelContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ResultCard
@onready var _result_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/ResultCard/ResultMargin/ResultLabel
@onready var _forge_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/ForgeButton
@onready var _skip_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/SkipButton
@onready var _selection_sparks: CPUParticles2D = $CenterContainer/Modal/SelectionSparks
@onready var _forge_burst: CPUParticles2D = $CenterContainer/Modal/ForgeBurst

var _selected_indices: Array[int] = []
var _die_buttons: Array[Button] = []
var _forging_done: bool = false
var _transition_tween: Tween = null
var _is_closing: bool = false


func _ready() -> void:
	visible = false
	_forge_button.pressed.connect(_on_forge_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_apply_theme_styling()


func open() -> void:
	_selected_indices.clear()
	_is_closing = false
	_forging_done = false
	_result_label.text = ""
	_result_card.visible = false
	_forge_button.disabled = true
	_forge_button.text = "Forge!"
	_skip_button.text = "Skip"
	_skip_button.disabled = false
	_skip_button.visible = true
	_refresh_grid()
	_update_instruction()
	visible = true
	_play_open_transition()


func _on_skip_pressed() -> void:
	if _is_closing:
		return
	await _close_panel()
	forge_closed.emit()


func _on_forge_pressed() -> void:
	if _is_closing:
		return
	if _forging_done:
		await _close_panel()
		forge_closed.emit()
		return

	if _selected_indices.size() != 2:
		return
	if not _can_forge_selection():
		_result_label.text = "Cannot forge two Epic dice!"
		_result_label.modulate = _UITheme.DANGER_RED
		_result_card.visible = true
		return

	await _play_sacrifice_animation()

	# Sort descending so removal doesn't shift earlier indices.
	var sorted: Array[int] = _selected_indices.duplicate()
	sorted.sort()
	sorted.reverse()

	var die_a: DiceData = GameManager.dice_pool[_selected_indices[0]]
	var die_b: DiceData = GameManager.dice_pool[_selected_indices[1]]

	var result_die: DiceData = _roll_forge_result(die_a.rarity, die_b.rarity)
	result_die = _apply_reroll_affinity(result_die, die_a, die_b)
	if result_die == null:
		_result_label.text = "Cannot forge these dice!"
		return

	# Remove sacrificed dice.
	for idx: int in sorted:
		GameManager.dice_pool.remove_at(idx)

	# Add the new die.
	GameManager.add_dice(result_die)
	SaveManager.discover_die(result_die.dice_name)

	_result_label.text = "Forged: %s (%s)" % [result_die.get_display_name(), RARITY_NAMES[result_die.rarity]]
	_result_label.modulate = result_die.get_rarity_color_value()
	_result_card.visible = true
	_animate_result_card()

	_forging_done = true
	_forge_button.text = "Continue"
	_forge_button.disabled = false
	_skip_button.visible = false
	_selected_indices.clear()
	_refresh_grid()


func _close_panel() -> void:
	if _is_closing:
		return
	_is_closing = true
	_forge_button.disabled = true
	_skip_button.disabled = true
	await _play_close_transition()
	visible = false


func _play_open_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_enter(self, _modal, MODAL_INTRO_DURATION, _backdrop)


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _modal, MODAL_EXIT_DURATION, _backdrop)
	await _transition_tween.finished


func _update_instruction() -> void:
	_instruction_label.text = "Select 2 dice to sacrifice (%d / 2 selected)" % _selected_indices.size()


func _refresh_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_die_buttons.clear()

	for i: int in GameManager.dice_pool.size():
		var die: DiceData = GameManager.dice_pool[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(DICE_BUTTON_WIDTH, DICE_BUTTON_HEIGHT)
		btn.text = "%s\n%s" % [die.get_display_name(), RARITY_NAMES[die.rarity]]
		btn.tooltip_text = "%s\nFaces: %s" % [
			RARITY_NAMES[die.rarity],
			_face_summary(die)
		]
		btn.add_theme_font_override("font", _UITheme.font_stats())
		btn.add_theme_font_size_override("font_size", 14)

		var selected: bool = i in _selected_indices
		var normal := _build_button_style(die.get_rarity_color_value(), selected)
		var hover := _build_button_style(die.get_rarity_color_value(), selected)
		hover.bg_color = hover.bg_color.lightened(0.08)
		var pressed := _build_button_style(die.get_rarity_color_value(), selected)
		pressed.bg_color = pressed.bg_color.darkened(0.08)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)

		if _forging_done:
			btn.disabled = true
		else:
			var idx: int = i
			btn.pressed.connect(func() -> void: _toggle_die(idx))

		_die_buttons.append(btn)
		_grid.add_child(btn)


func _toggle_die(index: int) -> void:
	if _forging_done:
		return

	var was_selected: bool = index in _selected_indices
	if index in _selected_indices:
		_selected_indices.erase(index)
	elif _selected_indices.size() < 2:
		_selected_indices.append(index)

	_forge_button.disabled = _selected_indices.size() != 2

	# Check if purple + purple (cannot forge).
	if _selected_indices.size() == 2:
		if not _can_forge_selection():
			_forge_button.disabled = true
			_result_label.text = "Cannot forge two Epic dice!"
			_result_label.modulate = _UITheme.DANGER_RED
			_result_card.visible = true
		else:
			_result_label.text = ""
			_result_card.visible = false
	else:
		_result_label.text = ""
		_result_card.visible = false

	_update_instruction()
	_refresh_grid()

	if not was_selected and index in _selected_indices:
		_emit_selection_sparks(index)


func _can_forge_selection() -> bool:
	if _selected_indices.size() != 2:
		return false
	var r1: DiceData.Rarity = GameManager.dice_pool[_selected_indices[0]].rarity
	var r2: DiceData.Rarity = GameManager.dice_pool[_selected_indices[1]].rarity
	return not (r1 == DiceData.Rarity.PURPLE and r2 == DiceData.Rarity.PURPLE)


func _play_sacrifice_animation() -> void:
	var tween: Tween = create_tween()
	for idx: int in _selected_indices:
		if idx >= 0 and idx < _die_buttons.size():
			var btn: Button = _die_buttons[idx]
			_emit_particles_at(btn.get_global_rect().get_center())
			tween.parallel().tween_property(btn, "scale", Vector2(0.2, 0.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(btn, "modulate:a", 0.0, 0.2)
	await tween.finished
	_emit_forge_burst()
	await get_tree().create_timer(0.14).timeout


func _emit_selection_sparks(index: int) -> void:
	if index < 0 or index >= _die_buttons.size():
		return
	_emit_particles_at(_die_buttons[index].get_global_rect().get_center())


func _emit_particles_at(global_center: Vector2) -> void:
	_selection_sparks.global_position = global_center
	_selection_sparks.restart()
	_selection_sparks.emitting = true


func _emit_forge_burst() -> void:
	_forge_burst.global_position = _modal.get_global_rect().get_center()
	_forge_burst.restart()
	_forge_burst.emitting = true


func _animate_result_card() -> void:
	_result_card.scale = Vector2(1.25, 1.25)
	_result_card.modulate = Color(1, 1, 1, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_result_card, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(_result_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_backdrop.color = Color(_UITheme.STAGE_FAMILY_BACKDROP_COLOR, _UITheme.STAGE_FAMILY_BACKDROP_ALPHA)
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.SCORE_GOLD, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	_cost_badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, _UITheme.ACTION_CYAN, 1)
	)
	_cost_label.add_theme_font_override("font", _UITheme.font_body())
	_cost_label.add_theme_font_size_override("font_size", 14)
	_cost_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	_instruction_label.add_theme_font_override("font", _UITheme.font_stats())
	_instruction_label.add_theme_font_size_override("font_size", 16)
	_result_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.SCORE_GOLD, 1)
	)
	_result_label.add_theme_font_override("font", _UITheme.font_stats())
	_result_label.add_theme_font_size_override("font_size", 24)
	_forge_button.add_theme_font_override("font", _UITheme.font_display())
	_forge_button.add_theme_font_size_override("font_size", 12)
	_skip_button.add_theme_font_override("font", _UITheme.font_display())
	_skip_button.add_theme_font_size_override("font_size", 12)


func _build_button_style(rarity_color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _UITheme.PANEL_SURFACE
	style.corner_radius_top_left = _UITheme.CORNER_RADIUS_CARD
	style.corner_radius_top_right = _UITheme.CORNER_RADIUS_CARD
	style.corner_radius_bottom_left = _UITheme.CORNER_RADIUS_CARD
	style.corner_radius_bottom_right = _UITheme.CORNER_RADIUS_CARD
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if selected:
		style.bg_color = Color("#2D240E")
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = _UITheme.SCORE_GOLD
	return style


func _face_summary(die: DiceData) -> String:
	var faces: Array[String] = []
	for face: DiceFaceData in die.faces:
		faces.append(face.get_display_text())
	return ", ".join(faces)


static func _apply_reroll_affinity(result_die: DiceData, die_a: DiceData, die_b: DiceData) -> DiceData:
	if result_die == null:
		return null
	var evolving_inputs: Array[DiceData] = []
	if die_a != null and die_a.is_reroll_evolving():
		evolving_inputs.append(die_a)
	if die_b != null and die_b.is_reroll_evolving():
		evolving_inputs.append(die_b)
	if evolving_inputs.is_empty():
		return result_die
	var affinity_tier: int = 0
	for die: DiceData in evolving_inputs:
		affinity_tier = maxi(affinity_tier, die.reroll_tier)
	if evolving_inputs.size() >= 2:
		affinity_tier = mini(2, affinity_tier + 1)
	var affinity_die: DiceData = DiceData.make_reroll_chaser_d6(affinity_tier)
	affinity_die.reroll_affinity_locked = true
	return affinity_die


## Roll the forge outcome based on two sacrifice rarity tiers.
## Returns null only for Purple+Purple (handled above).
static func _roll_forge_result(r1: DiceData.Rarity, r2: DiceData.Rarity) -> DiceData:
	# Normalize so r1 <= r2 (lower or equal tier first).
	if r1 > r2:
		var tmp: DiceData.Rarity = r1
		r1 = r2
		r2 = tmp

	var target_rarity: DiceData.Rarity = _pick_result_rarity(r1, r2)
	return _random_die_of_rarity(target_rarity)


## Pick the result rarity tier from the probability table.
static func _pick_result_rarity(r1: DiceData.Rarity, r2: DiceData.Rarity) -> DiceData.Rarity:
	var roll: float = GameManager.rng_randf("forge")

	# Same-tier pairs: guaranteed upgrade.
	if r1 == r2:
		match r1:
			DiceData.Rarity.GREY:
				return DiceData.Rarity.GREEN
			DiceData.Rarity.GREEN:
				return DiceData.Rarity.BLUE
			DiceData.Rarity.BLUE:
				return DiceData.Rarity.PURPLE
			DiceData.Rarity.PURPLE:
				# Should not reach here — blocked in UI.
				return DiceData.Rarity.PURPLE

	# Cross-tier pairs.
	match [r1, r2]:
		[DiceData.Rarity.GREY, DiceData.Rarity.GREEN]:
			if roll < 0.55:
				return DiceData.Rarity.GREEN
			elif roll < 0.85:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREY
		[DiceData.Rarity.GREY, DiceData.Rarity.BLUE]:
			if roll < 0.50:
				return DiceData.Rarity.BLUE
			elif roll < 0.80:
				return DiceData.Rarity.GREEN
			return DiceData.Rarity.PURPLE
		[DiceData.Rarity.GREY, DiceData.Rarity.PURPLE]:
			if roll < 0.45:
				return DiceData.Rarity.PURPLE
			elif roll < 0.80:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.GREEN, DiceData.Rarity.BLUE]:
			if roll < 0.55:
				return DiceData.Rarity.BLUE
			elif roll < 0.85:
				return DiceData.Rarity.PURPLE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.GREEN, DiceData.Rarity.PURPLE]:
			if roll < 0.50:
				return DiceData.Rarity.PURPLE
			elif roll < 0.85:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.BLUE, DiceData.Rarity.PURPLE]:
			if roll < 0.60:
				return DiceData.Rarity.PURPLE
			elif roll < 0.95:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN

	# Fallback (shouldn't reach).
	return DiceData.Rarity.GREEN


## Pick a random die of the given rarity tier.
static func _random_die_of_rarity(rarity: DiceData.Rarity) -> DiceData:
	var all: Array[DiceData] = DiceData.get_all_known_dice()
	var candidates: Array[DiceData] = []
	for die: DiceData in all:
		if die.rarity == rarity:
			candidates.append(die)
	if candidates.is_empty():
		return DiceData.make_standard_d6()
	var index: int = GameManager.rng_pick_index("forge", candidates.size())
	if index < 0:
		return candidates[0]
	return candidates[index]
