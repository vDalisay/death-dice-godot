class_name DoubleDownOverlay
extends PanelContainer
## Shop sub-overlay: player picks EVEN or ODDS, die rolls, gold is doubled or lost.

signal resolved()

const ROLL_DURATION: float = 3.0
const MIN_INTERVAL: float = 0.3
const START_INTERVAL: float = 0.06
const DIE_FACES: Array[int] = [1, 2, 3, 4, 5, 6]
const _UITheme := preload("res://Scripts/UITheme.gd")

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/TitleLabel
@onready var _die_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/DieLabel
@onready var _prompt_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/PromptLabel
@onready var _result_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/ResultLabel
@onready var _even_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/EvenButton
@onready var _odd_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/OddButton
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton

var _gold_at_stake: int = 0
var _player_picked_even: bool = true
var _final_roll: int = 0
var _rolling: bool = false
var _confetti_nodes: Array[Node] = []


func _ready() -> void:
	_apply_theme_styling()
	visible = false
	_even_button.pressed.connect(_on_even_pressed)
	_odd_button.pressed.connect(_on_odd_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.visible = false
	_result_label.text = ""


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.ACTION_CYAN, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_die_label.add_theme_font_override("font", _UITheme.font_stats())
	_die_label.add_theme_font_size_override("font_size", 120)
	_die_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	_prompt_label.add_theme_font_override("font", _UITheme.font_body())
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_result_label.add_theme_font_override("font", _UITheme.font_stats())
	_result_label.add_theme_font_size_override("font_size", 24)

	for button: Button in [_even_button, _odd_button, _close_button]:
		button.add_theme_font_override("font", _UITheme.font_display())
		button.add_theme_font_size_override("font_size", 13)


func open(gold_at_stake: int) -> void:
	_gold_at_stake = gold_at_stake
	_rolling = false
	_die_label.text = _UITheme.GLYPH_DIE
	_prompt_label.text = "Wager: %dg — pick your side!" % gold_at_stake
	_result_label.text = ""
	_result_label.modulate = _UITheme.BRIGHT_TEXT
	_even_button.visible = true
	_even_button.disabled = false
	_odd_button.visible = true
	_odd_button.disabled = false
	_close_button.visible = false
	_modal.position = Vector2.ZERO
	_clear_confetti()
	visible = true


func _on_even_pressed() -> void:
	_player_picked_even = true
	_start_roll()


func _on_odd_pressed() -> void:
	_player_picked_even = false
	_start_roll()


func _start_roll() -> void:
	if _rolling:
		return
	_rolling = true
	_even_button.disabled = true
	_odd_button.disabled = true
	_prompt_label.text = "Rolling..."
	_final_roll = (randi() % 6) + 1
	_animate_roll()


func _animate_roll() -> void:
	_roll_step(0.0)


func _roll_step(elapsed: float) -> void:
	if elapsed >= ROLL_DURATION:
		_finish_roll()
		return
	var progress: float = elapsed / ROLL_DURATION
	var interval: float = lerpf(START_INTERVAL, MIN_INTERVAL, progress * progress)
	var display_face: int = _final_roll if progress > 0.85 else DIE_FACES[randi() % DIE_FACES.size()]
	_die_label.text = str(display_face)
	SFXManager.play_roll()
	get_tree().create_timer(interval).timeout.connect(func() -> void: _roll_step(elapsed + interval))


func _finish_roll() -> void:
	_die_label.text = str(_final_roll)
	_rolling = false
	_even_button.visible = false
	_odd_button.visible = false
	var is_even: bool = _final_roll % 2 == 0
	var won: bool = (_player_picked_even and is_even) or (not _player_picked_even and not is_even)
	if won:
		GameManager.add_gold(_gold_at_stake)
		_result_label.text = "Rolled %d (%s) — YOU WIN! +%dg!" % [_final_roll, "even" if is_even else "odd", _gold_at_stake]
		_result_label.modulate = _UITheme.SUCCESS_GREEN
		SFXManager.play_double_down_win()
		_spawn_confetti()
	else:
		var loss: int = mini(_gold_at_stake, GameManager.gold)
		GameManager.add_gold(-loss)
		_result_label.text = "Rolled %d (%s) — LOST! -%dg" % [_final_roll, "even" if is_even else "odd", loss]
		_result_label.modulate = _UITheme.DANGER_RED
		SFXManager.play_bust()
		_play_loss_shake()
	_close_button.visible = true


func _play_loss_shake() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_modal, "position", Vector2(-12, 0), 0.04)
	tween.tween_property(_modal, "position", Vector2(12, 0), 0.05)
	tween.tween_property(_modal, "position", Vector2(-8, 0), 0.04)
	tween.tween_property(_modal, "position", Vector2(8, 0), 0.04)
	tween.tween_property(_modal, "position", Vector2.ZERO, 0.05)


func _on_close_pressed() -> void:
	_clear_confetti()
	visible = false
	resolved.emit()


func _spawn_confetti() -> void:
	_clear_confetti()
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 60
	particles.lifetime = 2.0
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 90.0
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 500.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = _UITheme.SCORE_GOLD
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.3, 0.3))
	gradient.add_point(0.25, _UITheme.SUCCESS_GREEN)
	gradient.add_point(0.5, _UITheme.ACTION_CYAN)
	gradient.add_point(0.75, _UITheme.SCORE_GOLD)
	gradient.set_color(1, _UITheme.NEON_PURPLE)
	particles.color_ramp = gradient
	particles.position = Vector2(_modal.size.x / 2.0, _modal.size.y * 0.5)
	_modal.add_child(particles)
	_confetti_nodes.append(particles)
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
				_confetti_nodes.erase(particles)
	)


func _clear_confetti() -> void:
	for node: Node in _confetti_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_confetti_nodes.clear()
