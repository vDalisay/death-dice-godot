extends Node
## Global score and run state. Registered as autoload "GameManager".

const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")

const MAX_LIVES: int = 3
const STARTING_DICE_COUNT: int = 5
const STAGES_LOOP_1: int = 5
const STAGES_LOOP_2_PLUS: int = 7
const BASE_STAGE_TARGET: int = 30
const STAGE_TARGET_STEP: int = 25
const STAGE_CLEAR_GOLD_BONUS: int = 20
const LOOP_BONUS_GOLD_STEP: int = 10
const MAX_MODIFIERS: int = 3
const MISER_SPEND_THRESHOLD: int = 15
const MISER_BONUS_GOLD: int = 20

enum Archetype { CAUTION, RISK_IT, BLANK_SLATE }
enum RunMode { CLASSIC, GAUNTLET }
const ARCHETYPE_NAMES: Dictionary = {
	Archetype.CAUTION: "Caution",
	Archetype.RISK_IT: "Risk It",
	Archetype.BLANK_SLATE: "Blank Slate",
}
const ARCHETYPE_DESCRIPTIONS: Dictionary = {
	Archetype.CAUTION: "6 Standard dice, bust immunity to turn 3.",
	Archetype.RISK_IT: "5 Gambler dice, 2x gold per turn.",
	Archetype.BLANK_SLATE: "8 Blank Canvas dice, shop gold doubled.",
}
## Loops required to unlock each archetype (0 = always available).
const ARCHETYPE_UNLOCK_LOOPS: Dictionary = {
	Archetype.CAUTION: 0,
	Archetype.RISK_IT: 1,
	Archetype.BLANK_SLATE: 3,
}
const RUN_MODE_NAMES: Dictionary = {
	RunMode.CLASSIC: "Classic",
	RunMode.GAUNTLET: "Gauntlet",
}
const GAUNTLET_LOOP_MULT_STEP: float = 0.75
const GAUNTLET_STAGE_STEP_MULT: float = 1.25

signal score_changed(new_total: int)
signal turn_banked(points: int, new_total: int)
signal lives_changed(new_lives: int)
signal gold_changed(new_gold: int)
signal stage_advanced(new_stage: int)
signal run_ended()
signal stage_cleared()
signal loop_advanced(new_loop: int)
signal luck_changed(new_luck: int)
signal momentum_changed(new_momentum: int)
signal run_mode_changed(new_mode: int)

var total_score: int = 0
var lives: int = MAX_LIVES
var current_stage: int = 1
var current_loop: int = 1
var current_row: int = 0
var previous_col: int = -1
var stage_map: Resource = null
var gold: int = 0
var stage_target_score: int = BASE_STAGE_TARGET
var dice_pool: Array[DiceData] = []
var total_stages_cleared: int = 0
var best_turn_score: int = 0
var run_busts: int = 0
var active_modifiers: Array[RunModifier] = []
var chosen_archetype: Archetype = Archetype.CAUTION
var run_mode: RunMode = RunMode.CLASSIC
var luck: int = 0
## Event flags — temporary effects that reset each loop.
var event_free_bust: bool = false
var event_target_multiplier: float = 1.0
## Momentum: consecutive banks this stage. Resets on bust / stage transition.
var momentum: int = 0
## Tracks gold spent in the current shop visit (for Miser modifier).
var _shop_gold_spent: int = 0
## Whether the Miser bonus is pending for the next shop.
var _miser_bonus_pending: bool = false
## When true, RollPhase skips the archetype picker and starts immediately.
## Set by tests to avoid UI blocking.
var skip_archetype_picker: bool = false


func set_archetype(archetype: Archetype) -> void:
	chosen_archetype = archetype


func add_momentum(amount: int = 1) -> void:
	momentum += amount
	momentum_changed.emit(momentum)


func reset_momentum() -> void:
	momentum = 0
	momentum_changed.emit(momentum)


func set_event_free_bust(enabled: bool) -> void:
	event_free_bust = enabled


func consume_event_free_bust() -> bool:
	if not event_free_bust:
		return false
	event_free_bust = false
	return true


func apply_event_target_multiplier(multiplier: float) -> void:
	event_target_multiplier = multiplier
	stage_target_score = roundi(float(stage_target_score) * multiplier)


func remove_gold(amount: int) -> void:
	gold = maxi(gold - maxi(0, amount), 0)
	gold_changed.emit(gold)


func heal_lives(amount: int) -> void:
	lives = mini(lives + maxi(0, amount), MAX_LIVES)
	lives_changed.emit(lives)


func begin_stage_from_map() -> void:
	total_stages_cleared += 1
	current_stage += 1
	total_score = 0
	stage_target_score = _calculate_stage_target(current_stage)
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)


func register_turn_score(turn_score: int) -> bool:
	if turn_score <= best_turn_score:
		return false
	best_turn_score = turn_score
	return true


func _ready() -> void:
	_build_starting_pool()
	generate_stage_map()


func generate_stage_map() -> void:
	stage_map = StageMapDataScript.generate(current_loop)
	current_row = 0
	previous_col = -1


# ---------------------------------------------------------------------------
# Dice pool
# ---------------------------------------------------------------------------

func _build_starting_pool() -> void:
	dice_pool.clear()
	match chosen_archetype:
		Archetype.CAUTION:
			for i: int in 6:
				dice_pool.append(DiceData.make_standard_d6())
		Archetype.RISK_IT:
			for i: int in 5:
				dice_pool.append(DiceData.make_gambler_d6())
		Archetype.BLANK_SLATE:
			for i: int in 8:
				dice_pool.append(DiceData.make_blank_canvas_d6())


func add_dice(die: DiceData) -> void:
	dice_pool.append(die)


# ---------------------------------------------------------------------------
# Score & gold
# ---------------------------------------------------------------------------

func add_score(points: int) -> void:
	total_score += points
	var gold_earned: int = points
	if chosen_archetype == Archetype.RISK_IT:
		gold_earned *= 2
	add_gold(gold_earned)
	score_changed.emit(total_score)
	turn_banked.emit(points, total_score)
	if total_score >= stage_target_score:
		stage_cleared.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func add_luck(amount: int) -> void:
	luck += amount
	luck_changed.emit(luck)


func reset_luck() -> void:
	luck = 0
	luck_changed.emit(luck)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# ---------------------------------------------------------------------------
# Stage & loop progression
# ---------------------------------------------------------------------------

func get_stages_in_current_loop() -> int:
	if current_loop <= 1:
		return STAGES_LOOP_1
	return STAGES_LOOP_2_PLUS


func _loop_multiplier() -> float:
	if run_mode == RunMode.GAUNTLET:
		return 1.0 + GAUNTLET_LOOP_MULT_STEP * (current_loop - 1)
	return 1.0 + 0.5 * (current_loop - 1)


func _calculate_stage_target(stage: int) -> int:
	var mult: float = _loop_multiplier()
	var row: int = current_row if stage_map else (stage - 1)
	var step_mult: float = GAUNTLET_STAGE_STEP_MULT if run_mode == RunMode.GAUNTLET else 1.0
	return int(BASE_STAGE_TARGET * mult) + row * int(STAGE_TARGET_STEP * mult * step_mult)


func set_run_mode(mode: int) -> void:
	run_mode = mode as RunMode
	run_mode_changed.emit(run_mode)


func get_run_mode_name() -> String:
	return str(RUN_MODE_NAMES.get(run_mode, "Classic"))


func advance_stage() -> void:
	total_stages_cleared += 1
	current_stage += 1
	total_score = 0
	reset_momentum()
	stage_target_score = _calculate_stage_target(current_stage)
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)


func advance_row(col: int) -> void:
	previous_col = col
	current_row += 1


func advance_loop() -> void:
	total_stages_cleared += 1
	current_loop += 1
	current_stage = 1
	total_score = 0
	reset_momentum()
	_reset_event_flags()
	generate_stage_map()
	stage_target_score = _calculate_stage_target(current_stage)
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)
	run_mode_changed.emit(run_mode)
	loop_advanced.emit(current_loop)


func is_final_stage() -> bool:
	if stage_map:
		return current_row >= stage_map.get_row_count() - 1
	return current_stage >= get_stages_in_current_loop()


func get_stage_clear_bonus() -> int:
	var base: int = STAGE_CLEAR_GOLD_BONUS + LOOP_BONUS_GOLD_STEP * (current_loop - 1)
	if chosen_archetype == Archetype.BLANK_SLATE:
		base *= 2
	return base


# ---------------------------------------------------------------------------
# Lives
# ---------------------------------------------------------------------------

func lose_life() -> void:
	lives -= 1
	run_busts += 1
	reset_momentum()
	lives_changed.emit(lives)
	if lives <= 0:
		run_ended.emit()


# ---------------------------------------------------------------------------
# Run reset
# ---------------------------------------------------------------------------

func reset_run() -> void:
	current_stage = 1
	current_loop = 1
	current_row = 0
	previous_col = -1
	total_score = 0
	total_stages_cleared = 0
	run_busts = 0
	lives = MAX_LIVES
	gold = 0
	best_turn_score = 0
	luck = 0
	event_free_bust = false
	event_target_multiplier = 1.0
	reset_momentum()
	active_modifiers.clear()
	_shop_gold_spent = 0
	_miser_bonus_pending = false
	stage_target_score = _calculate_stage_target(current_stage)
	_build_starting_pool()
	generate_stage_map()
	score_changed.emit(total_score)
	lives_changed.emit(lives)
	gold_changed.emit(gold)
	stage_advanced.emit(current_stage)
	loop_advanced.emit(current_loop)


# ---------------------------------------------------------------------------
# Modifier helpers
# ---------------------------------------------------------------------------

func has_modifier(mod_type: RunModifier.ModifierType) -> bool:
	for m: RunModifier in active_modifiers:
		if m.modifier_type == mod_type:
			return true
	return false


func add_modifier(modifier: RunModifier) -> bool:
	if active_modifiers.size() >= MAX_MODIFIERS:
		return false
	active_modifiers.append(modifier)
	return true


func can_add_modifier() -> bool:
	return active_modifiers.size() < MAX_MODIFIERS


## Called when entering the shop. Awards Miser bonus if pending.
func on_shop_entered() -> void:
	_shop_gold_spent = 0
	if _miser_bonus_pending:
		_miser_bonus_pending = false
		add_gold(MISER_BONUS_GOLD)


## Called when leaving the shop. Checks Miser condition for next shop.
func on_shop_exited() -> void:
	if has_modifier(RunModifier.ModifierType.MISER) and _shop_gold_spent < MISER_SPEND_THRESHOLD:
		_miser_bonus_pending = true
	else:
		_miser_bonus_pending = false


## Track gold spent in shop (for Miser modifier).
func track_shop_spend(amount: int) -> void:
	_shop_gold_spent += amount


# ---------------------------------------------------------------------------
# Event flags
# ---------------------------------------------------------------------------

func _reset_event_flags() -> void:
	event_free_bust = false
	event_target_multiplier = 1.0
