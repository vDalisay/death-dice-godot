extends Control

## Cubitos-style dice rolling game.
## Roll all dice → STOP faces lock → select dice to keep/reroll → bust or bank.

const STARTING_DICE_COUNT: int = 5
const BASE_BUST_THRESHOLD: int = 3

enum TurnState { IDLE, ACTIVE, BUST, BANKED }

@onready var score_label: Label       = $MarginContainer/VBoxContainer/ScoreLabel
@onready var turn_score_label: Label  = $MarginContainer/VBoxContainer/TurnScoreLabel
@onready var status_label: Label      = $MarginContainer/VBoxContainer/StatusLabel
@onready var stop_label: Label        = $MarginContainer/VBoxContainer/StopLabel
@onready var dice_container: HFlowContainer = $MarginContainer/VBoxContainer/DiceContainer
@onready var roll_button: Button      = $MarginContainer/VBoxContainer/ButtonRow/RollButton
@onready var bank_button: Button      = $MarginContainer/VBoxContainer/ButtonRow/BankButton

var total_score: int = 0
var last_banked: int = 0
var turn_state: TurnState = TurnState.IDLE
var turn_number: int = 0

var dice_pool: Array[DiceData] = []
var current_results: Array[DiceFaceData] = []  # null until rolled
var dice_stopped: Array[bool] = []             # permanently locked by STOP face
var dice_keep: Array[bool] = []                # true = player wants to keep (not reroll)
var dice_keep_locked: Array[bool] = []         # keep confirmed by a reroll — cannot be undone
var die_buttons: Array[Button] = []

func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	_build_dice_pool()
	_start_new_turn()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _build_dice_pool() -> void:
	dice_pool.clear()
	for i: int in STARTING_DICE_COUNT:
		dice_pool.append(DiceData.make_standard_d6())

func _start_new_turn() -> void:
	turn_state = TurnState.IDLE
	turn_number += 1
	current_results.clear()
	current_results.resize(dice_pool.size())  # filled with null
	dice_stopped.resize(dice_pool.size())
	dice_stopped.fill(false)
	dice_keep.resize(dice_pool.size())
	dice_keep.fill(false)
	dice_keep_locked.resize(dice_pool.size())
	dice_keep_locked.fill(false)
	_rebuild_die_buttons()
	_refresh_ui()

func _rebuild_die_buttons() -> void:
	for child: Node in dice_container.get_children():
		child.queue_free()
	die_buttons.clear()
	for i: int in dice_pool.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 90)
		btn.add_theme_font_size_override("font_size", 18)
		btn.text = "?"
		btn.disabled = true
		btn.pressed.connect(_on_die_clicked.bind(i))
		dice_container.add_child(btn)
		die_buttons.append(btn)

# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	match turn_state:
		TurnState.IDLE:
			_roll_all_dice()
		TurnState.ACTIVE:
			_reroll_selected_dice()
		TurnState.BUST, TurnState.BANKED:
			_start_new_turn()

func _on_bank_pressed() -> void:
	if turn_state != TurnState.ACTIVE:
		return
	# Pop all scoring dice before banking.
	for i: int in dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type in [DiceFaceData.FaceType.NUMBER, DiceFaceData.FaceType.AUTO_KEEP]:
			_pop_die(i)
	last_banked = _calculate_turn_score()
	total_score += last_banked
	turn_state = TurnState.BANKED
	_refresh_ui()

func _on_die_clicked(index: int) -> void:
	if turn_state != TurnState.ACTIVE:
		return
	# Stopped and locked-keep dice cannot be toggled.
	if dice_stopped[index] or dice_keep_locked[index]:
		return
	dice_keep[index] = not dice_keep[index]
	_refresh_die_button(index)
	_refresh_ui()

# ---------------------------------------------------------------------------
# Rolling logic
# ---------------------------------------------------------------------------

func _roll_all_dice() -> void:
	var all_indices: Array[int] = []
	for i: int in dice_pool.size():
		current_results[i] = dice_pool[i].roll()
		all_indices.append(i)
	_process_roll_results(all_indices)

func _reroll_selected_dice() -> void:
	# Confirm all currently-kept dice as permanently locked before rerolling.
	for i: int in dice_pool.size():
		if dice_keep[i] and not dice_keep_locked[i]:
			dice_keep_locked[i] = true
	var rerolled: Array[int] = []
	for i: int in dice_pool.size():
		if not dice_stopped[i] and not dice_keep[i]:
			current_results[i] = dice_pool[i].roll()
			rerolled.append(i)
	if rerolled.is_empty():
		status_label.text = "All dice are kept — Bank your score or start a new turn."
		return
	_process_roll_results(rerolled)

func _process_roll_results(rolled_indices: Array[int]) -> void:
	for i: int in rolled_indices:
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
			DiceFaceData.FaceType.AUTO_KEEP:
				# Instantly kept & locked — not user-selectable.
				dice_keep[i] = true
				dice_keep_locked[i] = true
				_pop_die(i)
			_:
				# NUMBER / BLANK — default to reroll unless already locked.
				if not dice_keep_locked[i]:
					dice_keep[i] = false

	var stop_count: int = _count_stops()
	var threshold: int = _get_bust_threshold()
	if stop_count >= threshold and turn_number > 1:
		turn_state = TurnState.BUST
	else:
		turn_state = TurnState.ACTIVE

	for i: int in dice_pool.size():
		_refresh_die_button(i)
	_refresh_ui()

	if turn_number == 1 and stop_count >= threshold:
		status_label.text = "Close call! Turn 1 — no bust this time."
		status_label.modulate = Color(1.0, 0.85, 0.0)

# ---------------------------------------------------------------------------
# Score calculation
# ---------------------------------------------------------------------------

func _calculate_turn_score() -> int:
	var score: int = 0
	for i: int in dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.NUMBER or face.type == DiceFaceData.FaceType.AUTO_KEEP:
			score += face.value
	return score

func _count_stops() -> int:
	var count: int = 0
	for stopped: bool in dice_stopped:
		if stopped:
			count += 1
	return count

func _get_bust_threshold() -> int:
	if turn_number <= 1:
		return BASE_BUST_THRESHOLD + 99  # Effectively immune
	if turn_number <= 3:
		return BASE_BUST_THRESHOLD + 1   # Lenient: 4
	return BASE_BUST_THRESHOLD           # Standard: 3

# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

func _pop_die(index: int) -> void:
	var btn: Button = die_buttons[index]
	btn.pivot_offset = btn.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_IN)

# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------

func _refresh_die_button(index: int) -> void:
	var btn: Button = die_buttons[index]
	var face: DiceFaceData = current_results[index]

	if face == null:
		btn.text = "?"
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.disabled = true
		return

	btn.text = face.get_display_text()

	if dice_stopped[index]:
		# Red — bust-locked
		btn.modulate = Color(0.9, 0.2, 0.2)
		btn.disabled = true
	elif face.type == DiceFaceData.FaceType.AUTO_KEEP:
		# Gold — auto-kept, not user-selectable
		btn.modulate = Color(1.0, 0.85, 0.0)
		btn.disabled = true
	elif dice_keep_locked[index]:
		# Dark green — player locked this keep via reroll, cannot undo
		btn.modulate = Color(0.1, 0.65, 0.1)
		btn.disabled = true
	elif dice_keep[index]:
		# Bright green — player chose keep, still toggleable until next reroll
		btn.modulate = Color(0.3, 0.85, 0.3)
		btn.disabled = false
	else:
		# Orange — will be rerolled
		btn.modulate = Color(1.0, 0.65, 0.2)
		btn.disabled = false

func _refresh_ui() -> void:
	var stop_count: int = _count_stops()
	var turn_score: int = _calculate_turn_score()

	score_label.text      = "Total Score: %d" % total_score
	turn_score_label.text = "This turn: %d" % turn_score
	stop_label.text       = "Stops: %d / %d" % [stop_count, _get_bust_threshold()]
	stop_label.modulate   = Color(0.9, 0.2, 0.2) if stop_count > 0 else Color.WHITE

	match turn_state:
		TurnState.IDLE:
			status_label.text    = "Press 'Roll All' to begin your turn!"
			status_label.modulate = Color.WHITE
			roll_button.text     = "Roll All"
			roll_button.disabled = false
			bank_button.disabled = true

		TurnState.ACTIVE:
			status_label.text    = "Green = keep · Orange = reroll · Click to toggle (locks on reroll)"
			status_label.modulate = Color.WHITE
			roll_button.text     = "Reroll Selected"
			roll_button.disabled = false
			bank_button.disabled = false

		TurnState.BUST:
			status_label.text    = "BUST! %d stops — turn score lost!" % stop_count
			status_label.modulate = Color(0.9, 0.2, 0.2)
			roll_button.text     = "New Turn"
			roll_button.disabled = false
			bank_button.disabled = true

		TurnState.BANKED:
			status_label.text    = "Banked %d points!  Total: %d" % [last_banked, total_score]
			status_label.modulate = Color(0.3, 0.9, 0.3)
			roll_button.text     = "New Turn"
			roll_button.disabled = false
			bank_button.disabled = true
