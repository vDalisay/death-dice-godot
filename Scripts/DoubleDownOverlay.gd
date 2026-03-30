class_name DoubleDownOverlay
extends PanelContainer
## Shop sub-overlay: player picks EVEN or ODDS, die rolls, gold is doubled or lost.

signal resolved()

const ROLL_DURATION: float = 3.0
const MIN_INTERVAL: float = 0.3
const START_INTERVAL: float = 0.06
const DIE_FACES: Array[int] = [1, 2, 3, 4, 5, 6]

@onready var _die_label: Label = $MarginContainer/VBoxContainer/DieLabel
@onready var _prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel
@onready var _result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var _even_button: Button = $MarginContainer/VBoxContainer/ButtonRow/EvenButton
@onready var _odd_button: Button = $MarginContainer/VBoxContainer/ButtonRow/OddButton
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _gold_at_stake: int = 0
var _player_picked_even: bool = true
var _final_roll: int = 0
var _rolling: bool = false
var _confetti_nodes: Array[Node] = []


func _ready() -> void:
	visible = false
	_even_button.pressed.connect(_on_even_pressed)
	_odd_button.pressed.connect(_on_odd_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.visible = false
	_result_label.text = ""


func open(gold_at_stake: int) -> void:
	_gold_at_stake = gold_at_stake
	_rolling = false
	_die_label.text = "🎲"
	_prompt_label.text = "Wager: %dg — pick your side!" % gold_at_stake
	_result_label.text = ""
	_even_button.visible = true
	_even_button.disabled = false
	_odd_button.visible = true
	_odd_button.disabled = false
	_close_button.visible = false
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
	# Pre-determine final result.
	_final_roll = (randi() % 6) + 1
	_animate_roll()


func _animate_roll() -> void:
	var elapsed: float = 0.0
	var step_count: int = 0
	_roll_step(elapsed, step_count)


func _roll_step(elapsed: float, step_count: int) -> void:
	if elapsed >= ROLL_DURATION:
		_finish_roll()
		return
	# Interval increases from START_INTERVAL to MIN_INTERVAL (slowing down).
	var progress: float = elapsed / ROLL_DURATION
	var interval: float = lerpf(START_INTERVAL, MIN_INTERVAL, progress * progress)
	# Show random face (biased toward final near the end).
	var display_face: int
	if progress > 0.85:
		display_face = _final_roll
	else:
		display_face = DIE_FACES[randi() % DIE_FACES.size()]
	_die_label.text = str(display_face)
	SFXManager.play_roll()
	var next_elapsed: float = elapsed + interval
	var next_step: int = step_count + 1
	get_tree().create_timer(interval).timeout.connect(
		func() -> void: _roll_step(next_elapsed, next_step)
	)


func _finish_roll() -> void:
	_die_label.text = str(_final_roll)
	_rolling = false
	_even_button.visible = false
	_odd_button.visible = false
	var is_even: bool = _final_roll % 2 == 0
	var won: bool = (_player_picked_even and is_even) or (not _player_picked_even and not is_even)
	if won:
		GameManager.add_gold(_gold_at_stake)
		_result_label.text = "Rolled %d (%s) — YOU WIN! +%dg!" % [
			_final_roll, "even" if is_even else "odd", _gold_at_stake]
		_result_label.modulate = Color(0.2, 1.0, 0.4)
		SFXManager.play_double_down_win()
		_spawn_confetti()
	else:
		var loss: int = mini(_gold_at_stake, GameManager.gold)
		GameManager.add_gold(-loss)
		_result_label.text = "Rolled %d (%s) — LOST! -%dg" % [
			_final_roll, "even" if is_even else "odd", loss]
		_result_label.modulate = Color(1.0, 0.4, 0.2)
		SFXManager.play_bust()
	_close_button.visible = true


func _on_close_pressed() -> void:
	_clear_confetti()
	visible = false
	resolved.emit()


func _spawn_confetti() -> void:
	_clear_confetti()
	# Simple particle confetti using CPUParticles2D.
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
	particles.color = Color(1.0, 0.85, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.3, 0.3))
	gradient.add_point(0.25, Color(0.3, 1.0, 0.3))
	gradient.add_point(0.5, Color(0.3, 0.5, 1.0))
	gradient.add_point(0.75, Color(1.0, 0.85, 0.0))
	gradient.set_color(1, Color(1.0, 0.5, 0.8))
	particles.color_ramp = gradient
	particles.position = Vector2(size.x / 2.0, size.y * 0.5)
	add_child(particles)
	_confetti_nodes.append(particles)
	# Auto-cleanup after lifetime.
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
