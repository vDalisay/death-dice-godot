class_name RollPhase
extends Control
## Turn state machine for the Cubitos-style dice rolling phase.
## Owns dice logic. Delegates visuals to DiceTray and HUD.

const BASE_BUST_THRESHOLD: int = 3

enum TurnState { IDLE, ACTIVE, BUST, BANKED }

@onready var _roll_content: MarginContainer = $MarginContainer
@onready var hud: HUD           = $MarginContainer/VBoxContainer/HUD
@onready var dice_tray: DiceTray = $MarginContainer/VBoxContainer/DiceTray
@onready var roll_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RollButton
@onready var bank_button: Button = $MarginContainer/VBoxContainer/ButtonRow/BankButton
@onready var new_run_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NewRunButton
@onready var shop_panel: ShopPanel = $ShopPanel

var turn_state: TurnState = TurnState.IDLE
var turn_number: int = 0

# Per-die state arrays (same length as GameManager.dice_pool).
var current_results: Array[DiceFaceData] = []
var dice_stopped: Array[bool] = []
var dice_keep: Array[bool] = []
var dice_keep_locked: Array[bool] = []

## Running total of STOP faces rolled this turn. Only increases; resets on
## bank, bust, or new turn. Used for the accumulated bust check.
var accumulated_stop_count: int = 0

var _run_active: bool = true
var _loop_complete_pending: bool = false

func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	dice_tray.die_toggled.connect(_on_die_toggled)
	shop_panel.shop_closed.connect(_on_shop_closed)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	new_run_button.visible = false
	_start_new_turn()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _start_new_turn() -> void:
	turn_state = TurnState.IDLE
	turn_number += 1
	accumulated_stop_count = 0
	var count: int = GameManager.dice_pool.size()
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
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and (face.type == DiceFaceData.FaceType.NUMBER or face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.EXPLODE or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT):
			dice_tray.pop_die(i)
	var banked: int = _calculate_turn_score()
	GameManager.add_score(banked)
	turn_state = TurnState.BANKED
	var mult: int = _get_turn_multiplier()
	var mult_text: String = " (x%d!)" % mult if mult > 1 else ""
	hud.show_status("Banked %d points%s!  Total: %d" % [banked, mult_text, GameManager.total_score], Color(0.3, 0.9, 0.3))
	_sync_buttons()

func _on_die_toggled(die_index: int, is_kept: bool) -> void:
	if turn_state != TurnState.ACTIVE:
		return
	if dice_keep_locked[die_index]:
		return
	# Allow picking up stopped dice (Cubitos-style rerollable stops)
	if dice_stopped[die_index] and not is_kept:
		dice_stopped[die_index] = false
		dice_keep[die_index] = false
		_sync_all_dice()
		_sync_ui()
		return
	if dice_stopped[die_index]:
		return
	dice_keep[die_index] = is_kept
	_sync_ui()

# ---------------------------------------------------------------------------
# Rolling logic
# ---------------------------------------------------------------------------

func _roll_all_dice() -> void:
	var indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		current_results[i] = GameManager.dice_pool[i].roll()
		indices.append(i)
	_process_roll_results(indices)

func _reroll_selected_dice() -> void:
	# Lock all currently-kept dice permanently before rerolling.
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] and not dice_keep_locked[i]:
			dice_keep_locked[i] = true
	var rerolled: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] or dice_keep_locked[i]:
			continue
		# Stopped dice are rerolled too (Cubitos-style: pick them up and retry)
		if dice_stopped[i]:
			dice_stopped[i] = false
		current_results[i] = GameManager.dice_pool[i].roll()
		rerolled.append(i)
	if rerolled.is_empty():
		# No dice to reroll — all are kept/locked, so auto-bank.
		_on_bank_pressed()
		return
	_process_roll_results(rerolled)

func _process_roll_results(rolled_indices: Array[int]) -> void:
	# Track which dice need chain re-rolls (EXPLODE faces)
	var chain_reroll: Array[int] = []

	for i: int in rolled_indices:
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT:
				dice_keep[i] = true
				dice_keep_locked[i] = true
				dice_tray.pop_die(i)
			DiceFaceData.FaceType.EXPLODE:
				# EXPLODE: score its value AND chain-reroll this die
				dice_keep[i] = true
				dice_keep_locked[i] = true
				dice_tray.pop_die(i)
				chain_reroll.append(i)
			_:
				if not dice_keep_locked[i]:
					dice_keep[i] = false

	# Accumulated bust check: add new stops from this roll to running total
	accumulated_stop_count += _count_stops_in(rolled_indices)
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var threshold: int = _get_bust_threshold()
	if effective_stops >= threshold and turn_number > 1:
		turn_state = TurnState.BUST
		GameManager.lose_life()
	else:
		turn_state = TurnState.ACTIVE

	_sync_all_dice()
	_sync_ui()

	if turn_number == 1 and effective_stops >= threshold:
		hud.show_status("Close call! Turn 1 — no bust this time.", Color(1.0, 0.85, 0.0))

	var roll_stop_count: int = _count_stops_in(rolled_indices)
	if shield_count > 0 and roll_stop_count > 0 and roll_stop_count > maxi(0, roll_stop_count - shield_count):
		var shielded: int = roll_stop_count - maxi(0, roll_stop_count - shield_count)
		hud.show_status("Shields absorbed %d stop(s)!" % shielded, Color(0.3, 0.7, 1.0))

	# Handle EXPLODE chain re-rolls (free extra rolls, not counted toward bust)
	if turn_state == TurnState.ACTIVE and not chain_reroll.is_empty():
		_process_explode_chains(chain_reroll)
		return

	if turn_state == TurnState.ACTIVE and _all_dice_resolved():
		_on_bank_pressed()

# ---------------------------------------------------------------------------
# Score / helpers
# ---------------------------------------------------------------------------

func _all_dice_resolved() -> bool:
	for i: int in GameManager.dice_pool.size():
		if not dice_stopped[i] and not dice_keep[i]:
			return false
	return true

func _calculate_turn_score() -> int:
	var pool_size: int = GameManager.dice_pool.size()
	# Pass 1: compute per-die base scores
	var base_scores: Array[int] = []
	base_scores.resize(pool_size)
	base_scores.fill(0)
	var multiplier: int = 1
	for i: int in pool_size:
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.NUMBER, DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.EXPLODE:
				base_scores[i] = face.value
			DiceFaceData.FaceType.MULTIPLY:
				multiplier *= face.value
	# Pass 2: apply MULTIPLY_LEFT — multiply the left neighbor's base score
	for i: int in pool_size:
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY_LEFT and i > 0 and not dice_stopped[i - 1]:
			base_scores[i - 1] *= face.value
	# Sum all per-die scores, then apply global multiplier
	var score: int = 0
	for s: int in base_scores:
		score += s
	return score * multiplier

func _count_stops() -> int:
	var count: int = 0
	for stopped: bool in dice_stopped:
		if stopped:
			count += 1
	return count

## Count stops only among the specified dice indices (per-roll bust check).
func _count_stops_in(indices: Array[int]) -> int:
	var count: int = 0
	for i: int in indices:
		if dice_stopped[i]:
			count += 1
	return count

func _count_shields() -> int:
	var count: int = 0
	for i: int in GameManager.dice_pool.size():
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.SHIELD:
			count += face.value
	return count

func _get_turn_multiplier() -> int:
	var multiplier: int = 1
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.MULTIPLY:
			multiplier *= face.value
	return multiplier

## EXPLODE chain: re-roll each exploding die. If it lands EXPLODE again, chain.
## Chains are free rolls (not counted toward bust). Capped to prevent infinite loops.
func _process_explode_chains(exploding_indices: Array[int]) -> void:
	var chain_depth: int = 0
	var to_reroll: Array[int] = exploding_indices.duplicate()
	while not to_reroll.is_empty() and chain_depth < DiceData.MAX_CHAIN_ROLLS:
		chain_depth += 1
		var next_chain: Array[int] = []
		for i: int in to_reroll:
			# Unlock the die for chain reroll
			dice_keep[i] = false
			dice_keep_locked[i] = false
			current_results[i] = GameManager.dice_pool[i].roll()
			var face: DiceFaceData = current_results[i]
			if face.type == DiceFaceData.FaceType.EXPLODE:
				# Chain continues! Score and reroll again.
				dice_keep[i] = true
				dice_keep_locked[i] = true
				dice_tray.pop_die(i)
				next_chain.append(i)
			elif face.type == DiceFaceData.FaceType.STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
				accumulated_stop_count += 1
			elif face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT:
				dice_keep[i] = true
				dice_keep_locked[i] = true
				dice_tray.pop_die(i)
			else:
				if not dice_keep_locked[i]:
					dice_keep[i] = false
		to_reroll = next_chain

	_sync_all_dice()
	_sync_ui()

	if chain_depth > 0:
		hud.show_status("💥 Chain x%d!" % chain_depth, Color(1.0, 0.5, 0.0))

	if turn_state == TurnState.ACTIVE and _all_dice_resolved():
		_on_bank_pressed()

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
	if face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.EXPLODE or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT:
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
	for i: int in GameManager.dice_pool.size():
		dice_tray.update_die(i, current_results[i], _die_visual_state(i))

func _sync_ui() -> void:
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var turn_score: int = _calculate_turn_score()
	hud.update_turn(turn_score, effective_stops, _get_bust_threshold())
	_sync_buttons()

	match turn_state:
		TurnState.IDLE:
			hud.show_status("Press 'Roll All' to begin your turn!")
		TurnState.ACTIVE:
			hud.show_status("Green = keep · Orange = reroll · Red = pick up to reroll")
		TurnState.BUST:
			hud.show_status("BUST! %d stops — turn score lost!" % effective_stops, Color(0.9, 0.2, 0.2))
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
	GameManager.add_gold(GameManager.get_stage_clear_bonus())
	if GameManager.is_final_stage():
		hud.show_status(
			"LOOP %d COMPLETE! Entering Loop %d..." % [GameManager.current_loop, GameManager.current_loop + 1],
			Color(1.0, 0.85, 0.0))
		_open_shop(true)
	else:
		_open_shop(false)

func _open_shop(is_loop_complete: bool = false) -> void:
	_loop_complete_pending = is_loop_complete
	_roll_content.visible = false
	shop_panel.open(GameManager.current_stage, is_loop_complete)

func _on_shop_closed() -> void:
	if _loop_complete_pending:
		GameManager.advance_loop()
		_loop_complete_pending = false
	else:
		GameManager.advance_stage()
	shop_panel.visible = false
	_roll_content.visible = true
	_run_active = true
	turn_number = 0
	_start_new_turn()

func _on_new_run_pressed() -> void:
	var snapshot: Resource = SaveManager.make_run_snapshot()
	SaveManager.record_run(snapshot)
	GameManager.reset_run()
	_run_active = true
	turn_number = 0
	new_run_button.visible = false
	shop_panel.visible = false
	_roll_content.visible = true
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
