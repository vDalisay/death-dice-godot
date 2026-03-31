class_name RollPhase
extends Control
## Turn state machine for the Cubitos-style dice rolling phase.
## Owns dice logic. Delegates visuals to DiceArena and HUD.

const BASE_BUST_THRESHOLD: int = 3
const AUTO_ADVANCE_DELAY: float = 1.5
const MAX_SCORE_ANIM_DURATION: float = 2.0
const HOT_STREAK_TIER_1: int = 3
const HOT_STREAK_TIER_2: int = 5
const HOT_STREAK_MULT_1: float = 1.1
const HOT_STREAK_MULT_2: float = 1.2
const JACKPOT_MIN_DICE: int = 5
const JACKPOT_GOLD_BONUS: float = 0.25
const POST_ROLL_EFFECT_LOCK_DURATION: float = 0.2
const BANK_CASCADE_STEP_DELAY: float = 0.22
const SHAKE_ROLL: float = 2.0
const SHAKE_STOP: float = 3.0
const SHAKE_CURSED_STOP: float = 5.0
const SHAKE_BUST: float = 8.0
const SHAKE_BIG_BANK: float = 4.0

const BUTTON_HOVER_SCALE: float = 1.03
const BUTTON_PRESS_SCALE: float = 0.96
const BUTTON_TWEEN_DURATION: float = 0.08

enum TurnState { IDLE, ACTIVE, BUST, BANKED }

@onready var _roll_content: MarginContainer = $MarginContainer
@onready var hud: HUD           = $MarginContainer/VBoxContainer/HUD
@onready var dice_arena: DiceArena = $MarginContainer/VBoxContainer/ArenaViewportContainer/ArenaViewport/DiceArena
@onready var roll_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RollButton
@onready var bank_button: Button = $MarginContainer/VBoxContainer/ButtonRow/BankButton
@onready var new_run_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NewRunButton
@onready var career_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CareerButton
@onready var codex_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CodexButton
@onready var shop_panel: ShopPanel = $ShopPanel
@onready var career_panel: CareerPanel = $CareerPanel
@onready var codex_panel: DiceCodexPanel = $DiceCodexPanel
@onready var highlights_panel: HighlightsPanel = $HighlightsPanel
@onready var forge_panel: ForgePanel = $ForgePanel

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
var bank_streak: int = 0
var _reroll_count: int = 0
var _streak_display: Control = null
var _run_snapshot_recorded: bool = false
var _is_roll_animating: bool = false
var _roll_anim_nonce: int = 0
var _triggered_combo_ids: Dictionary = {}
var _screen_shake: Node = null
var _screen_overlay: Node = null

const StreakDisplayScript: GDScript = preload("res://Scripts/StreakDisplay.gd")
const BustOverlayScene: PackedScene = preload("res://Scenes/BustOverlay.tscn")
const StageClearedScene: PackedScene = preload("res://Scenes/StageCleared.tscn")
const AchievementToastScene: PackedScene = preload("res://Scenes/AchievementToast.tscn")
const ScreenShakeScript: GDScript = preload("res://Scripts/ScreenShake.gd")
const ScreenOverlayScript: GDScript = preload("res://Scripts/ScreenOverlay.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")

func _ready() -> void:
	theme = _UITheme.build_theme()
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	career_button.pressed.connect(_on_career_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	dice_arena.die_clicked.connect(_on_die_toggled)
	dice_arena.all_dice_settled.connect(_on_all_dice_settled)
	dice_arena.die_collision_rerolled.connect(_on_die_collision_rerolled)
	shop_panel.shop_closed.connect(_on_shop_closed)
	career_panel.closed.connect(_on_career_closed)
	codex_panel.closed.connect(_on_codex_closed)
	highlights_panel.closed.connect(_on_highlights_closed)
	forge_panel.forge_closed.connect(_on_forge_closed)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	new_run_button.visible = false
	career_button.visible = false
	codex_button.visible = false
	_streak_display = StreakDisplayScript.new()
	hud.attach_streak_display(_streak_display)
	_screen_shake = ScreenShakeScript.new()
	add_child(_screen_shake)
	_screen_shake.setup(_roll_content)
	_screen_overlay = ScreenOverlayScript.new()
	add_child(_screen_overlay)
	_add_button_micro_tween(roll_button)
	_add_button_micro_tween(bank_button)
	_add_button_micro_tween(new_run_button)
	_add_button_micro_tween(career_button)
	_add_button_micro_tween(codex_button)
	if GameManager.skip_archetype_picker:
		_start_new_turn()
	elif SaveManager.run_history.is_empty():
		# First run ever — skip archetype picker, use default Caution.
		GameManager.chosen_archetype = GameManager.Archetype.CAUTION
		GameManager.reset_run()
		_run_snapshot_recorded = false
		_run_active = true
		_start_new_turn()
	else:
		_show_archetype_picker()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _start_new_turn() -> void:
	turn_state = TurnState.IDLE
	turn_number += 1
	accumulated_stop_count = 0
	_reroll_count = 0
	_triggered_combo_ids.clear()
	hud.set_active_combos([])
	var count: int = GameManager.dice_pool.size()
	current_results.resize(count)
	current_results.fill(null)
	dice_stopped.resize(count)
	dice_stopped.fill(false)
	dice_keep.resize(count)
	dice_keep.fill(false)
	dice_keep_locked.resize(count)
	dice_keep_locked.fill(false)
	dice_arena.reset()
	_sync_ui()

# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	if not _run_active:
		return
	if _is_roll_animating:
		return
	match turn_state:
		TurnState.IDLE:
			_roll_all_dice()
		TurnState.ACTIVE:
			_reroll_selected_dice()

func _on_bank_pressed() -> void:
	if turn_state != TurnState.ACTIVE:
		return
	turn_state = TurnState.BANKED
	bank_streak += 1
	_update_streak_display()
	var base_banked: int = _calculate_turn_score()
	# Iron Bank: +50% score if no rerolls.
	if GameManager.has_modifier(RunModifier.ModifierType.IRON_BANK) and _reroll_count == 0:
		base_banked = int(base_banked * 1.5)
	# Hot Streak multiplier: 3+ consecutive banks = x1.1, 5+ = x1.2.
	var streak_mult: float = _get_streak_multiplier()
	var banked: int = int(base_banked * streak_mult)
	var old_total: int = GameManager.total_score
	GameManager.add_score(banked)
	# Gambler's Rush: +1g per survived stop.
	if GameManager.has_modifier(RunModifier.ModifierType.GAMBLERS_RUSH) and accumulated_stop_count > 0:
		var rush_gold: int = accumulated_stop_count
		GameManager.add_gold(rush_gold)
	# Jackpot check: first roll only (no rerolls), 5+ dice, 0 stops.
	var is_jackpot: bool = _reroll_count == 0 and GameManager.dice_pool.size() >= JACKPOT_MIN_DICE and accumulated_stop_count == 0
	AchievementManager.on_bank(banked, _reroll_count, accumulated_stop_count, GameManager.dice_pool.size(), bank_streak)
	if is_jackpot:
		var jackpot_gold: int = maxi(1, int(banked * JACKPOT_GOLD_BONUS))
		GameManager.add_gold(jackpot_gold)
		SFXManager.play_jackpot()
		if _screen_overlay and _screen_overlay.has_method("flash_jackpot"):
			_screen_overlay.flash_jackpot()
		_spawn_jackpot_confetti()
		hud.show_status("JACKPOT! +%dg bonus!" % jackpot_gold, Color(1.0, 0.85, 0.0))
	var mult: int = _get_turn_multiplier()
	var status_parts: Array[String] = []
	var mult_text: String = " (x%d!)" % mult if mult > 1 else ""
	if streak_mult > 1.0:
		status_parts.append("ON FIRE x%.1f" % streak_mult)
	status_parts.append("Banked %d points%s!  Total: %d" % [banked, mult_text, GameManager.total_score])
	if not is_jackpot:
		hud.show_status(" | ".join(status_parts), Color(0.3, 0.9, 0.3))
	SFXManager.play_bank()
	# Personal best turn score check.
	if banked > GameManager.best_turn_score:
		GameManager.best_turn_score = banked
		hud.show_status("NEW BEST TURN! %d pts" % banked, Color(1.0, 0.85, 0.0))
		SFXManager.play_personal_best()
	if banked >= 50:
		_shake_screen(SHAKE_BIG_BANK, 0.2)
	_play_multiply_face_vfx()
	# Per-die score count-up followed by cascade checkpoints.
	_play_bank_cascade_animation(old_total, GameManager.total_score, mult, streak_mult)
	_sync_buttons()
	# Auto-advance to next turn after a delay.
	_schedule_auto_advance()

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
	_begin_roll_animation_lock()
	_shake_screen(SHAKE_ROLL, 0.15)
	# Throw all dice into the arena — faces are rolled inside throw_dice
	dice_arena.throw_dice(GameManager.dice_pool)
	# Results will be processed when all_dice_settled signal fires

func _reroll_selected_dice() -> void:
	_reroll_count += 1
	# Lock all currently-kept dice permanently before rerolling.
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] and not dice_keep_locked[i]:
			dice_keep_locked[i] = true
			dice_arena.lock_die(i)
			var locked_die: PhysicsDie = dice_arena.get_die(i)
			if locked_die:
				locked_die.play_keep_lock_snap()

	var rerolled: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] or dice_keep_locked[i]:
			continue
		# Stopped dice are rerolled too (Cubitos-style: pick them up and retry)
		if dice_stopped[i]:
			dice_stopped[i] = false
		rerolled.append(i)
	if rerolled.is_empty():
		# No dice to reroll — all are kept/locked, so auto-bank.
		_on_bank_pressed()
		return
	_begin_roll_animation_lock()
	dice_arena.reroll_dice(rerolled, GameManager.dice_pool)
	# Results will be processed when all_dice_settled signal fires


## Called when all dice in the arena have stopped moving.
func _on_all_dice_settled() -> void:
	# Read final faces from the arena (only for non-locked dice; locked keep their result)
	var arena_results: Array[DiceFaceData] = dice_arena.get_results()
	for i: int in arena_results.size():
		if not dice_keep_locked[i]:
			current_results[i] = arena_results[i]
	# Determine which indices to process (all non-locked dice)
	var rolled_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		if not dice_keep_locked[i]:
			rolled_indices.append(i)
	if rolled_indices.is_empty():
		rolled_indices = range(GameManager.dice_pool.size()) as Array[int]
	_process_roll_results(rolled_indices)


## Called when a collision reroll happens during the rolling phase (cosmetic only).
func _on_die_collision_rerolled(die_index: int, new_face: DiceFaceData) -> void:
	# Update our tracking — cosmetic only, stops are NOT accumulated
	current_results[die_index] = new_face

func _process_roll_results(rolled_indices: Array[int]) -> void:
	if not rolled_indices.is_empty():
		_begin_roll_animation_lock()
	# Track which dice need chain re-rolls (EXPLODE faces)
	var chain_reroll: Array[int] = []

	for i: int in rolled_indices:
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.STOP, DiceFaceData.FaceType.CURSED_STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT, DiceFaceData.FaceType.INSURANCE:
				dice_keep[i] = true
				dice_keep_locked[i] = true
			DiceFaceData.FaceType.EXPLODE:
				# EXPLODE: score its value AND chain-reroll this die
				dice_keep[i] = true
				dice_keep_locked[i] = true
				chain_reroll.append(i)
			_:
				if not dice_keep_locked[i]:
					dice_keep[i] = false

	# Update arena die visuals for rolled dice
	for i: int in rolled_indices:
		var die: PhysicsDie = dice_arena.get_die(i)
		if die:
			die.show_face(current_results[i])
			_sync_arena_die_state(i)
			var face: DiceFaceData = current_results[i]
			if face and (face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP):
				die.play_stop_impact(face.type == DiceFaceData.FaceType.CURSED_STOP)
				if face.type == DiceFaceData.FaceType.CURSED_STOP:
					SFXManager.play_cursed_stop()
				else:
					SFXManager.play_stop_face()
			if face and (face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD \
					or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT \
					or face.type == DiceFaceData.FaceType.INSURANCE or face.type == DiceFaceData.FaceType.EXPLODE):
				die.pop()

	# Accumulated bust check: add new stops from this roll to running total
	accumulated_stop_count += _count_stops_in(rolled_indices)
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var threshold: int = _get_bust_threshold()
	var immune_turns: int = 3 if GameManager.chosen_archetype == GameManager.Archetype.CAUTION else 1
	var is_immune: bool = turn_number <= immune_turns and GameManager.current_stage == 1
	if effective_stops >= threshold and not is_immune:
		var insurance_index: int = _find_insurance_face_index()
		if insurance_index >= 0:
			_consume_insurance_face(insurance_index)
			_sync_arena_die_state(insurance_index)
			turn_state = TurnState.BANKED
			bank_streak = 0
			_update_streak_display()
			hud.show_status("INSURANCE TRIGGERED! Bust canceled; turn score forfeited.", Color(0.4, 0.8, 1.0))
			SFXManager.play_close_call()
			_sync_buttons()
			_schedule_auto_advance()
		else:
			turn_state = TurnState.BUST
			bank_streak = 0
			_update_streak_display()
			GameManager.lose_life()
			AchievementManager.on_bust()
			SFXManager.play_bust()
			_show_bust_overlay(effective_stops)
			_sync_buttons()
			_schedule_auto_advance()
	else:
		turn_state = TurnState.ACTIVE

	# Sync non-rolled dice visuals.
	for i: int in GameManager.dice_pool.size():
		if i not in rolled_indices:
			_sync_arena_die_state(i)
	_sync_ui()

	# Status messages based on roll outcome.
	if turn_state == TurnState.BUST:
		pass  # Bust overlay handles messaging.
	elif is_immune and effective_stops >= threshold:
		hud.show_status("CLOSE CALL! Turn %d — no bust this time." % turn_number, Color(1.0, 0.6, 0.0))
	elif effective_stops == threshold - 1 and threshold > 1 and turn_number > 1:
		hud.show_status("CLOSE CALL! One more stop and you bust!", Color(1.0, 0.6, 0.0))
		SFXManager.play_close_call()
	elif effective_stops == 0 and rolled_indices.size() > 0:
		hud.show_status("CLEAN ROLL! No stops!", Color(0.3, 1.0, 0.3))
		SFXManager.play_clean_roll()

	var roll_stop_count: int = _count_stops_in(rolled_indices)
	if roll_stop_count > 0:
		var has_cursed: bool = false
		for i: int in rolled_indices:
			var f: DiceFaceData = current_results[i]
			if f != null and f.type == DiceFaceData.FaceType.CURSED_STOP:
				has_cursed = true
				break
		_shake_screen(SHAKE_CURSED_STOP if has_cursed else SHAKE_STOP, 0.12 if has_cursed else 0.1)
	if shield_count > 0 and roll_stop_count > 0 and roll_stop_count > maxi(0, roll_stop_count - shield_count):
		var shielded: int = roll_stop_count - maxi(0, roll_stop_count - shield_count)
		hud.show_status("Shields absorbed %d stop(s)!" % shielded, Color(0.3, 0.7, 1.0))
		for i: int in GameManager.dice_pool.size():
			var shield_face: DiceFaceData = current_results[i]
			if shield_face != null and shield_face.type == DiceFaceData.FaceType.SHIELD:
				var shield_die: PhysicsDie = dice_arena.get_die(i)
				if shield_die:
					shield_die.play_shield_absorb()
		SFXManager.play_shield_absorb()

	# Handle EXPLODE chain re-rolls (free extra rolls, not counted toward bust)
	if turn_state == TurnState.ACTIVE and not chain_reroll.is_empty():
		_process_explode_chains(chain_reroll)
		return

	_check_roll_combos()
	_release_roll_animation_lock(POST_ROLL_EFFECT_LOCK_DURATION)

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
	var glass_cannon: bool = GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON)
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
			DiceFaceData.FaceType.NUMBER:
				base_scores[i] = face.value + (2 if glass_cannon else 0)
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.EXPLODE:
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
## CURSED_STOP counts as 2 stops.
func _count_stops_in(indices: Array[int]) -> int:
	var count: int = 0
	for i: int in indices:
		if dice_stopped[i]:
			var face: DiceFaceData = current_results[i]
			if face != null and face.type == DiceFaceData.FaceType.CURSED_STOP:
				count += 2
			else:
				count += 1
	return count

func _count_shields() -> int:
	var count: int = 0
	var multiplier: int = 2 if GameManager.has_modifier(RunModifier.ModifierType.SHIELD_WALL) else 1
	for i: int in GameManager.dice_pool.size():
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.SHIELD:
			count += face.value * multiplier
	return count


func _find_insurance_face_index() -> int:
	for i: int in GameManager.dice_pool.size():
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.INSURANCE:
			return i
	return -1


func _consume_insurance_face(die_index: int) -> void:
	var face: DiceFaceData = current_results[die_index]
	if face == null:
		return
	var die: PhysicsDie = dice_arena.get_die(die_index)
	if die:
		die.play_insurance_trigger()
	SFXManager.play_insurance_trigger()
	face.type = DiceFaceData.FaceType.BLANK
	face.value = 0
	dice_keep[die_index] = true
	dice_keep_locked[die_index] = true

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
			var die: PhysicsDie = dice_arena.get_die(i)
			if face.type == DiceFaceData.FaceType.EXPLODE:
				# Chain continues! Score and reroll again.
				dice_keep[i] = true
				dice_keep_locked[i] = true
				if die:
					_shake_screen(2.0 + float(chain_depth) * 0.5, 0.1)
					die.play_explode_charge()
					die.tumble(face)
					die.pop()
					die.show_chain_label(chain_depth)
				next_chain.append(i)
			elif face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
				accumulated_stop_count += 2 if face.type == DiceFaceData.FaceType.CURSED_STOP else 1
				if die:
					die.play_stop_impact(face.type == DiceFaceData.FaceType.CURSED_STOP)
					die.tumble(face)
					_sync_arena_die_state(i)
			elif face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT or face.type == DiceFaceData.FaceType.INSURANCE:
				dice_keep[i] = true
				dice_keep_locked[i] = true
				if die:
					die.tumble(face)
					die.pop()
			else:
				if not dice_keep_locked[i]:
					dice_keep[i] = false
				if die:
					die.tumble(face)
					_sync_arena_die_state(i)
		to_reroll = next_chain

	# Explosophile: after chains end, reroll 1 extra un-resolved die for free.
	if chain_depth > 0 and GameManager.has_modifier(RunModifier.ModifierType.EXPLOSOPHILE):
		var candidates: Array[int] = []
		for i: int in GameManager.dice_pool.size():
			if not dice_keep[i] and not dice_keep_locked[i] and not dice_stopped[i]:
				candidates.append(i)
		if not candidates.is_empty():
			var extra_i: int = candidates[randi() % candidates.size()]
			current_results[extra_i] = GameManager.dice_pool[extra_i].roll()
			var extra_face: DiceFaceData = current_results[extra_i]
			var extra_die: PhysicsDie = dice_arena.get_die(extra_i)
			if extra_face.type == DiceFaceData.FaceType.STOP or extra_face.type == DiceFaceData.FaceType.CURSED_STOP:
				dice_stopped[extra_i] = true
				accumulated_stop_count += 2 if extra_face.type == DiceFaceData.FaceType.CURSED_STOP else 1
				if extra_die:
					extra_die.play_stop_impact(extra_face.type == DiceFaceData.FaceType.CURSED_STOP)
			elif extra_face.type in [DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.EXPLODE]:
				dice_keep[extra_i] = true
				dice_keep_locked[extra_i] = true
			if extra_die:
				extra_die.tumble(extra_face)
				_sync_arena_die_state(extra_i)

	_sync_all_dice()
	_sync_ui()

	if chain_depth > 0:
		SFXManager.play_explode(chain_depth)
		hud.show_status("CHAIN x%d!" % chain_depth, Color(1.0, 0.5, 0.0))

	_check_roll_combos()
	_release_roll_animation_lock(POST_ROLL_EFFECT_LOCK_DURATION)

	if turn_state == TurnState.ACTIVE and _all_dice_resolved():
		_on_bank_pressed()

func _check_roll_combos() -> void:
	if turn_state != TurnState.ACTIVE:
		return
	var combos: Array[RollCombo] = RollComboRegistry.get_triggered_combos(current_results, dice_stopped)
	for combo: RollCombo in combos:
		if combo == null or combo.combo_id.is_empty() or _triggered_combo_ids.has(combo.combo_id):
			continue
		_triggered_combo_ids[combo.combo_id] = true
		hud.flash_combo(combo.display_name, combo.flash_color, combo.combo_id)
	_update_combo_hud()


func _update_combo_hud() -> void:
	var active_combos: Array[RollCombo] = []
	var all_combos: Array[RollCombo] = RollComboRegistry.get_all_combos()
	for combo: RollCombo in all_combos:
		if combo != null and not combo.combo_id.is_empty() and _triggered_combo_ids.has(combo.combo_id):
			active_combos.append(combo)
	hud.set_active_combos(active_combos)


func _get_bust_threshold() -> int:
	var base: int = BASE_BUST_THRESHOLD
	if turn_number <= 3:
		base += 1   # Lenient: 4
	# Glass Cannon: threshold -1
	if GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON):
		base = maxi(1, base - 1)
	return base


func _get_streak_multiplier() -> float:
	if bank_streak >= HOT_STREAK_TIER_2:
		return HOT_STREAK_MULT_2
	elif bank_streak >= HOT_STREAK_TIER_1:
		return HOT_STREAK_MULT_1
	return 1.0


func _update_streak_display() -> void:
	if _streak_display != null:
		_streak_display.update_streak(bank_streak, _get_streak_multiplier())


func _get_bust_risk_text(effective_stops: int, threshold: int) -> String:
	if effective_stops == 0:
		return "Bust risk: LOW"
	elif effective_stops >= threshold - 1:
		return "Bust risk: HIGH"
	else:
		return "Bust risk: MEDIUM"


func _estimate_next_reroll_bust_chance(effective_stops: int, threshold: int) -> float:
	var stops_needed: int = threshold - effective_stops
	if stops_needed <= 0:
		return 1.0
	var distribution: Array[float] = [1.0]
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] or dice_keep_locked[i]:
			continue
		var die_data: DiceData = GameManager.dice_pool[i]
		if die_data == null or die_data.faces.is_empty():
			continue
		var face_count: float = float(die_data.faces.size())
		var p0: float = 0.0
		var p1: float = 0.0
		var p2: float = 0.0
		for face: DiceFaceData in die_data.faces:
			if face == null:
				continue
			match face.type:
				DiceFaceData.FaceType.CURSED_STOP:
					p2 += 1.0 / face_count
				DiceFaceData.FaceType.STOP:
					p1 += 1.0 / face_count
				_:
					p0 += 1.0 / face_count
		var next_dist: Array[float] = []
		next_dist.resize(distribution.size() + 2)
		next_dist.fill(0.0)
		for s: int in distribution.size():
			var base_prob: float = distribution[s]
			next_dist[s] += base_prob * p0
			next_dist[s + 1] += base_prob * p1
			next_dist[s + 2] += base_prob * p2
		distribution = next_dist
	var chance: float = 0.0
	for s: int in distribution.size():
		if s >= stops_needed:
			chance += distribution[s]
	return clampf(chance, 0.0, 1.0)


func _estimate_bust_odds(effective_stops: int, threshold: int) -> float:
	var next_roll_chance: float = _estimate_next_reroll_bust_chance(effective_stops, threshold)
	var horizon_rolls: int = maxi(1, _reroll_count + 1)
	var survive_all: float = pow(1.0 - next_roll_chance, float(horizon_rolls))
	return clampf(1.0 - survive_all, 0.0, 1.0)


func _build_risk_details(effective_stops: int, shield_count: int, threshold: int, bust_odds: float) -> String:
	var rerollable_count: int = _get_rerollable_count()
	var next_roll_odds: int = int(round(_estimate_next_reroll_bust_chance(effective_stops, threshold) * 100.0))
	var projected_odds: int = int(round(bust_odds * 100.0))
	return "Bust odds (next reroll): %d%%\nProjected odds (current reroll streak): %d%%\nStops: %d/%d (shields: %d)\nRerollable dice: %d | Rerolls taken: %d" % [
		next_roll_odds,
		projected_odds,
		effective_stops,
		threshold,
		shield_count,
		rerollable_count,
		_reroll_count,
	]

## Sync the i-th PhysicsDie's visual flags to match RollPhase tracking state.
func _sync_arena_die_state(index: int) -> void:
	var die: PhysicsDie = dice_arena.get_die(index)
	if die == null:
		return
	die.is_stopped = dice_stopped[index]
	die.is_kept = dice_keep[index]
	die.is_keep_locked = dice_keep_locked[index]
	die.show_face(current_results[index])
	die._apply_visual()

# ---------------------------------------------------------------------------
# UI sync
# ---------------------------------------------------------------------------

func _sync_all_dice() -> void:
	for i: int in GameManager.dice_pool.size():
		_sync_arena_die_state(i)

func _sync_ui() -> void:
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var threshold: int = _get_bust_threshold()
	var bust_odds: float = _estimate_bust_odds(effective_stops, threshold)
	var risk_details: String = _build_risk_details(effective_stops, shield_count, threshold, bust_odds)
	var turn_score: int = _calculate_turn_score()
	hud.update_turn(turn_score, effective_stops, threshold, shield_count, _reroll_count, bust_odds, risk_details)
	_sync_buttons()

	match turn_state:
		TurnState.IDLE:
			hud.show_status("Press 'Roll All' to begin your turn!")
		TurnState.ACTIVE:
			pass
		TurnState.BUST:
			hud.show_status("BUST! %d stops — turn score lost!" % effective_stops, Color(0.9, 0.2, 0.2))
		TurnState.BANKED:
			pass  # Already set in _on_bank_pressed

func _on_run_ended() -> void:
	# Capture prior career bests BEFORE recording (so highlights compare against pre-run values).
	var prior_bests: Dictionary = {
		"highscore": SaveManager.highscore,
		"best_stages": SaveManager.total_stages_cleared,
		"best_loop": SaveManager.career_best_loop,
		"best_turn": SaveManager.career_best_turn_score,
	}
	var snapshot: RunSaveData = SaveManager.make_run_snapshot()
	_record_run_snapshot_if_needed()
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	hud.show_status("RUN OVER — out of lives!", Color(0.9, 0.2, 0.2))
	highlights_panel.show_highlights(snapshot, prior_bests)

func _on_highlights_closed() -> void:
	new_run_button.visible = true
	career_button.visible = true
	codex_button.visible = true

func _on_stage_cleared() -> void:
	AchievementManager.on_stage_cleared()
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	var bonus: int = GameManager.get_stage_clear_bonus()
	var surplus: int = GameManager.total_score - GameManager.stage_target_score
	GameManager.add_gold(bonus)
	SFXManager.play_stage_clear()
	var is_loop: bool = GameManager.is_final_stage()
	if is_loop:
		hud.show_status(
			"LOOP %d COMPLETE! Entering Loop %d..." % [GameManager.current_loop, GameManager.current_loop + 1],
			Color(1.0, 0.85, 0.0))
	_show_stage_clear_overlay(bonus, surplus, is_loop)

func _open_shop(is_loop_complete: bool = false) -> void:
	_loop_complete_pending = is_loop_complete
	_roll_content.visible = false
	if _streak_display != null:
		_streak_display.visible = false
	shop_panel.open(GameManager.current_stage, is_loop_complete)

func _on_shop_closed() -> void:
	if _loop_complete_pending:
		GameManager.advance_loop()
		AchievementManager.on_loop_advanced(GameManager.current_loop)
		_loop_complete_pending = false
		# Curse event: ~20% chance on loop transition.
		_maybe_apply_curse()
	else:
		GameManager.advance_stage()
	shop_panel.visible = false
	_roll_content.visible = true
	_update_streak_display()
	_run_active = true
	turn_number = 0
	bank_streak = 0
	_update_streak_display()
	_start_new_turn()

func _on_new_run_pressed() -> void:
	_record_run_snapshot_if_needed()
	new_run_button.visible = false
	career_button.visible = false
	codex_button.visible = false
	shop_panel.visible = false
	_roll_content.visible = true
	_show_archetype_picker()


func _on_career_pressed() -> void:
	career_panel.open_panel()


func _on_career_closed() -> void:
	pass


func _on_codex_pressed() -> void:
	codex_panel.open_panel()


func _on_codex_closed() -> void:
	pass


func _on_achievement_unlocked(_key: String, title: String) -> void:
	var toast: PanelContainer = AchievementToastScene.instantiate() as PanelContainer
	add_child(toast)
	toast.call("show_unlock", title)
	SFXManager.play_achievement_unlock()
	hud.show_status("Achievement Unlocked: %s" % title, Color(1.0, 0.85, 0.0))

func _sync_buttons() -> void:
	if not _run_active:
		roll_button.disabled = true
		bank_button.disabled = true
		return
	match turn_state:
		TurnState.IDLE:
			roll_button.text     = "Roll All"
			roll_button.disabled = _is_roll_animating
			bank_button.disabled = true
		TurnState.ACTIVE:
			roll_button.text     = "Reroll %d" % _get_rerollable_count()
			roll_button.disabled = _is_roll_animating
			bank_button.disabled = false
		TurnState.BUST, TurnState.BANKED:
			roll_button.text     = "Roll All"
			roll_button.disabled = true
			bank_button.disabled = true


func _begin_roll_animation_lock() -> void:
	_is_roll_animating = true
	_roll_anim_nonce += 1
	_sync_buttons()


func _release_roll_animation_lock(delay: float = 0.0) -> void:
	var nonce: int = _roll_anim_nonce
	if delay <= 0.0:
		if nonce != _roll_anim_nonce:
			return
		_is_roll_animating = false
		_sync_buttons()
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if nonce != _roll_anim_nonce:
			return
		_is_roll_animating = false
		_sync_buttons()
	)


func _get_rerollable_count() -> int:
	var count: int = 0
	for i: int in GameManager.dice_pool.size():
		if not dice_keep[i] and not dice_keep_locked[i]:
			count += 1
	return count

# ---------------------------------------------------------------------------
# Auto-advance & per-die score animation
# ---------------------------------------------------------------------------

func _schedule_auto_advance() -> void:
	if not _run_active:
		return
	get_tree().create_timer(AUTO_ADVANCE_DELAY).timeout.connect(
		func() -> void:
			if turn_state == TurnState.BANKED or turn_state == TurnState.BUST:
				_start_new_turn()
	)


## Play left-to-right per-die score popups, then the total score tween.
func _play_score_count_animation(old_total: int, new_total: int) -> void:
	var pool_size: int = GameManager.dice_pool.size()
	var per_die: Array[int] = _get_per_die_scores()

	# Compute which dice have a non-zero contribution.
	var scoring_indices: Array[int] = []
	for i: int in pool_size:
		if per_die[i] > 0:
			scoring_indices.append(i)
	scoring_indices.sort_custom(func(a: int, b: int) -> bool:
		var die_a: PhysicsDie = dice_arena.get_die(a)
		var die_b: PhysicsDie = dice_arena.get_die(b)
		var a_x: float = die_a.global_position.x if die_a else float(a)
		var b_x: float = die_b.global_position.x if die_b else float(b)
		return a_x < b_x
	)

	if scoring_indices.is_empty():
		hud.animate_score_count(old_total, new_total)
		hud.show_floating_gold(new_total - old_total)
		return

	# Time per die: never exceed MAX_SCORE_ANIM_DURATION total.
	var interval: float = minf(0.15, MAX_SCORE_ANIM_DURATION / float(scoring_indices.size()))
	var tween: Tween = create_tween()
	var running: int = old_total
	for idx: int in scoring_indices.size():
		var die_i: int = scoring_indices[idx]
		var die_score: int = per_die[die_i]
		var tick_step: int = idx
		var new_running: int = running + die_score
		var _old: int = running
		var _new: int = new_running
		tween.tween_callback(func() -> void:
			var score_die: PhysicsDie = dice_arena.get_die(die_i)
			if score_die:
				score_die.show_score_popup(die_score)
				score_die.pop()
			SFXManager.play_score_tick(tick_step)
			hud.animate_score_count(_old, _new)
		).set_delay(interval)
		running = new_running
	# After all per-die popups, show floating gold.
	tween.tween_callback(func() -> void:
		hud.show_floating_gold(new_total - old_total)
	).set_delay(interval)


## Structured bank cascade checkpoints layered on top of per-die tally.
func _play_bank_cascade_animation(old_total: int, new_total: int, multiplier: int, streak_multiplier: float) -> void:
	_play_score_count_animation(old_total, new_total)
	var checkpoint_tween: Tween = create_tween()
	if _triggered_combo_ids.size() > 0:
		checkpoint_tween.tween_callback(func() -> void:
			hud.show_status("COMBO BONUS!", _UITheme.ROSE_ACCENT)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if multiplier > 1:
		checkpoint_tween.tween_callback(func() -> void:
			hud.show_status("MULTIPLIER x%d!" % multiplier, _UITheme.SCORE_GOLD)
			SFXManager.play_score_tick()
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if streak_multiplier > 1.0:
		checkpoint_tween.tween_callback(func() -> void:
			hud.show_status("HOT STREAK x%.1f!" % streak_multiplier, _UITheme.EXPLOSION_ORANGE)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	checkpoint_tween.tween_callback(func() -> void:
		hud.show_status("TOTAL LOCKED: %d" % new_total, _UITheme.SUCCESS_GREEN)
	).set_delay(BANK_CASCADE_STEP_DELAY)


func _play_multiply_face_vfx() -> void:
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		var die: PhysicsDie = dice_arena.get_die(i)
		if die == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY:
			die.play_multiply_vfx(face.value)
		elif face.type == DiceFaceData.FaceType.MULTIPLY_LEFT:
			die.play_multiply_left_vfx(face.value)


## Compute effective per-die score contributions (after MULTIPLY_LEFT, with global multiplier).
func _get_per_die_scores() -> Array[int]:
	var pool_size: int = GameManager.dice_pool.size()
	var glass_cannon: bool = GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON)
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
			DiceFaceData.FaceType.NUMBER:
				base_scores[i] = face.value + (2 if glass_cannon else 0)
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.EXPLODE:
				base_scores[i] = face.value
			DiceFaceData.FaceType.MULTIPLY:
				multiplier *= face.value
	for i: int in pool_size:
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY_LEFT and i > 0 and not dice_stopped[i - 1]:
			base_scores[i - 1] *= face.value
	# Apply global multiplier to each die's individual contribution.
	var result: Array[int] = []
	result.resize(pool_size)
	for i: int in pool_size:
		result[i] = base_scores[i] * multiplier
	return result

# ---------------------------------------------------------------------------
# Juice overlays
# ---------------------------------------------------------------------------

const JACKPOT_CONFETTI_AMOUNT: int = 80
const JACKPOT_CONFETTI_LIFETIME: float = 1.8


func _spawn_jackpot_confetti() -> void:
	var confetti := CPUParticles2D.new()
	confetti.one_shot = true
	confetti.amount = JACKPOT_CONFETTI_AMOUNT
	confetti.lifetime = JACKPOT_CONFETTI_LIFETIME
	confetti.explosiveness = 0.9
	confetti.direction = Vector2(0, -1)
	confetti.spread = 100.0
	confetti.gravity = Vector2(0, 400)
	confetti.initial_velocity_min = 200.0
	confetti.initial_velocity_max = 500.0
	confetti.scale_amount_min = 2.0
	confetti.scale_amount_max = 5.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.0))
	gradient.add_point(0.33, Color(1.0, 0.65, 0.0))
	gradient.add_point(0.66, Color(1.0, 1.0, 0.4))
	gradient.set_color(1, Color(1.0, 0.85, 0.0, 0.0))
	confetti.color_ramp = gradient
	confetti.position = Vector2(size.x / 2.0, size.y * 0.3)
	add_child(confetti)
	confetti.emitting = true
	get_tree().create_timer(JACKPOT_CONFETTI_LIFETIME + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(confetti):
			confetti.queue_free()
	)


func _show_bust_overlay(effective_stops: int) -> void:
	_shake_screen(SHAKE_BUST, 0.4)
	if _screen_overlay and _screen_overlay.has_method("flash_bust"):
		_screen_overlay.flash_bust()
	var overlay: ColorRect = BustOverlayScene.instantiate() as ColorRect
	add_child(overlay)
	overlay.call("play", 1)
	hud.show_status("BUST! %d stops — turn score lost!" % effective_stops, Color(0.9, 0.2, 0.2))


func _shake_screen(intensity: float, duration: float) -> void:
	if _screen_shake == null:
		return
	_screen_shake.shake(intensity, duration)


func _add_button_micro_tween(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled:
			return
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(BUTTON_HOVER_SCALE, BUTTON_HOVER_SCALE), BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_IN)
	)
	btn.button_down.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(BUTTON_PRESS_SCALE, BUTTON_PRESS_SCALE), BUTTON_TWEEN_DURATION * 0.6).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_IN)
	)


func _show_stage_clear_overlay(bonus_gold: int, surplus: int, is_loop: bool) -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	overlay.call("setup", bonus_gold, surplus, is_loop)
	overlay.connect("proceed_requested", func() -> void:
		overlay.queue_free()
		_maybe_open_forge(is_loop)
	)


func _maybe_open_forge(is_loop: bool) -> void:
	if GameManager.dice_pool.size() >= ForgePanel.MIN_DICE_FOR_FORGE and randf() < ForgePanel.FORGE_CHANCE:
		_loop_complete_pending = is_loop
		_roll_content.visible = false
		if _streak_display != null:
			_streak_display.visible = false
		forge_panel.open()
	else:
		_open_shop(is_loop)


func _on_forge_closed() -> void:
	var is_loop: bool = _loop_complete_pending
	forge_panel.visible = false
	_open_shop(is_loop)


# ---------------------------------------------------------------------------
# Curse event
# ---------------------------------------------------------------------------

const CURSE_CHANCE: float = 0.2

func _maybe_apply_curse() -> void:
	if randf() >= CURSE_CHANCE:
		return
	if GameManager.dice_pool.is_empty():
		return
	# Pick a random die and replace one non-CURSED_STOP face with CURSED_STOP.
	var die: DiceData = GameManager.dice_pool[randi() % GameManager.dice_pool.size()]
	var candidates: Array[int] = []
	for i: int in die.faces.size():
		if die.faces[i].type != DiceFaceData.FaceType.CURSED_STOP:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target: int = candidates[randi() % candidates.size()]
	die.faces[target].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[target].value = 0
	hud.show_status("CURSED! %s gained a ☠STOP face!" % die.dice_name, Color(0.6, 0.0, 0.6))

# ---------------------------------------------------------------------------
# Archetype picker
# ---------------------------------------------------------------------------

func _show_archetype_picker() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.1, 0.1, 0.15, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	var title: Label = Label.new()
	title.text = "Choose Your Archetype"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	var archetypes: Array = [
		GameManager.Archetype.CAUTION,
		GameManager.Archetype.RISK_IT,
		GameManager.Archetype.BLANK_SLATE,
	]
	for arch: GameManager.Archetype in archetypes:
		var unlock_req: int = GameManager.ARCHETYPE_UNLOCK_LOOPS[arch]
		var unlocked: bool = SaveManager.max_loops_completed >= unlock_req
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 160)
		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 8)
		var name_lbl: Label = Label.new()
		name_lbl.text = GameManager.ARCHETYPE_NAMES[arch]
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.4, 0.4, 0.4))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(name_lbl)
		var desc_lbl: Label = Label.new()
		if unlocked:
			desc_lbl.text = GameManager.ARCHETYPE_DESCRIPTIONS[arch]
		else:
			desc_lbl.text = "Locked — complete %d loop(s)" % unlock_req
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if unlocked else Color(0.35, 0.35, 0.35))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_lbl)
		var pick_btn: Button = Button.new()
		pick_btn.text = "Select" if unlocked else "Locked"
		pick_btn.disabled = not unlocked
		pick_btn.add_theme_font_size_override("font_size", 18)
		pick_btn.pressed.connect(_on_archetype_chosen.bind(arch, overlay))
		card_vbox.add_child(pick_btn)
		card.add_child(card_vbox)
		card_row.add_child(card)
	vbox.add_child(card_row)
	center.add_child(vbox)
	overlay.add_child(center)
	add_child(overlay)


func _on_archetype_chosen(arch: GameManager.Archetype, overlay: ColorRect) -> void:
	GameManager.chosen_archetype = arch
	GameManager.reset_run()
	_run_snapshot_recorded = false
	overlay.queue_free()
	_run_active = true
	turn_number = 0
	bank_streak = 0
	_update_streak_display()
	_start_new_turn()


func _record_run_snapshot_if_needed() -> void:
	if _run_snapshot_recorded:
		return
	var snapshot: RunSaveData = SaveManager.make_run_snapshot()
	SaveManager.record_run(snapshot)
	AchievementManager.on_run_recorded(snapshot)
	_run_snapshot_recorded = true
