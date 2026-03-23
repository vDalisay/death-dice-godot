class_name RollPhase
extends Control
## Turn state machine for the Cubitos-style dice rolling phase.
## Owns dice logic. Delegates visuals to DiceTray and HUD.

const STARTING_DICE_COUNT: int = 5
const BASE_BUST_THRESHOLD: int = 3

enum TurnState { IDLE, ACTIVE, BUST, BANKED }

@onready var hud: HUD           = $MarginContainer/VBoxContainer/HUD
@onready var dice_tray: DiceTray = $MarginContainer/VBoxContainer/DiceTray
@onready var roll_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RollButton
@onready var bank_button: Button = $MarginContainer/VBoxContainer/ButtonRow/BankButton
@onready var new_run_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NewRunButton

var turn_state: TurnState = TurnState.IDLE
var turn_number: int = 0

# Per-die state arrays (same length as dice_pool).
var dice_pool: Array[DiceData] = []
var current_results: Array[DiceFaceData] = []
var dice_stopped: Array[bool] = []
var dice_keep: Array[bool] = []
var dice_keep_locked: Array[bool] = []

var _run_active: bool = true

func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	dice_tray.die_toggled.connect(_on_die_toggled)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	new_run_button.visible = false
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
	var count: int = dice_pool.size()
	current_results.resize(count)
	current_results.fill(null)
	dice_stopped.resize(count)
	dice_stopped.fill(false)
	dice_keep.resize(count)
	dice_keep.fill(false)
	dice_keep_locked.resize(count)
	dice_keep_locked.fill(false)
	dice_tray.build(count)
	_sync_ui()

# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	if not _run_active:
		return
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
	# Pop all scoring dice.
	for i: int in dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and (face.type == DiceFaceData.FaceType.NUMBER or face.type == DiceFaceData.FaceType.AUTO_KEEP):
			dice_tray.pop_die(i)
	var banked: int = _calculate_turn_score()
	GameManager.add_score(banked)
	turn_state = TurnState.BANKED
	hud.show_status("Banked %d points!  Total: %d" % [banked, GameManager.total_score], Color(0.3, 0.9, 0.3))
	_sync_buttons()

func _on_die_toggled(die_index: int, is_kept: bool) -> void:
	if turn_state != TurnState.ACTIVE:
		return
	if dice_stopped[die_index] or dice_keep_locked[die_index]:
		return
	dice_keep[die_index] = is_kept
	_sync_ui()

# ---------------------------------------------------------------------------
# Rolling logic
# ---------------------------------------------------------------------------

func _roll_all_dice() -> void:
	var indices: Array[int] = []
	for i: int in dice_pool.size():
		current_results[i] = dice_pool[i].roll()
		indices.append(i)
	_process_roll_results(indices)

func _reroll_selected_dice() -> void:
	# Lock all currently-kept dice permanently before rerolling.
	for i: int in dice_pool.size():
		if dice_keep[i] and not dice_keep_locked[i]:
			dice_keep_locked[i] = true
	var rerolled: Array[int] = []
	for i: int in dice_pool.size():
		if not dice_stopped[i] and not dice_keep[i]:
			current_results[i] = dice_pool[i].roll()
			rerolled.append(i)
	if rerolled.is_empty():
		hud.show_status("All dice are kept — Bank your score or start a new turn.")
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
				dice_keep[i] = true
				dice_keep_locked[i] = true
				dice_tray.pop_die(i)
			_:
				if not dice_keep_locked[i]:
					dice_keep[i] = false

	var stop_count: int = _count_stops()
	var threshold: int = _get_bust_threshold()
	if stop_count >= threshold and turn_number > 1:
		turn_state = TurnState.BUST
		GameManager.lose_life()
	else:
		turn_state = TurnState.ACTIVE

	_sync_all_dice()
	_sync_ui()

	if turn_number == 1 and stop_count >= threshold:
		hud.show_status("Close call! Turn 1 — no bust this time.", Color(1.0, 0.85, 0.0))

# ---------------------------------------------------------------------------
# Score / helpers
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
	if turn_number <= 3:
		return BASE_BUST_THRESHOLD + 1   # Lenient: 4
	return BASE_BUST_THRESHOLD           # Standard: 3

func _die_visual_state(index: int) -> DieButton.DieState:
	var face: DiceFaceData = current_results[index]
	if face == null:
		return DieButton.DieState.UNROLLED
	if dice_stopped[index]:
		return DieButton.DieState.STOPPED
	if face.type == DiceFaceData.FaceType.AUTO_KEEP:
		return DieButton.DieState.AUTO_KEPT
	if dice_keep_locked[index]:
		return DieButton.DieState.KEEP_LOCKED
	if dice_keep[index]:
		return DieButton.DieState.KEPT
	return DieButton.DieState.REROLLABLE

# ---------------------------------------------------------------------------
# UI sync
# ---------------------------------------------------------------------------

func _sync_all_dice() -> void:
	for i: int in dice_pool.size():
		dice_tray.update_die(i, current_results[i], _die_visual_state(i))

func _sync_ui() -> void:
	var stop_count: int = _count_stops()
	var turn_score: int = _calculate_turn_score()
	hud.update_turn(turn_score, stop_count, _get_bust_threshold())
	_sync_buttons()

	match turn_state:
		TurnState.IDLE:
			hud.show_status("Press 'Roll All' to begin your turn!")
		TurnState.ACTIVE:
			hud.show_status("Green = keep · Orange = reroll · Click to toggle (locks on reroll)")
		TurnState.BUST:
			hud.show_status("BUST! %d stops — turn score lost!" % stop_count, Color(0.9, 0.2, 0.2))
		TurnState.BANKED:
			pass  # Already set in _on_bank_pressed

func _on_run_ended() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	new_run_button.visible = true
	hud.show_status("RUN OVER — out of lives!", Color(0.9, 0.2, 0.2))

func _on_stage_cleared() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	new_run_button.visible = true
	hud.show_status("STAGE CLEARED!", Color(0.3, 0.9, 0.3))

func _on_new_run_pressed() -> void:
	var snapshot: Resource = SaveManager.make_run_snapshot()
	SaveManager.record_run(snapshot)
	GameManager.reset_run()
	_run_active = true
	turn_number = 0
	new_run_button.visible = false
	_build_dice_pool()
	_start_new_turn()

func _sync_buttons() -> void:
	if not _run_active:
		roll_button.disabled = true
		bank_button.disabled = true
		return
	match turn_state:
		TurnState.IDLE:
			roll_button.text     = "Roll All"
			roll_button.disabled = false
			bank_button.disabled = true
		TurnState.ACTIVE:
			roll_button.text     = "Reroll Selected"
			roll_button.disabled = false
			bank_button.disabled = false
		TurnState.BUST, TurnState.BANKED:
			roll_button.text     = "New Turn"
			roll_button.disabled = false
			bank_button.disabled = true
