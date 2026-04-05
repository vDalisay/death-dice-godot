class_name RollPhase
extends Control
## Turn state machine for the Cubitos-style dice rolling phase.
## Owns dice logic. Delegates visuals to DiceArena and HUD.

const BASE_BUST_THRESHOLD: int = 4
const AUTO_ADVANCE_DELAY: float = 0.75
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
const CHAIN_SHAKE_BASE: float = 2.0
const CHAIN_SHAKE_STEP: float = 0.5
const CHAIN_SHAKE_DURATION: float = 0.1
const SCORE_ANIM_SPEEDUP_THRESHOLD: int = 6
const SCORE_ANIM_SPEEDUP_PER_DIE: float = 0.06
const SCORE_ANIM_BASE_INTERVAL_FLOOR: float = 0.05

const BUTTON_HOVER_SCALE: float = 1.03
const BUTTON_PRESS_SCALE: float = 0.96
const BUTTON_TWEEN_DURATION: float = 0.08
const MULTIPLIER_BURST_DURATION: float = 0.42
const MULTIPLIER_BURST_X_RATIO: float = 0.14
const MULTIPLIER_BURST_Y_JITTER: float = 18.0

enum TurnState { IDLE, ACTIVE, BUST, BANKED }
enum RollBustOutcome { SAFE, IMMUNE_SAVE, INSURANCE_SAVE, EVENT_SAVE, BUST }

@onready var _roll_content: MarginContainer = $MarginContainer
@onready var hud: HUD           = $MarginContainer/VBoxContainer/HUD
@onready var dice_arena: DiceArena = $MarginContainer/VBoxContainer/ArenaViewportContainer/ArenaViewport/DiceArena
@onready var _arena_viewport_container: SubViewportContainer = $MarginContainer/VBoxContainer/ArenaViewportContainer
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
@onready var stage_map_panel: StageMapPanel = $StageMapPanel

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
var accumulated_shield_count: int = 0

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
var _turn_score_service: RefCounted = null
var _bust_resolver: RefCounted = null
var _risk_estimator: RefCounted = null
var _roll_resolution_service: RefCounted = null
var _stage_flow: RefCounted = null
var _defer_stage_clear_overlay: bool = false
var _pending_stage_clear_overlay: bool = false

const StreakDisplayScript: GDScript = preload("res://Scripts/StreakDisplay.gd")
const BustOverlayScene: PackedScene = preload("res://Scenes/BustOverlay.tscn")
const StageClearedScene: PackedScene = preload("res://Scenes/StageCleared.tscn")
const DiceRewardScene: PackedScene = preload("res://Scenes/DiceRewardOverlay.tscn")
const AchievementToastScene: PackedScene = preload("res://Scenes/AchievementToast.tscn")
const StageEventScene: PackedScene = preload("res://Scenes/StageEventOverlay.tscn")
const RestOverlayScene: PackedScene = preload("res://Scenes/RestOverlay.tscn")
const ArchetypePickerScene: PackedScene = preload("res://Scenes/ArchetypePicker.tscn")
const ScreenShakeScript: GDScript = preload("res://Scripts/ScreenShake.gd")
const ScreenOverlayScript: GDScript = preload("res://Scripts/ScreenOverlay.gd")
const TurnScoreServiceScript: GDScript = preload("res://Scripts/TurnScoreService.gd")
const BustFlowResolverScript: GDScript = preload("res://Scripts/BustFlowResolver.gd")
const BustRiskEstimatorScript: GDScript = preload("res://Scripts/BustRiskEstimator.gd")
const RollResolutionServiceScript: GDScript = preload("res://Scripts/RollResolutionService.gd")
const StageFlowCoordinatorScript: GDScript = preload("res://Scripts/StageFlowCoordinator.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")

func _ready() -> void:
	_turn_score_service = TurnScoreServiceScript.new()
	_bust_resolver = BustFlowResolverScript.new()
	_risk_estimator = BustRiskEstimatorScript.new()
	_roll_resolution_service = RollResolutionServiceScript.new()
	_stage_flow = StageFlowCoordinatorScript.new()
	theme = _UITheme.build_theme()
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	career_button.pressed.connect(_on_career_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	dice_arena.die_clicked.connect(_on_die_toggled)
	dice_arena.die_shift_clicked.connect(_on_die_shift_toggled)
	dice_arena.all_dice_settled.connect(_on_all_dice_settled)
	dice_arena.die_collision_rerolled.connect(_on_die_collision_rerolled)
	shop_panel.shop_closed.connect(_on_shop_closed)
	career_panel.closed.connect(_on_career_closed)
	codex_panel.closed.connect(_on_codex_closed)
	highlights_panel.closed.connect(_on_highlights_closed)
	forge_panel.forge_closed.connect(_on_forge_closed)
	stage_map_panel.node_selected.connect(_on_map_node_selected)
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
		GameManager.set_archetype(GameManager.Archetype.CAUTION)
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
	accumulated_shield_count = 0
	GameManager.begin_special_stage_turn()
	hud.reset_score_feedback_visuals(true)
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
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var heart_relief: int = _apply_banked_heart_relief()
	var base_banked: int = _calculate_turn_score()
	# Iron Bank: +50% score if no rerolls.
	if GameManager.has_modifier(RunModifier.ModifierType.IRON_BANK) and _reroll_count == 0:
		base_banked = int(base_banked * 1.5)
	# Cascade combo bonus: active combos award bonus points with escalation.
	var combo_bonus: int = _calculate_combo_bonus()
	base_banked += combo_bonus
	# Hot Streak multiplier: 3+ consecutive banks = x1.1, 5+ = x1.2.
	var streak_mult: float = _get_streak_multiplier()
	# Momentum multiplier: grows +5% per reroll this stage.
	var momentum_mult: float = _get_momentum_multiplier()
	var banked: int = int(base_banked * streak_mult * momentum_mult)
	var special_preview: Dictionary = GameManager.get_special_stage_bank_preview(effective_stops, _reroll_count)
	banked += int(special_preview.get("bonus_score", 0))
	var old_total: int = GameManager.total_score
	var will_clear_stage: bool = old_total + banked >= GameManager.stage_target_score
	var special_clear_rewards: Dictionary = GameManager.get_special_stage_clear_rewards(effective_stops, will_clear_stage)
	_defer_stage_clear_overlay = will_clear_stage
	_pending_stage_clear_overlay = false
	GameManager.add_score(banked)
	_defer_stage_clear_overlay = false
	var special_gold: int = int(special_preview.get("bonus_gold", 0)) + int(special_clear_rewards.get("bonus_gold", 0))
	if special_gold > 0:
		GameManager.add_gold(special_gold)
	var special_luck: int = int(special_preview.get("bonus_luck", 0)) + int(special_clear_rewards.get("bonus_luck", 0))
	if special_luck > 0:
		GameManager.add_luck(special_luck)
	# Reset momentum after banking (cashes out the bonus).
	GameManager.reset_momentum()
	# Accumulate LUCK face values for dice reward rarity.
	_accumulate_luck()
	# Side-bets resolve on bank.
	var heat_payout: int = GameManager.resolve_heat_bet(accumulated_stop_count)
	if heat_payout > 0:
		hud.show_status("HEAT BET HIT! +%dg" % heat_payout, Color(1.0, 0.8, 0.2))

	var even_count: int = 0
	var odd_count: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		if not (dice_keep[i] or dice_keep_locked[i]):
			continue
		var parity_face: DiceFaceData = current_results[i]
		if parity_face == null or parity_face.type != DiceFaceData.FaceType.NUMBER:
			continue
		if parity_face.value % 2 == 0:
			even_count += 1
		else:
			odd_count += 1
	var had_even_odd_bet: bool = GameManager.even_odd_bet_wager > 0
	var eo_result: int = GameManager.resolve_even_odd_bet(even_count, odd_count)
	if eo_result > 0:
		hud.show_status("EVEN/ODD WIN! +%dg" % eo_result, Color(0.95, 0.85, 0.2))
	elif eo_result < 0:
		hud.show_status("EVEN/ODD LOST", Color(1.0, 0.4, 0.4))
	elif had_even_odd_bet and even_count == odd_count and (even_count + odd_count) > 0:
		hud.show_status("EVEN/ODD PUSH (tie)", Color(0.6, 0.9, 1.0))
	# Gambler's Rush: +1g per survived stop.
	if GameManager.has_modifier(RunModifier.ModifierType.GAMBLERS_RUSH) and accumulated_stop_count > 0:
		var rush_gold: int = accumulated_stop_count
		GameManager.add_gold(rush_gold)
	# Scavenger: +1g per kept (non-stopped) die.
	if GameManager.has_modifier(RunModifier.ModifierType.SCAVENGER):
		var kept_count: int = 0
		for i: int in GameManager.dice_pool.size():
			if not dice_stopped[i] and (dice_keep[i] or dice_keep_locked[i]):
				kept_count += 1
		if kept_count > 0:
			GameManager.add_gold(kept_count)
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
	if heart_relief > 0:
		status_parts.append("HEARTS -%d STOP" % heart_relief)
	for special_part: String in special_preview.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	for special_part: String in special_clear_rewards.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	if streak_mult > 1.0:
		status_parts.append("ON FIRE x%.1f" % streak_mult)
	if momentum_mult > 1.0:
		status_parts.append("MOMENTUM x%.2f" % momentum_mult)
	status_parts.append("Banked %d points%s!  Total: %d" % [banked, mult_text, GameManager.total_score])
	if not is_jackpot:
		hud.show_status(" | ".join(status_parts), Color(0.3, 0.9, 0.3))
	SFXManager.play_bank()
	# Personal best turn score check.
	if GameManager.register_turn_score(banked):
		hud.show_status("NEW BEST TURN! %d pts" % banked, Color(1.0, 0.85, 0.0))
		SFXManager.play_personal_best()
	if banked >= 50:
		_shake_screen(SHAKE_BIG_BANK, 0.2)
	_play_multiply_face_vfx()
	# Per-die score count-up followed by cascade checkpoints.
	var anim_duration: float = _play_bank_cascade_animation(old_total, GameManager.total_score, mult, streak_mult)
	_sync_buttons()
	if will_clear_stage or _pending_stage_clear_overlay:
		_schedule_deferred_stage_clear(anim_duration)
	else:
		# Auto-advance to next turn after counting animation finishes.
		_schedule_auto_advance(anim_duration)

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


func _on_die_shift_toggled(die_index: int, is_kept: bool) -> void:
	if turn_state != TurnState.ACTIVE:
		return
	var clicked_face: DiceFaceData = current_results[die_index]
	if clicked_face == null:
		return
	var target_type: DiceFaceData.FaceType = clicked_face.type
	var target_value: int = clicked_face.value
	for i: int in current_results.size():
		if current_results[i] == null:
			continue
		if current_results[i].type != target_type or current_results[i].value != target_value:
			continue
		if dice_keep_locked[i]:
			continue
		if is_kept and dice_stopped[i]:
			# Can't keep a stopped die — skip.
			continue
		if not is_kept and dice_stopped[i]:
			# Pick up stopped dice of matching type.
			dice_stopped[i] = false
			dice_keep[i] = false
			var stopped_die: PhysicsDie = dice_arena.get_die(i)
			if stopped_die:
				stopped_die.is_stopped = false
				stopped_die.is_kept = false
			continue
		dice_keep[i] = is_kept
		var toggle_die: PhysicsDie = dice_arena.get_die(i)
		if toggle_die:
			toggle_die.is_kept = is_kept
	_sync_all_dice()
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
	var special_reroll_status: String = GameManager.apply_special_stage_reroll_bonus(_reroll_count)
	if special_reroll_status != "":
		hud.show_status(special_reroll_status, GameManager.get_active_special_stage_color())
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
	# Increment momentum on each reroll.
	GameManager.add_momentum()
	# Recycler: +1g per die rerolled.
	if GameManager.has_modifier(RunModifier.ModifierType.RECYCLER):
		GameManager.add_gold(rerolled.size())
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
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.LUCK:
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
					or face.type == DiceFaceData.FaceType.INSURANCE or face.type == DiceFaceData.FaceType.EXPLODE \
					or face.type == DiceFaceData.FaceType.LUCK):
				die.pop()

	# Accumulated bust check: add new stops from this roll to running total
	accumulated_stop_count += _count_stops_in(rolled_indices)
	_register_rolled_shields(rolled_indices)
	var shield_count: int = _count_shields()
	var effective_stops: int = _bust_resolver.effective_stops(accumulated_stop_count, shield_count)
	var threshold: int = _get_bust_threshold()
	var is_immune: bool = _bust_resolver.is_immune_turn(turn_number, GameManager.current_stage, int(GameManager.chosen_archetype))
	var insurance_index: int = _find_insurance_face_index()
	var bust_outcome: int = _get_roll_resolution_service().resolve_bust_outcome(
		effective_stops,
		threshold,
		is_immune,
		insurance_index,
		GameManager.event_free_bust
	)
	match bust_outcome:
		RollBustOutcome.SAFE, RollBustOutcome.IMMUNE_SAVE:
			turn_state = TurnState.ACTIVE
		RollBustOutcome.INSURANCE_SAVE:
			_consume_insurance_face(insurance_index)
			_sync_arena_die_state(insurance_index)
			turn_state = TurnState.BANKED
			bank_streak = 0
			_update_streak_display()
			hud.show_status("INSURANCE TRIGGERED! Bust canceled; turn score forfeited.", Color(0.4, 0.8, 1.0))
			SFXManager.play_close_call()
			_sync_buttons()
			_schedule_auto_advance()
		RollBustOutcome.EVENT_SAVE:
			if GameManager.consume_event_free_bust():
				turn_state = TurnState.BANKED
				bank_streak = 0
				_update_streak_display()
				hud.show_status("GUARDIAN ANGEL! Bust absorbed — turn score forfeited.", Color(0.4, 0.8, 1.0))
				SFXManager.play_close_call()
				_sync_buttons()
				_schedule_auto_advance()
			else:
				_apply_bust_outcome(effective_stops)
		RollBustOutcome.BUST:
			_apply_bust_outcome(effective_stops)

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
		var has_cursed: bool = _get_roll_resolution_service().has_cursed_stop_in(rolled_indices, current_results)
		_shake_screen(SHAKE_CURSED_STOP if has_cursed else SHAKE_STOP, 0.12 if has_cursed else 0.1)
	var shielded: int = _get_roll_resolution_service().absorbed_stop_count(roll_stop_count, shield_count)
	if shielded > 0:
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
	return _turn_score_service.calculate_turn_score(
		current_results,
		dice_stopped,
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.HIGH_ROLLER),
		GameManager.has_modifier(RunModifier.ModifierType.OVERCHARGE),
		GameManager.has_modifier(RunModifier.ModifierType.CHAIN_LIGHTNING)
	)


func _get_roll_resolution_service() -> RefCounted:
	if _roll_resolution_service == null:
		_roll_resolution_service = RollResolutionServiceScript.new()
	return _roll_resolution_service

func _count_stops() -> int:
	var count: int = 0
	for stopped: bool in dice_stopped:
		if stopped:
			count += 1
	return count

## Count stops only among the specified dice indices (per-roll bust check).
## CURSED_STOP counts as 2 stops.
func _count_stops_in(indices: Array[int]) -> int:
	return _get_roll_resolution_service().count_stops_in(indices, dice_stopped, current_results)

func _count_shields() -> int:
	return accumulated_shield_count


func _register_rolled_shields(indices: Array[int], play_feedback: bool = true) -> int:
	var multiplier: int = 2 if GameManager.has_modifier(RunModifier.ModifierType.SHIELD_WALL) else 1
	var total: int = 0
	for i: int in indices:
		if i < 0 or i >= current_results.size():
			continue
		var face: DiceFaceData = current_results[i]
		if face == null or face.type != DiceFaceData.FaceType.SHIELD:
			continue
		total += face.value * multiplier
		if play_feedback:
			var shield_die: PhysicsDie = dice_arena.get_die(i)
			if shield_die:
				shield_die.play_shield_charge_pulse()
			SFXManager.play_shield_absorb()
	accumulated_shield_count += total
	return total


func _accumulate_luck() -> void:
	var luck_total: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.LUCK:
			luck_total += maxi(1, face.value)
	if luck_total > 0:
		GameManager.add_luck(luck_total)


func _count_banked_hearts() -> int:
	var total: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		if not (dice_keep[i] or dice_keep_locked[i]):
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.HEART:
			total += maxi(1, face.value)
	return total


func _apply_banked_heart_relief() -> int:
	var relief: int = _count_banked_hearts()
	if relief <= 0 or accumulated_stop_count <= 0:
		return 0
	accumulated_stop_count = maxi(0, accumulated_stop_count - relief)
	return relief


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


func _apply_bust_outcome(effective_stops: int) -> void:
	turn_state = TurnState.BUST
	bank_streak = 0
	_update_streak_display()
	hud.reset_score_feedback_visuals(true)
	GameManager.lose_life()
	var insurance_payout: int = GameManager.resolve_insurance_bet()
	AchievementManager.on_bust()
	SFXManager.play_bust()
	_show_bust_overlay(effective_stops)
	if insurance_payout > 0:
		hud.show_status("Insurance paid out: +%dg" % insurance_payout, Color(0.25, 0.95, 0.6))
	_sync_buttons()
	_schedule_auto_advance()

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
					_shake_screen(CHAIN_SHAKE_BASE + float(chain_depth) * CHAIN_SHAKE_STEP, CHAIN_SHAKE_DURATION)
					die.play_explode_charge()
					die.tumble(face)
					die.pop()
					die.show_chain_label(chain_depth)
				next_chain.append(i)
			elif face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
				accumulated_stop_count += _get_roll_resolution_service().stop_weight(face)
				if die:
					die.play_stop_impact(face.type == DiceFaceData.FaceType.CURSED_STOP)
					die.tumble(face)
					_sync_arena_die_state(i)
			elif face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD or face.type == DiceFaceData.FaceType.MULTIPLY or face.type == DiceFaceData.FaceType.MULTIPLY_LEFT or face.type == DiceFaceData.FaceType.INSURANCE or face.type == DiceFaceData.FaceType.LUCK:
				dice_keep[i] = true
				dice_keep_locked[i] = true
				if face.type == DiceFaceData.FaceType.SHIELD:
					_register_rolled_shields([i], die != null)
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
				accumulated_stop_count += _get_roll_resolution_service().stop_weight(extra_face)
				if extra_die:
					extra_die.play_stop_impact(extra_face.type == DiceFaceData.FaceType.CURSED_STOP)
			elif extra_face.type in [DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.EXPLODE]:
				dice_keep[extra_i] = true
				dice_keep_locked[extra_i] = true
				if extra_face.type == DiceFaceData.FaceType.SHIELD:
					_register_rolled_shields([extra_i], extra_die != null)
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


func _calculate_combo_bonus() -> int:
	var active_combos: Array[RollCombo] = []
	var all_combos: Array[RollCombo] = RollComboRegistry.get_all_combos()
	for combo: RollCombo in all_combos:
		if combo != null and not combo.combo_id.is_empty() and _triggered_combo_ids.has(combo.combo_id):
			active_combos.append(combo)
	return RollComboRegistry.calculate_combo_bonus(active_combos)


func _get_bust_threshold() -> int:
	return _bust_resolver.get_bust_threshold(
		BASE_BUST_THRESHOLD,
		turn_number,
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.LAST_STAND),
		GameManager.lives
	)


func _get_streak_multiplier() -> float:
	if bank_streak >= HOT_STREAK_TIER_2:
		return HOT_STREAK_MULT_2
	elif bank_streak >= HOT_STREAK_TIER_1:
		return HOT_STREAK_MULT_1
	return 1.0


## Momentum multiplier: +5% per reroll this stage.
const MOMENTUM_STEP: float = 0.05

func _get_momentum_multiplier() -> float:
	if GameManager.momentum <= 0:
		return 1.0
	return 1.0 + float(GameManager.momentum) * MOMENTUM_STEP


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
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	return _risk_estimator.estimate_next_reroll_bust_chance(
		effective_stops,
		threshold,
		GameManager.dice_pool,
		dice_keep,
		dice_keep_locked
	)


func _estimate_bust_odds(effective_stops: int, threshold: int) -> float:
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	return _risk_estimator.estimate_bust_odds(
		effective_stops,
		threshold,
		_reroll_count,
		GameManager.dice_pool,
		dice_keep,
		dice_keep_locked
	)


func _build_risk_details(effective_stops: int, shield_count: int, threshold: int, bust_odds: float) -> String:
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	var rerollable_count: int = _get_rerollable_count()
	var next_roll_chance: float = _estimate_next_reroll_bust_chance(effective_stops, threshold)
	return _risk_estimator.build_risk_details(
		effective_stops,
		shield_count,
		threshold,
		next_roll_chance,
		bust_odds,
		rerollable_count,
		_reroll_count
	)

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
	# Capture prior bests BEFORE recording (so highlights compare against pre-run values).
	var prior_bests: Dictionary = {
		"highscore": SaveManager.get_mode_highscore(int(GameManager.run_mode)),
		"best_stages": SaveManager.total_stages_cleared,
		"best_loop": SaveManager.get_mode_best_loop(int(GameManager.run_mode)),
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
	if _defer_stage_clear_overlay:
		_pending_stage_clear_overlay = true
		return
	_perform_stage_clear()


func _perform_stage_clear() -> void:
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


func _schedule_deferred_stage_clear(after_delay: float) -> void:
	_pending_stage_clear_overlay = true
	get_tree().create_timer(maxf(after_delay, 0.0)).timeout.connect(_trigger_pending_stage_clear, CONNECT_ONE_SHOT)


func _trigger_pending_stage_clear() -> void:
	if not _pending_stage_clear_overlay:
		return
	_pending_stage_clear_overlay = false
	_perform_stage_clear()

func _open_shop(is_loop_complete: bool = false) -> void:
	_loop_complete_pending = is_loop_complete
	_roll_content.visible = false
	if _streak_display != null:
		_streak_display.visible = false
	shop_panel.open(GameManager.current_stage, is_loop_complete)

func _on_shop_closed() -> void:
	shop_panel.visible = false
	# Return to the path map for the next node.
	_open_stage_map()

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
			bank_button.disabled = _is_roll_animating
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
	get_tree().create_timer(delay).timeout.connect(_complete_roll_animation_lock.bind(nonce))


func _complete_roll_animation_lock(nonce: int) -> void:
	if nonce != _roll_anim_nonce:
		return
	_is_roll_animating = false
	_sync_buttons()


func _get_rerollable_count() -> int:
	var count: int = 0
	for i: int in GameManager.dice_pool.size():
		if not dice_keep[i] and not dice_keep_locked[i]:
			count += 1
	return count

# ---------------------------------------------------------------------------
# Auto-advance & per-die score animation
# ---------------------------------------------------------------------------

func _schedule_auto_advance(after_delay: float = 0.0) -> void:
	if not _run_active:
		return
	var total_delay: float = after_delay + AUTO_ADVANCE_DELAY
	get_tree().create_timer(total_delay).timeout.connect(_auto_advance_turn)


func _auto_advance_turn() -> void:
	if turn_state == TurnState.BANKED or turn_state == TurnState.BUST:
		_start_new_turn()


## Play left-to-right per-die score popups, then the total score tween.
func _play_score_count_animation(old_total: int, new_total: int) -> float:
	var pool_size: int = GameManager.dice_pool.size()
	var per_die: Array[int] = _get_per_die_scores()
	hud.begin_score_feedback(old_total, new_total, _reroll_count > 0)

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
		hud.finish_score_feedback()
		hud.show_floating_gold(new_total - old_total)
		return 0.0

	# Time per die: start at base interval, accelerate after ACCEL_START_TIME.
	const ACCEL_START_TIME: float = 2.0
	const ACCEL_PERIOD: float = 2.0
	var base_interval: float = _score_tick_base_interval(scoring_indices.size(), pool_size)
	var tween: Tween = create_tween()
	var running: int = old_total
	var elapsed: float = 0.0
	var last_interval: float = base_interval
	for idx: int in scoring_indices.size():
		var die_i: int = scoring_indices[idx]
		var die_score: int = per_die[die_i]
		var tick_step: int = idx
		var new_running: int = running + die_score
		var _old: int = running
		var _new: int = new_running
		# Accelerate: double speed every ACCEL_PERIOD seconds after ACCEL_START_TIME.
		var interval: float = base_interval
		if elapsed > ACCEL_START_TIME:
			var accel_elapsed: float = elapsed - ACCEL_START_TIME
			var doublings: float = accel_elapsed / ACCEL_PERIOD
			interval = base_interval / pow(2.0, doublings)
			interval = maxf(interval, 0.01)  # Floor to prevent zero-delay.
		elapsed += interval
		last_interval = interval
		tween.tween_callback(
			_play_score_tick_animation.bind(die_i, die_score, tick_step, _old, _new)
		).set_delay(interval)
		running = new_running
	# After all per-die popups, show floating gold.
	tween.tween_callback(_show_floating_gold_delta.bind(new_total - old_total)).set_delay(last_interval)
	tween.tween_callback(hud.finish_score_feedback).set_delay(last_interval)
	return elapsed + last_interval


func _score_tick_base_interval(scoring_die_count: int, pool_size: int) -> float:
	var safe_scoring_count: int = maxi(scoring_die_count, 1)
	var base_interval: float = minf(0.15, MAX_SCORE_ANIM_DURATION / float(safe_scoring_count))
	var extra_dice: int = maxi(pool_size - SCORE_ANIM_SPEEDUP_THRESHOLD, 0)
	var speed_scale: float = maxf(0.55, 1.0 - float(extra_dice) * SCORE_ANIM_SPEEDUP_PER_DIE)
	return maxf(SCORE_ANIM_BASE_INTERVAL_FLOOR, base_interval * speed_scale)


func _play_score_tick_animation(die_index: int, die_score: int, tick_step: int, old_total: int, new_total: int) -> void:
	var score_die: PhysicsDie = dice_arena.get_die(die_index)
	var score_face: DiceFaceData = current_results[die_index]
	if score_die:
		var popup_color: Color = PhysicsDie.face_type_color(score_face.type) if score_face else _UITheme.SCORE_GOLD
		score_die.pop()
		hud.animate_score_transfer(score_die.global_position, die_score, old_total, new_total, popup_color)
	else:
		hud.animate_score_transfer(_get_multiplier_vfx_anchor_global_position(), die_score, old_total, new_total)
	SFXManager.play_score_tick(tick_step)


func _show_floating_gold_delta(amount: int) -> void:
	hud.show_floating_gold(amount)


## Structured bank cascade checkpoints layered on top of per-die tally.
func _play_bank_cascade_animation(old_total: int, new_total: int, multiplier: int, streak_multiplier: float) -> float:
	var anim_duration: float = _play_score_count_animation(old_total, new_total)
	var checkpoint_tween: Tween = create_tween()
	if _triggered_combo_ids.size() > 0:
		checkpoint_tween.tween_callback(
			_show_hud_status.bind("COMBO BONUS!", _UITheme.ROSE_ACCENT)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if multiplier > 1:
		checkpoint_tween.tween_callback(
			_show_multiplier_status.bind(multiplier)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if streak_multiplier > 1.0:
		checkpoint_tween.tween_callback(
			_show_hot_streak_status.bind(streak_multiplier)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	checkpoint_tween.tween_callback(
		_show_total_locked_status.bind(new_total)
	).set_delay(BANK_CASCADE_STEP_DELAY)
	return anim_duration


func _show_hud_status(message: String, color: Color) -> void:
	hud.show_status(message, color)


func _show_multiplier_status(multiplier: int) -> void:
	hud.show_status("MULTIPLIER x%d!" % multiplier, _UITheme.SCORE_GOLD)
	SFXManager.play_score_tick()


func _show_hot_streak_status(streak_multiplier: float) -> void:
	hud.show_status("HOT STREAK x%.1f!" % streak_multiplier, _UITheme.EXPLOSION_ORANGE)


func _show_total_locked_status(new_total: int) -> void:
	hud.show_status("TOTAL LOCKED: %d" % new_total, _UITheme.SUCCESS_GREEN)


func _play_multiply_face_vfx() -> void:
	var effect_index: int = 0
	var anchor: Vector2 = _get_multiplier_vfx_anchor_global_position()
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY:
			_spawn_multiplier_burst(anchor + Vector2(0.0, _burst_vertical_offset(effect_index)), face.value, false)
			effect_index += 1
		elif face.type == DiceFaceData.FaceType.MULTIPLY_LEFT:
			_spawn_multiplier_burst(anchor + Vector2(0.0, _burst_vertical_offset(effect_index)), face.value, true)
			effect_index += 1


func _burst_vertical_offset(effect_index: int) -> float:
	if effect_index == 0:
		return 0.0
	var direction: float = -1.0 if effect_index % 2 == 0 else 1.0
	return direction * ceilf(float(effect_index) * 0.5) * MULTIPLIER_BURST_Y_JITTER


func _get_multiplier_vfx_anchor_global_position() -> Vector2:
	var arena_origin: Vector2 = _arena_viewport_container.global_position
	var arena_size: Vector2 = _arena_viewport_container.size
	return arena_origin + Vector2(arena_size.x * MULTIPLIER_BURST_X_RATIO, arena_size.y * 0.5)


func _spawn_multiplier_burst(burst_position: Vector2, multiplier: int, is_left_multiplier: bool) -> void:
	var fx_root := Node2D.new()
	fx_root.name = "MultiplierBurstFx"
	fx_root.top_level = true
	fx_root.global_position = burst_position
	add_child(fx_root)

	var flame := CPUParticles2D.new()
	flame.one_shot = true
	flame.amount = 36
	flame.lifetime = MULTIPLIER_BURST_DURATION
	flame.explosiveness = 0.82
	flame.direction = Vector2.RIGHT if not is_left_multiplier else Vector2(0.9, -0.1)
	flame.spread = 34.0
	flame.gravity = Vector2(0.0, -18.0)
	flame.initial_velocity_min = 90.0
	flame.initial_velocity_max = 180.0
	flame.scale_amount_min = 1.4
	flame.scale_amount_max = 2.6
	var flame_gradient := Gradient.new()
	var flame_color: Color = _UITheme.ROSE_ACCENT if is_left_multiplier else _UITheme.SCORE_GOLD
	flame_gradient.set_color(0, Color(1.0, 0.98, 0.72, 0.95))
	flame_gradient.add_point(0.45, flame_color)
	flame_gradient.set_color(1, Color(flame_color.r, flame_color.g, flame_color.b, 0.0))
	flame.color_ramp = flame_gradient
	fx_root.add_child(flame)

	var tag := Label.new()
	tag.text = "<x%d" % multiplier if is_left_multiplier else "x%d" % multiplier
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.position = Vector2(-28.0, -18.0)
	tag.size = Vector2(64.0, 24.0)
	tag.add_theme_font_override("font", _UITheme.font_stats())
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", flame_color)
	tag.add_theme_color_override("font_outline_color", Color("#05050A"))
	tag.add_theme_constant_override("outline_size", 5)
	fx_root.add_child(tag)

	flame.emitting = true
	fx_root.scale = Vector2(0.72, 0.72)
	fx_root.modulate.a = 0.95
	var tween: Tween = fx_root.create_tween()
	tween.tween_property(fx_root, "scale", Vector2(1.12, 1.12), MULTIPLIER_BURST_DURATION * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "global_position", burst_position + Vector2(34.0, -8.0), MULTIPLIER_BURST_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "modulate:a", 0.0, MULTIPLIER_BURST_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx_root.queue_free)


## Compute effective per-die score contributions (after MULTIPLY_LEFT, with global multiplier).
func _get_per_die_scores() -> Array[int]:
	return _turn_score_service.calculate_per_die_scores(
		current_results,
		dice_stopped,
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.HIGH_ROLLER),
		GameManager.has_modifier(RunModifier.ModifierType.OVERCHARGE)
	)

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
	get_tree().create_timer(JACKPOT_CONFETTI_LIFETIME + 0.5).timeout.connect(_queue_free_if_valid.bind(confetti))


func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


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
	overlay.connect("proceed_requested", _on_stage_clear_overlay_proceed.bind(overlay))


func _on_stage_clear_overlay_proceed(overlay: ColorRect) -> void:
	_queue_free_if_valid(overlay)
	_show_dice_reward()


func _show_dice_reward() -> void:
	var reward_overlay: ColorRect = DiceRewardScene.instantiate() as ColorRect
	add_child(reward_overlay)
	reward_overlay.call("open", GameManager.luck)
	reward_overlay.connect("reward_chosen", _on_reward_chosen)


func _on_reward_chosen(die: DiceData) -> void:
	GameManager.add_dice(die)
	_open_stage_map()


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
	forge_panel.visible = false
	# After forge, return to the path map for next row.
	_open_stage_map()


func _show_stage_event() -> void:
	var event_overlay: ColorRect = StageEventScene.instantiate() as ColorRect
	add_child(event_overlay)
	event_overlay.call("open")
	event_overlay.connect("event_resolved", _on_stage_event_resolved.bind(event_overlay))


func _on_stage_event_resolved(summary: String, status_color: Color, event_overlay: ColorRect) -> void:
	_queue_free_if_valid(event_overlay)
	if summary != "":
		hud.show_status(summary, status_color)
	_open_stage_map()


# ---------------------------------------------------------------------------
# Path map
# ---------------------------------------------------------------------------

const REST_HEAL_LIVES: int = 1
const REST_GOLD_BONUS: int = 10

func _open_stage_map() -> void:
	GameManager.reset_luck()
	if GameManager.stage_map == null:
		GameManager.generate_stage_map()
	# Check if we've completed all rows (loop complete).
	if GameManager.current_row >= StageMapDataScript.ROWS_PER_LOOP:
		_complete_loop()
		return
	_roll_content.visible = false
	if _streak_display != null:
		_streak_display.visible = false
	stage_map_panel.open(
		GameManager.stage_map,
		GameManager.current_row,
		GameManager.previous_col,
		GameManager.prestige_reroute_uses
	)


func _on_map_node_selected(row: int, col: int, node_type: MapNodeData.NodeType, used_reroute: bool) -> void:
	if used_reroute:
		GameManager.use_reroute_token()
		hud.show_status("REROUTE SPENT! Path broken for this pick.", Color(1.0, 0.72, 0.35))
	var selected_node: MapNodeData = GameManager.stage_map.get_node_at(row, col)
	_stage_flow.advance_row(col)
	stage_map_panel.visible = false
	match node_type:
		MapNodeData.NodeType.NORMAL_STAGE:
			_start_stage_from_map("")
		MapNodeData.SPECIAL_STAGE_TYPE:
			_start_stage_from_map(selected_node.special_rule_id if selected_node != null else "")
		MapNodeData.NodeType.SHOP:
			_open_shop_from_map()
		MapNodeData.NodeType.FORGE:
			_open_forge_from_map()
		MapNodeData.NodeType.REST:
			_execute_rest_node()
		MapNodeData.NodeType.RANDOM_EVENT:
			_show_stage_event()


func _start_stage_from_map(special_rule_id: String = "") -> void:
	_stage_flow.begin_stage_from_map()
	if special_rule_id != "":
		GameManager.enter_special_stage(special_rule_id)
		hud.show_status(
			"SPECIAL STAGE: %s" % GameManager.get_active_special_stage_summary(),
			GameManager.get_active_special_stage_color()
		)
	_roll_content.visible = true
	_update_streak_display()
	_run_active = true
	turn_number = 0
	bank_streak = 0
	_update_streak_display()
	_start_new_turn()


func _open_shop_from_map() -> void:
	_loop_complete_pending = false
	_roll_content.visible = false
	if _streak_display != null:
		_streak_display.visible = false
	shop_panel.open(GameManager.current_stage, false)


func _open_forge_from_map() -> void:
	if GameManager.dice_pool.size() >= ForgePanel.MIN_DICE_FOR_FORGE:
		_roll_content.visible = false
		if _streak_display != null:
			_streak_display.visible = false
		forge_panel.open()
	else:
		# Not enough dice for forge — open map for next node.
		hud.show_status("Not enough dice to forge (need %d)." % ForgePanel.MIN_DICE_FOR_FORGE, Color(1.0, 0.6, 0.0))
		_open_stage_map()


func _execute_rest_node() -> void:
	var lives_before: int = GameManager.lives
	_stage_flow.apply_rest_rewards(REST_HEAL_LIVES, REST_GOLD_BONUS)
	var lives_after: int = GameManager.lives
	hud.show_status("Rested! +%d life, +%dg" % [REST_HEAL_LIVES, REST_GOLD_BONUS], Color(0.3, 1.0, 0.3))
	SFXManager.play_stage_clear()
	_show_rest_overlay(lives_before, lives_after)


func _show_rest_overlay(lives_before: int, lives_after: int) -> void:
	var overlay: ColorRect = RestOverlayScene.instantiate() as ColorRect
	add_child(overlay)
	overlay.call("open", REST_HEAL_LIVES, REST_GOLD_BONUS, lives_before, lives_after)
	overlay.connect("continue_requested", _on_rest_overlay_continue.bind(overlay))


func _on_rest_overlay_continue(overlay: ColorRect) -> void:
	_queue_free_if_valid(overlay)
	_open_stage_map()


func _complete_loop() -> void:
	_stage_flow.complete_loop()
	AchievementManager.on_loop_advanced(GameManager.current_loop)
	_maybe_apply_curse()
	hud.show_status(
		"LOOP %d COMPLETE! Entering Loop %d..." % [GameManager.current_loop - 1, GameManager.current_loop],
		Color(1.0, 0.85, 0.0))
	# Open the new loop's map.
	_open_stage_map()


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
	var picker: ColorRect = ArchetypePickerScene.instantiate() as ColorRect
	add_child(picker)
	picker.call("open", int(GameManager.run_mode))
	picker.connect("selection_confirmed", _on_archetype_selected)


func _on_archetype_selected(run_mode: int, archetype: int) -> void:
	GameManager.set_run_mode(run_mode)
	GameManager.set_archetype(archetype as GameManager.Archetype)
	GameManager.reset_run()
	_run_snapshot_recorded = false
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
