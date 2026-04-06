extends Node
## Global score and run state. Registered as autoload "GameManager".

const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")
const SpecialStageCatalogScript: GDScript = preload("res://Scripts/SpecialStageCatalog.gd")
const SpecialStageRegistryScript: GDScript = preload("res://Scripts/SpecialStageRegistry.gd")
const RunSeedServiceScript: GDScript = preload("res://Scripts/RunSeedService.gd")

const BASE_STAGE_HANDS: int = 5
const MAX_LIVES: int = BASE_STAGE_HANDS
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
const ARCHETYPE_CAPSTONE_LOOP: int = 3

enum Archetype { CAUTION, RISK_IT, BLANK_SLATE, FORTUNE_FOOL, STOP_COLLECTOR, LAST_CALL }
enum RunMode { CLASSIC, GAUNTLET }
enum NextRouteRestriction { NONE, STANDARD_ONLY, NO_HARD }
const ARCHETYPE_NAMES: Dictionary = {
	Archetype.CAUTION: "Caution",
	Archetype.RISK_IT: "Risk It",
	Archetype.BLANK_SLATE: "Blank Slate",
	Archetype.FORTUNE_FOOL: "Fortune's Fool",
	Archetype.STOP_COLLECTOR: "Stop Collector",
	Archetype.LAST_CALL: "Last Call",
}
const ARCHETYPE_DESCRIPTIONS: Dictionary = {
	Archetype.CAUTION: "5 Standard dice + 1 Shield die, bust immunity to turn 3.",
	Archetype.RISK_IT: "5 Gambler dice, 2x gold per turn.",
	Archetype.BLANK_SLATE: "8 Blank Canvas dice, shop gold doubled.",
	Archetype.FORTUNE_FOOL: "10 Fortune dice, LUCK x2, but start with only 15 gold.",
	Archetype.STOP_COLLECTOR: "4 Standard + Gambler + Shield. Banked stops pay gold. Capstone: loop 3+ banks at 2+ stops earn EXP.",
	Archetype.LAST_CALL: "3 Gambler + 2 Heavy + 1 Shield. Near-death banks heal once per stage. Capstone: loop 3+ near-death banks earn a Shard.",
}
## Loops required to unlock each archetype (0 = always available).
const ARCHETYPE_UNLOCK_LOOPS: Dictionary = {
	Archetype.CAUTION: 0,
	Archetype.RISK_IT: 1,
	Archetype.BLANK_SLATE: 3,
	Archetype.FORTUNE_FOOL: 0,
	Archetype.STOP_COLLECTOR: 2,
	Archetype.LAST_CALL: 4,
}
const RUN_MODE_NAMES: Dictionary = {
	RunMode.CLASSIC: "Classic",
	RunMode.GAUNTLET: "Gauntlet",
}
const GAUNTLET_LOOP_MULT_STEP: float = 0.75
const GAUNTLET_STAGE_STEP_MULT: float = 1.25
const CLASSIC_LOOP_1_TARGETS: Array[int] = [18, 26, 34, 42, 52]
const CLASSIC_LOOP_2_TARGETS: Array[int] = [24, 36, 48, 62, 78, 96, 118]
const INITIAL_CLASSIC_STAGE_TARGET: int = 18

signal score_changed(new_total: int)
signal turn_banked(points: int, new_total: int)
signal hands_changed(new_hands: int)
signal lives_changed(new_lives: int)
signal gold_changed(new_gold: int)
signal stage_advanced(new_stage: int)
signal run_ended()
signal stage_cleared()
signal loop_advanced(new_loop: int)
signal luck_changed(new_luck: int)
signal momentum_changed(new_momentum: int)
signal run_mode_changed(new_mode: int)
signal stage_variant_changed(new_variant: int)
signal held_stops_changed(new_total: int)
signal near_death_banked(effective_stops: int, threshold: int)
signal loop_contract_changed(active_contract_id: String)
signal loop_contract_progress_changed(progress: Dictionary)
signal run_exp_changed(new_total: int)
signal run_stop_shards_changed(new_total: int)
signal run_seed_changed(is_seeded: bool, seed_text: String)
signal resumable_run_changed(has_resumable: bool)

var total_score: int = 0
var hands: int = BASE_STAGE_HANDS
var stage_hand_cap: int = BASE_STAGE_HANDS
var lives: int:
	get:
		return hands
	set(value):
		hands = maxi(0, value)
var current_stage: int = 1
var current_loop: int = 1
var current_row: int = 0
var previous_col: int = -1
var stage_map: Resource = null
var gold: int = 0
var stage_target_score: int = INITIAL_CLASSIC_STAGE_TARGET
var current_stage_variant: int = SpecialStageCatalogScript.Variant.NONE
var dice_pool: Array[DiceData] = []
var total_stages_cleared: int = 0
var best_turn_score: int = 0
var run_busts: int = 0
var is_seeded_run: bool = false
var run_seed_text: String = ""
var run_seed_version: int = 1
var has_resumable_run: bool = false
var active_modifiers: Array[RunModifier] = []
var chosen_archetype: Archetype = Archetype.CAUTION
var run_mode: RunMode = RunMode.CLASSIC
var luck: int = 0
var current_run_exp: int = 0
var current_run_stop_shards: int = 0
var held_stop_count: int = 0
var active_loop_contract_id: String = ""
var active_loop_contract_progress: Dictionary = {}
var offered_loop_contract_ids: Array[String] = []
var near_death_banks_this_stage: int = 0
var near_death_banks_this_run: int = 0
## Event flags — temporary effects that reset each loop.
var event_free_bust: bool = false
var event_target_multiplier: float = 1.0
var event_next_stage_target_multiplier: float = 1.0
var event_next_stage_first_bank_gold_multiplier: float = 1.0
var event_next_stage_clear_gold_multiplier: float = 1.0
var event_next_stage_starting_stop_pressure: int = 0
var event_next_reward_rarity_bonus: int = 0
var event_next_route_restriction: NextRouteRestriction = NextRouteRestriction.NONE
var event_next_map_row_reveal: bool = false
## Momentum: consecutive banks this stage. Resets on bust / stage transition.
var momentum: int = 0
## Tracks gold spent in the current shop visit (for Miser modifier).
var _shop_gold_spent: int = 0
## Whether the Miser bonus is pending for the next shop.
var _miser_bonus_pending: bool = false
## When true, RollPhase skips the archetype picker and starts immediately.
## Set by tests to avoid UI blocking.
var skip_archetype_picker: bool = false

# ---------------------------------------------------------------------------
# Side-bet state (cleared on shop_entered and reset_run)
# ---------------------------------------------------------------------------
## Insurance: payout awarded on bust. 0 = no active bet.
var insurance_payout: int = 0
## Heat Bet: stop count target (-1 = no active bet) and payout on hit.
var heat_bet_target_stops: int = -1
var heat_bet_payout: int = 0
## Even/Odd Bet: is_even = player's pick; wager = 0 means no active bet.
var even_odd_bet_is_even: bool = true
var even_odd_bet_wager: int = 0

# ---------------------------------------------------------------------------
# Prestige run flags (refreshed on reset_run)
# ---------------------------------------------------------------------------
var prestige_starting_gold_bonus: int = 0
var prestige_shop_tier_active: bool = false
var prestige_reward_reroll_available: bool = false
var prestige_reroute_uses: int = 0
var _revealed_loop_numbers: Array[int] = []
var _last_call_heal_used_this_stage: bool = false
var active_special_stage_id: String = ""
var _special_stage_first_reroll_used: bool = false
var _run_seed_locked: bool = false
var _run_seed_service: RefCounted = RunSeedServiceScript.new()


func set_archetype(archetype: Archetype) -> void:
	chosen_archetype = archetype


func begin_new_run(mode: int, archetype: Archetype, seeded: bool, seed_text: String = "") -> void:
	set_run_mode(mode)
	set_archetype(archetype)
	_prepare_new_run_identity(seed_text, seeded)
	reset_run()


func restore_run_identity(seed_text: String, seeded: bool, seed_version: int, stream_states: Dictionary = {}) -> void:
	var normalized_seed: String = RunSeedServiceScript.normalize_seed_text(seed_text)
	if normalized_seed.is_empty():
		normalized_seed = RunSeedServiceScript.make_random_seed_text()
	is_seeded_run = seeded
	run_seed_text = normalized_seed
	run_seed_version = maxi(1, seed_version)
	_run_seed_locked = true
	_ensure_seed_service_initialized()
	_run_seed_service.configure(run_seed_text, run_seed_version)
	if not stream_states.is_empty():
		_run_seed_service.restore_stream_states(stream_states)
	run_seed_changed.emit(is_seeded_run, run_seed_text)


func clear_active_run_identity() -> void:
	is_seeded_run = false
	run_seed_text = ""
	run_seed_version = RunSeedServiceScript.SEED_VERSION
	_run_seed_locked = false
	_run_seed_service.configure(RunSeedServiceScript.make_random_seed_text(), run_seed_version)
	run_seed_changed.emit(is_seeded_run, run_seed_text)


func set_has_resumable_run(value: bool) -> void:
	if has_resumable_run == value:
		return
	has_resumable_run = value
	resumable_run_changed.emit(has_resumable_run)


func snapshot_rng_stream_states() -> Dictionary:
	_ensure_seed_service_initialized()
	return _run_seed_service.snapshot_stream_states()


func rng_randf(stream_name: String) -> float:
	_ensure_seed_service_initialized()
	return _run_seed_service.randf_stream(stream_name)


func rng_randi(stream_name: String) -> int:
	_ensure_seed_service_initialized()
	return _run_seed_service.randi_stream(stream_name)


func rng_randi_range(stream_name: String, min_value: int, max_value: int) -> int:
	_ensure_seed_service_initialized()
	return _run_seed_service.randi_range_stream(stream_name, min_value, max_value)


func rng_randf_range(stream_name: String, min_value: float, max_value: float) -> float:
	_ensure_seed_service_initialized()
	return _run_seed_service.randf_range_stream(stream_name, min_value, max_value)


func rng_pick_index(stream_name: String, size: int) -> int:
	_ensure_seed_service_initialized()
	return _run_seed_service.pick_index(stream_name, size)


func rng_shuffle_in_place(stream_name: String, values: Array) -> void:
	_ensure_seed_service_initialized()
	_run_seed_service.shuffle_in_place(stream_name, values)


func rng_shuffle_copy(stream_name: String, values: Array) -> Array:
	_ensure_seed_service_initialized()
	return _run_seed_service.shuffle_copy(stream_name, values)


func add_momentum(amount: int = 1) -> void:
	momentum += amount
	momentum_changed.emit(momentum)


func reset_momentum() -> void:
	momentum = 0
	momentum_changed.emit(momentum)


func add_run_exp(amount: int) -> void:
	if amount <= 0:
		return
	current_run_exp += amount
	run_exp_changed.emit(current_run_exp)


func add_run_stop_shards(amount: int) -> void:
	if amount <= 0:
		return
	current_run_stop_shards += amount
	run_stop_shards_changed.emit(current_run_stop_shards)


func set_held_stop_count(count: int) -> void:
	held_stop_count = maxi(0, count)
	held_stops_changed.emit(held_stop_count)


func set_offered_loop_contract_ids(contract_ids: Array[String]) -> void:
	offered_loop_contract_ids = contract_ids.duplicate()


func activate_loop_contract(contract_id: String) -> void:
	active_loop_contract_id = contract_id
	active_loop_contract_progress = {}
	loop_contract_changed.emit(active_loop_contract_id)
	loop_contract_progress_changed.emit(active_loop_contract_progress.duplicate(true))


func clear_active_loop_contract() -> void:
	active_loop_contract_id = ""
	active_loop_contract_progress = {}
	offered_loop_contract_ids.clear()
	loop_contract_changed.emit(active_loop_contract_id)
	loop_contract_progress_changed.emit(active_loop_contract_progress.duplicate(true))


func update_loop_contract_progress(progress: Dictionary) -> void:
	active_loop_contract_progress = progress.duplicate(true)
	loop_contract_progress_changed.emit(active_loop_contract_progress.duplicate(true))


func register_near_death_bank(effective_stops: int, threshold: int) -> void:
	near_death_banks_this_stage += 1
	near_death_banks_this_run += 1
	near_death_banked.emit(effective_stops, threshold)


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


func set_next_stage_target_multiplier(multiplier: float) -> void:
	event_next_stage_target_multiplier = multiplier


func set_next_stage_first_bank_gold_multiplier(multiplier: float) -> void:
	event_next_stage_first_bank_gold_multiplier = multiplier


func set_next_stage_clear_gold_multiplier(multiplier: float) -> void:
	event_next_stage_clear_gold_multiplier = multiplier


func set_next_stage_starting_stop_pressure(amount: int) -> void:
	event_next_stage_starting_stop_pressure = maxi(0, amount)


func set_next_reward_rarity_bonus(amount: int) -> void:
	event_next_reward_rarity_bonus = maxi(0, amount)


func set_next_route_restriction(restriction: int) -> void:
	if not NextRouteRestriction.values().has(restriction):
		event_next_route_restriction = NextRouteRestriction.NONE
		return
	event_next_route_restriction = restriction as NextRouteRestriction


func clear_next_route_restriction() -> void:
	event_next_route_restriction = NextRouteRestriction.NONE


func set_next_map_row_reveal(enabled: bool) -> void:
	event_next_map_row_reveal = enabled


func consume_next_map_row_reveal() -> bool:
	if not event_next_map_row_reveal:
		return false
	event_next_map_row_reveal = false
	return true


func apply_pending_next_stage_modifiers() -> void:
	if not is_equal_approx(event_next_stage_target_multiplier, 1.0):
		stage_target_score = roundi(float(stage_target_score) * event_next_stage_target_multiplier)
		event_next_stage_target_multiplier = 1.0


func consume_next_stage_first_bank_gold_bonus(base_gold: int) -> int:
	if base_gold <= 0 or is_equal_approx(event_next_stage_first_bank_gold_multiplier, 1.0):
		return base_gold
	var adjusted_gold: int = roundi(float(base_gold) * event_next_stage_first_bank_gold_multiplier)
	event_next_stage_first_bank_gold_multiplier = 1.0
	return adjusted_gold


func consume_next_stage_clear_gold_bonus(base_gold: int) -> int:
	if base_gold <= 0 or is_equal_approx(event_next_stage_clear_gold_multiplier, 1.0):
		return base_gold
	var adjusted_gold: int = roundi(float(base_gold) * event_next_stage_clear_gold_multiplier)
	event_next_stage_clear_gold_multiplier = 1.0
	return adjusted_gold


func consume_next_stage_starting_stop_pressure() -> int:
	var pressure: int = maxi(0, event_next_stage_starting_stop_pressure)
	event_next_stage_starting_stop_pressure = 0
	return pressure


func consume_next_reward_rarity_bonus() -> int:
	var bonus: int = maxi(0, event_next_reward_rarity_bonus)
	event_next_reward_rarity_bonus = 0
	return bonus


func remove_gold(amount: int) -> void:
	gold = maxi(gold - maxi(0, amount), 0)
	gold_changed.emit(gold)


func reset_stage_hands() -> void:
	stage_hand_cap = BASE_STAGE_HANDS
	hands = stage_hand_cap
	hands_changed.emit(hands)
	lives_changed.emit(hands)


func adjust_stage_hand_cap(amount: int) -> void:
	if amount == 0:
		return
	stage_hand_cap = maxi(1, stage_hand_cap + amount)
	hands = clampi(hands + amount, 0, stage_hand_cap)
	hands_changed.emit(hands)
	lives_changed.emit(hands)


func spend_hand_on_bank(will_clear_stage: bool) -> void:
	hands = maxi(0, hands - 1)
	hands_changed.emit(hands)
	lives_changed.emit(hands)
	if hands <= 0 and not will_clear_stage:
		run_ended.emit()


func spend_hand_on_bust() -> void:
	hands = maxi(0, hands - 1)
	run_busts += 1
	reset_momentum()
	hands_changed.emit(hands)
	lives_changed.emit(hands)
	if hands <= 0:
		run_ended.emit()


func heal_hands(amount: int) -> void:
	hands = mini(hands + maxi(0, amount), stage_hand_cap)
	hands_changed.emit(hands)
	lives_changed.emit(hands)


func heal_lives(amount: int) -> void:
	heal_hands(amount)


func set_current_stage_variant(stage_variant: int) -> void:
	current_stage_variant = SpecialStageCatalogScript.sanitize(stage_variant)
	stage_variant_changed.emit(current_stage_variant)


func has_current_stage_variant() -> bool:
	return current_stage_variant != SpecialStageCatalogScript.Variant.NONE


func get_current_stage_variant_name() -> String:
	return SpecialStageCatalogScript.get_display_name(current_stage_variant)


func get_current_stage_variant_hover_text() -> String:
	return SpecialStageCatalogScript.get_hover_text(current_stage_variant)


func begin_stage_from_map(stage_node: MapNodeData = null) -> void:
	var stage_variant: int = SpecialStageCatalogScript.Variant.NONE
	if stage_node != null:
		stage_variant = stage_node.stage_variant
	set_current_stage_variant(stage_variant)
	clear_next_route_restriction()
	clear_special_stage()

	total_stages_cleared += 1
	current_stage += 1
	total_score = 0
	stage_target_score = _calculate_stage_target(current_stage)
	apply_pending_next_stage_modifiers()
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)


func register_turn_score(turn_score: int) -> bool:
	if turn_score <= best_turn_score:
		return false
	best_turn_score = turn_score
	return true


func _ready() -> void:
	_ensure_seed_service_initialized()
	stage_target_score = _calculate_stage_target(current_stage)
	_build_starting_pool()
	generate_stage_map()


func generate_stage_map() -> void:
	_ensure_seed_service_initialized()
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
			for i: int in 5:
				dice_pool.append(DiceData.make_standard_d6())
			dice_pool.append(DiceData.make_shield_d6())
		Archetype.RISK_IT:
			for i: int in 5:
				dice_pool.append(DiceData.make_gambler_d6())
		Archetype.BLANK_SLATE:
			for i: int in 8:
				dice_pool.append(DiceData.make_blank_canvas_d6())
		Archetype.FORTUNE_FOOL:
			for i: int in 10:
				dice_pool.append(DiceData.make_fortune_d6())
		Archetype.STOP_COLLECTOR:
			for i: int in 4:
				dice_pool.append(DiceData.make_standard_d6())
			dice_pool.append(DiceData.make_gambler_d6())
			dice_pool.append(DiceData.make_shield_d6())
		Archetype.LAST_CALL:
			for i: int in 3:
				dice_pool.append(DiceData.make_gambler_d6())
			for i: int in 2:
				dice_pool.append(DiceData.make_heavy_d6())
			dice_pool.append(DiceData.make_shield_d6())


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
	gold_earned = consume_next_stage_first_bank_gold_bonus(gold_earned)
	add_gold(gold_earned)
	score_changed.emit(total_score)
	turn_banked.emit(points, total_score)
	if total_score >= stage_target_score:
		stage_cleared.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func add_luck(amount: int) -> void:
	var gain: int = amount
	if chosen_archetype == Archetype.FORTUNE_FOOL:
		gain *= 2
	luck += gain
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
	if run_mode == RunMode.CLASSIC:
		var target_row: int = current_row if stage_map else (stage - 1)
		var loop_targets: Array[int] = CLASSIC_LOOP_1_TARGETS if current_loop <= 1 else CLASSIC_LOOP_2_TARGETS
		var base_target: int = loop_targets[clampi(target_row, 0, loop_targets.size() - 1)]
		if current_loop <= 2:
			return base_target
		var loop_two_multiplier: float = 1.0 + 0.5 * (2 - 1)
		return roundi(float(base_target) * (_loop_multiplier() / loop_two_multiplier))
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
	set_current_stage_variant(SpecialStageCatalogScript.Variant.NONE)
	clear_special_stage()
	total_stages_cleared += 1
	current_stage += 1
	total_score = 0
	reset_stage_hands()
	near_death_banks_this_stage = 0
	_last_call_heal_used_this_stage = false
	reset_momentum()
	stage_target_score = _calculate_stage_target(current_stage)
	apply_pending_next_stage_modifiers()
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)


func advance_row(col: int) -> void:
	previous_col = col
	current_row += 1


func advance_loop() -> void:
	clear_special_stage()
	total_stages_cleared += 1
	current_loop += 1
	current_stage = 1
	total_score = 0
	reset_stage_hands()
	set_current_stage_variant(SpecialStageCatalogScript.Variant.NONE)
	near_death_banks_this_stage = 0
	_last_call_heal_used_this_stage = false
	reset_momentum()
	_reset_event_flags()
	clear_active_loop_contract()
	generate_stage_map()
	stage_target_score = _calculate_stage_target(current_stage)
	apply_pending_next_stage_modifiers()
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)
	run_mode_changed.emit(run_mode)
	loop_advanced.emit(current_loop)


func consume_loop_reveal(loop_number: int) -> bool:
	if loop_number in _revealed_loop_numbers:
		return false
	_revealed_loop_numbers.append(loop_number)
	return true


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
# Hand budget
# ---------------------------------------------------------------------------

func lose_life() -> void:
	spend_hand_on_bust()


# ---------------------------------------------------------------------------
# Run reset
# ---------------------------------------------------------------------------

func reset_run() -> void:
	_ensure_seed_service_initialized()
	clear_special_stage()
	current_stage = 1
	current_loop = 1
	current_row = 0
	previous_col = -1
	total_score = 0
	set_current_stage_variant(SpecialStageCatalogScript.Variant.NONE)
	total_stages_cleared = 0
	run_busts = 0
	stage_hand_cap = BASE_STAGE_HANDS
	hands = BASE_STAGE_HANDS
	gold = 0
	best_turn_score = 0
	luck = 0
	current_run_exp = 0
	current_run_stop_shards = 0
	held_stop_count = 0
	near_death_banks_this_stage = 0
	near_death_banks_this_run = 0
	_last_call_heal_used_this_stage = false
	_reset_event_flags()
	reset_momentum()
	active_modifiers.clear()
	clear_active_loop_contract()
	set_has_resumable_run(false)
	_shop_gold_spent = 0
	_miser_bonus_pending = false
	_clear_side_bets()
	prestige_starting_gold_bonus = 20 if SaveManager.has_prestige_unlock("starting_gold") else 0
	prestige_shop_tier_active = SaveManager.has_prestige_unlock("shop_tier")
	prestige_reward_reroll_available = SaveManager.has_prestige_unlock("reward_reroll")
	prestige_reroute_uses = 1 if SaveManager.has_prestige_unlock("reroute_token") else 0
	_revealed_loop_numbers.clear()
	stage_target_score = _calculate_stage_target(current_stage)
	_build_starting_pool()
	if chosen_archetype == Archetype.FORTUNE_FOOL:
		gold = 15 + prestige_starting_gold_bonus
	else:
		gold = prestige_starting_gold_bonus
	generate_stage_map()
	score_changed.emit(total_score)
	hands_changed.emit(hands)
	lives_changed.emit(hands)
	gold_changed.emit(gold)
	run_exp_changed.emit(current_run_exp)
	run_stop_shards_changed.emit(current_run_stop_shards)
	held_stops_changed.emit(held_stop_count)
	stage_advanced.emit(current_stage)
	loop_advanced.emit(current_loop)


func get_archetype_bank_rewards(effective_stops: int, is_near_death_bank: bool) -> Dictionary:
	var rewards: Dictionary = {
		"gold": 0,
		"exp": 0,
		"stop_shards": 0,
		"heal": 0,
	}
	match chosen_archetype:
		Archetype.STOP_COLLECTOR:
			rewards["gold"] = maxi(0, effective_stops) * 2
			if current_loop >= ARCHETYPE_CAPSTONE_LOOP and effective_stops >= 2:
				rewards["exp"] = 1
		Archetype.LAST_CALL:
			if is_near_death_bank and hands < stage_hand_cap and not _last_call_heal_used_this_stage:
				rewards["heal"] = 1
				_last_call_heal_used_this_stage = true
			if current_loop >= ARCHETYPE_CAPSTONE_LOOP and is_near_death_bank:
				rewards["stop_shards"] = 1
	return rewards


func enter_special_stage(rule_id: String) -> void:
	if not SpecialStageRegistryScript.call("has_rule", rule_id):
		clear_special_stage()
		return
	active_special_stage_id = rule_id
	_special_stage_first_reroll_used = false


func clear_special_stage() -> void:
	active_special_stage_id = ""
	_special_stage_first_reroll_used = false


func has_active_special_stage() -> bool:
	return active_special_stage_id != ""


func get_active_special_stage_name() -> String:
	if not has_active_special_stage():
		return ""
	return str(SpecialStageRegistryScript.call("get_rule_name", active_special_stage_id))


func get_active_special_stage_summary() -> String:
	if not has_active_special_stage():
		return ""
	return str(SpecialStageRegistryScript.call("get_rule_summary", active_special_stage_id))


func get_active_special_stage_color() -> Color:
	if not has_active_special_stage():
		return Color.WHITE
	return SpecialStageRegistryScript.call("get_rule_color", active_special_stage_id) as Color


func begin_special_stage_turn() -> void:
	_special_stage_first_reroll_used = false


func apply_special_stage_reroll_bonus(reroll_count: int) -> String:
	if active_special_stage_id != "lucky_floor":
		return ""
	if reroll_count != 1 or _special_stage_first_reroll_used:
		return ""
	_special_stage_first_reroll_used = true
	add_luck(2)
	return "Lucky Floor: first reroll +2 LUCK"


func get_special_stage_bank_preview(effective_stops: int, reroll_count: int) -> Dictionary:
	var result: Dictionary = {
		"bonus_score": 0,
		"bonus_gold": 0,
		"bonus_luck": 0,
		"status_parts": [],
	}
	match active_special_stage_id:
		"lucky_floor":
			if reroll_count >= 2:
				result["bonus_gold"] = 12
				(result["status_parts"] as Array[String]).append("Lucky Floor +12g")
		"clean_room":
			if effective_stops <= 1:
				result["bonus_score"] = 6
				(result["status_parts"] as Array[String]).append("Clean Room +6 score")
		"precision_hall":
			if effective_stops == 2:
				result["bonus_gold"] = 8
				(result["status_parts"] as Array[String]).append("Precision Hall +8g")
	return result


func get_special_stage_clear_rewards(effective_stops: int, will_clear_stage: bool) -> Dictionary:
	var result: Dictionary = {
		"bonus_gold": 0,
		"bonus_luck": 0,
		"status_parts": [],
	}
	if not will_clear_stage:
		return result
	match active_special_stage_id:
		"clean_room":
			if effective_stops <= 1:
				result["bonus_gold"] = 15
				(result["status_parts"] as Array[String]).append("Clean clear +15g")
		"precision_hall":
			if effective_stops == 2:
				result["bonus_luck"] = 3
				(result["status_parts"] as Array[String]).append("Exact clear +3 LUCK")
	return result


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
	_clear_side_bets()


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
	event_next_stage_target_multiplier = 1.0
	event_next_stage_first_bank_gold_multiplier = 1.0
	event_next_stage_clear_gold_multiplier = 1.0
	event_next_stage_starting_stop_pressure = 0
	event_next_reward_rarity_bonus = 0
	event_next_route_restriction = NextRouteRestriction.NONE
	event_next_map_row_reveal = false


func apply_prestige_reward_reroll_used() -> void:
	prestige_reward_reroll_available = false


func use_reroute_token() -> bool:
	if prestige_reroute_uses <= 0:
		return false
	prestige_reroute_uses -= 1
	return true


# ---------------------------------------------------------------------------
# Side-bet helpers
# ---------------------------------------------------------------------------

func _clear_side_bets() -> void:
	insurance_payout = 0
	heat_bet_target_stops = -1
	heat_bet_payout = 0
	even_odd_bet_wager = 0


## Place Insurance Bet: deduct premium, store payout for bust resolution.
func set_insurance_bet(premium: int, payout: int) -> void:
	insurance_payout = payout
	remove_gold(premium)


## Called on bust. Returns the insurance payout (0 if no bet).
func resolve_insurance_bet() -> int:
	var payout: int = insurance_payout
	if payout > 0:
		add_gold(payout)
		insurance_payout = 0
	return payout


## Place Heat Bet: deduct wager, store target and payout.
func set_heat_bet(target_stops: int, wager: int, payout: int) -> void:
	heat_bet_target_stops = target_stops
	heat_bet_payout = payout
	remove_gold(wager)


## Called on bank. Returns payout if stop count matches target (0 otherwise).
func resolve_heat_bet(actual_stops: int) -> int:
	if heat_bet_target_stops < 0:
		return 0
	var payout: int = heat_bet_payout if actual_stops == heat_bet_target_stops else 0
	if payout > 0:
		add_gold(payout)
	heat_bet_target_stops = -1
	heat_bet_payout = 0
	return payout


## Place Even/Odd Bet: store pick and wager amount (not deducted yet — deducted on resolution).
func set_even_odd_bet(is_even: bool, wager: int) -> void:
	even_odd_bet_is_even = is_even
	even_odd_bet_wager = wager
	remove_gold(wager)


## Called on bank. Counts NUMBER-face parity among kept dice values.
## Returns net gold change: +wager on win, 0 on push, -0 on loss (wager already deducted).
## even_count / odd_count are the counts of even/odd NUMBER-face dice kept.
func resolve_even_odd_bet(even_count: int, odd_count: int) -> int:
	if even_odd_bet_wager <= 0:
		return 0
	var wager: int = even_odd_bet_wager
	even_odd_bet_wager = 0
	if even_count == odd_count:
		# Push: refund the wager
		add_gold(wager)
		return 0
	var player_wins: bool = (even_odd_bet_is_even and even_count > odd_count) or \
		(not even_odd_bet_is_even and odd_count > even_count)
	if player_wins:
		add_gold(wager * 2)
		return wager
	return -wager


# ---------------------------------------------------------------------------
# Active run save/load helpers
# ---------------------------------------------------------------------------

func build_active_run_state() -> Dictionary:
	var map_data: Dictionary = {}
	if stage_map != null and stage_map.has_method("to_dict"):
		map_data = stage_map.call("to_dict") as Dictionary
	return {
		"total_score": total_score,
		"hands": hands,
		"stage_hand_cap": stage_hand_cap,
		"lives": hands,
		"current_stage": current_stage,
		"current_loop": current_loop,
		"current_row": current_row,
		"previous_col": previous_col,
		"gold": gold,
		"stage_target_score": stage_target_score,
		"current_stage_variant": current_stage_variant,
		"total_stages_cleared": total_stages_cleared,
		"best_turn_score": best_turn_score,
		"run_busts": run_busts,
		"run_mode": int(run_mode),
		"chosen_archetype": int(chosen_archetype),
		"luck": luck,
		"current_run_exp": current_run_exp,
		"current_run_stop_shards": current_run_stop_shards,
		"held_stop_count": held_stop_count,
		"active_loop_contract_id": active_loop_contract_id,
		"active_loop_contract_progress": active_loop_contract_progress.duplicate(true),
		"offered_loop_contract_ids": offered_loop_contract_ids.duplicate(),
		"near_death_banks_this_stage": near_death_banks_this_stage,
		"near_death_banks_this_run": near_death_banks_this_run,
		"event_free_bust": event_free_bust,
		"event_target_multiplier": event_target_multiplier,
		"event_next_stage_target_multiplier": event_next_stage_target_multiplier,
		"event_next_stage_first_bank_gold_multiplier": event_next_stage_first_bank_gold_multiplier,
		"event_next_stage_clear_gold_multiplier": event_next_stage_clear_gold_multiplier,
		"event_next_stage_starting_stop_pressure": event_next_stage_starting_stop_pressure,
		"event_next_reward_rarity_bonus": event_next_reward_rarity_bonus,
		"event_next_route_restriction": int(event_next_route_restriction),
		"event_next_map_row_reveal": event_next_map_row_reveal,
		"momentum": momentum,
		"shop_gold_spent": _shop_gold_spent,
		"miser_bonus_pending": _miser_bonus_pending,
		"insurance_payout": insurance_payout,
		"heat_bet_target_stops": heat_bet_target_stops,
		"heat_bet_payout": heat_bet_payout,
		"even_odd_bet_is_even": even_odd_bet_is_even,
		"even_odd_bet_wager": even_odd_bet_wager,
		"prestige_starting_gold_bonus": prestige_starting_gold_bonus,
		"prestige_shop_tier_active": prestige_shop_tier_active,
		"prestige_reward_reroll_available": prestige_reward_reroll_available,
		"prestige_reroute_uses": prestige_reroute_uses,
		"revealed_loop_numbers": _revealed_loop_numbers.duplicate(),
		"last_call_heal_used_this_stage": _last_call_heal_used_this_stage,
		"active_special_stage_id": active_special_stage_id,
		"special_stage_first_reroll_used": _special_stage_first_reroll_used,
		"dice_pool": _serialize_dice_pool(),
		"active_modifiers": _serialize_modifiers(),
		"stage_map": map_data,
	}


func apply_active_run_state(data: Dictionary) -> void:
	total_score = int(data.get("total_score", 0))
	hands = int(data.get("hands", data.get("lives", BASE_STAGE_HANDS)))
	stage_hand_cap = int(data.get("stage_hand_cap", maxi(BASE_STAGE_HANDS, hands)))
	current_stage = int(data.get("current_stage", 1))
	current_loop = int(data.get("current_loop", 1))
	current_row = int(data.get("current_row", 0))
	previous_col = int(data.get("previous_col", -1))
	gold = int(data.get("gold", 0))
	stage_target_score = int(data.get("stage_target_score", INITIAL_CLASSIC_STAGE_TARGET))
	current_stage_variant = SpecialStageCatalog.sanitize(int(data.get("current_stage_variant", SpecialStageCatalog.Variant.NONE)))
	total_stages_cleared = int(data.get("total_stages_cleared", 0))
	best_turn_score = int(data.get("best_turn_score", 0))
	run_busts = int(data.get("run_busts", 0))
	run_mode = int(data.get("run_mode", int(RunMode.CLASSIC))) as RunMode
	chosen_archetype = int(data.get("chosen_archetype", int(Archetype.CAUTION))) as Archetype
	luck = int(data.get("luck", 0))
	current_run_exp = int(data.get("current_run_exp", 0))
	current_run_stop_shards = int(data.get("current_run_stop_shards", 0))
	held_stop_count = int(data.get("held_stop_count", 0))
	active_loop_contract_id = str(data.get("active_loop_contract_id", ""))
	active_loop_contract_progress = data.get("active_loop_contract_progress", {}) as Dictionary
	offered_loop_contract_ids.clear()
	for contract_id: Variant in data.get("offered_loop_contract_ids", []) as Array:
		offered_loop_contract_ids.append(str(contract_id))
	near_death_banks_this_stage = int(data.get("near_death_banks_this_stage", 0))
	near_death_banks_this_run = int(data.get("near_death_banks_this_run", 0))
	event_free_bust = bool(data.get("event_free_bust", false))
	event_target_multiplier = float(data.get("event_target_multiplier", 1.0))
	event_next_stage_target_multiplier = float(data.get("event_next_stage_target_multiplier", 1.0))
	event_next_stage_first_bank_gold_multiplier = float(data.get("event_next_stage_first_bank_gold_multiplier", 1.0))
	event_next_stage_clear_gold_multiplier = float(data.get("event_next_stage_clear_gold_multiplier", 1.0))
	event_next_stage_starting_stop_pressure = int(data.get("event_next_stage_starting_stop_pressure", 0))
	event_next_reward_rarity_bonus = int(data.get("event_next_reward_rarity_bonus", 0))
	set_next_route_restriction(int(data.get("event_next_route_restriction", int(NextRouteRestriction.NONE))))
	event_next_map_row_reveal = bool(data.get("event_next_map_row_reveal", false))
	momentum = int(data.get("momentum", 0))
	_shop_gold_spent = int(data.get("shop_gold_spent", 0))
	_miser_bonus_pending = bool(data.get("miser_bonus_pending", false))
	insurance_payout = int(data.get("insurance_payout", 0))
	heat_bet_target_stops = int(data.get("heat_bet_target_stops", -1))
	heat_bet_payout = int(data.get("heat_bet_payout", 0))
	even_odd_bet_is_even = bool(data.get("even_odd_bet_is_even", true))
	even_odd_bet_wager = int(data.get("even_odd_bet_wager", 0))
	prestige_starting_gold_bonus = int(data.get("prestige_starting_gold_bonus", 0))
	prestige_shop_tier_active = bool(data.get("prestige_shop_tier_active", false))
	prestige_reward_reroll_available = bool(data.get("prestige_reward_reroll_available", false))
	prestige_reroute_uses = int(data.get("prestige_reroute_uses", 0))
	_revealed_loop_numbers.clear()
	for loop_number: Variant in data.get("revealed_loop_numbers", []) as Array:
		_revealed_loop_numbers.append(int(loop_number))
	_last_call_heal_used_this_stage = bool(data.get("last_call_heal_used_this_stage", false))
	active_special_stage_id = str(data.get("active_special_stage_id", ""))
	_special_stage_first_reroll_used = bool(data.get("special_stage_first_reroll_used", false))
	dice_pool = _deserialize_dice_pool(data.get("dice_pool", []) as Array)
	active_modifiers = _deserialize_modifiers(data.get("active_modifiers", []) as Array)
	var stage_map_data: Dictionary = data.get("stage_map", {}) as Dictionary
	if not stage_map_data.is_empty():
		stage_map = StageMapDataScript.from_dict(stage_map_data)
	elif stage_map == null:
		generate_stage_map()

	score_changed.emit(total_score)
	hands_changed.emit(hands)
	lives_changed.emit(hands)
	gold_changed.emit(gold)
	luck_changed.emit(luck)
	momentum_changed.emit(momentum)
	stage_variant_changed.emit(current_stage_variant)
	held_stops_changed.emit(held_stop_count)
	run_mode_changed.emit(run_mode)
	run_exp_changed.emit(current_run_exp)
	run_stop_shards_changed.emit(current_run_stop_shards)
	stage_advanced.emit(current_stage)
	loop_advanced.emit(current_loop)
	loop_contract_changed.emit(active_loop_contract_id)
	loop_contract_progress_changed.emit(active_loop_contract_progress.duplicate(true))


func _prepare_new_run_identity(seed_text: String, seeded: bool) -> void:
	if _run_seed_locked:
		clear_active_run_identity()
	var normalized_seed: String = RunSeedServiceScript.normalize_seed_text(seed_text)
	if normalized_seed.is_empty():
		normalized_seed = RunSeedServiceScript.make_random_seed_text()
	is_seeded_run = seeded
	run_seed_text = normalized_seed
	run_seed_version = RunSeedServiceScript.SEED_VERSION
	_run_seed_locked = true
	_ensure_seed_service_initialized()
	_run_seed_service.configure(run_seed_text, run_seed_version)
	run_seed_changed.emit(is_seeded_run, run_seed_text)


func _ensure_seed_service_initialized() -> void:
	if _run_seed_service == null:
		_run_seed_service = RunSeedServiceScript.new()
	if run_seed_version <= 0:
		run_seed_version = RunSeedServiceScript.SEED_VERSION
	if run_seed_text.is_empty():
		run_seed_text = RunSeedServiceScript.make_random_seed_text()
		_run_seed_locked = true
	if _run_seed_service.root_seed_text != run_seed_text or _run_seed_service.seed_version != run_seed_version:
		_run_seed_service.configure(run_seed_text, run_seed_version)


func _serialize_dice_pool() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for die: DiceData in dice_pool:
		serialized.append(_serialize_die(die))
	return serialized


func _deserialize_dice_pool(raw_data: Array) -> Array[DiceData]:
	var deserialized: Array[DiceData] = []
	for die_data: Variant in raw_data:
		if die_data is Dictionary:
			deserialized.append(_deserialize_die(die_data as Dictionary))
	return deserialized


func _serialize_die(die: DiceData) -> Dictionary:
	var faces_data: Array[Dictionary] = []
	for face: DiceFaceData in die.faces:
		faces_data.append({
			"type": int(face.type),
			"value": face.value,
		})
	return {
		"dice_name": die.dice_name,
		"faces": faces_data,
		"custom_color": die.custom_color.to_html(true),
		"rarity": int(die.rarity),
		"reroll_family_id": die.reroll_family_id,
		"reroll_tier": die.reroll_tier,
		"reroll_upgrade_thresholds": die.reroll_upgrade_thresholds.duplicate(),
		"reroll_affinity_locked": die.reroll_affinity_locked,
	}


func _deserialize_die(data: Dictionary) -> DiceData:
	var die := DiceData.new()
	die.dice_name = str(data.get("dice_name", "Standard D6"))
	die.custom_color = Color(str(data.get("custom_color", Color.TRANSPARENT.to_html(true))))
	die.rarity = int(data.get("rarity", int(DiceData.Rarity.GREY))) as DiceData.Rarity
	die.reroll_family_id = str(data.get("reroll_family_id", ""))
	die.reroll_tier = int(data.get("reroll_tier", 0))
	die.reroll_upgrade_thresholds.clear()
	for threshold: Variant in data.get("reroll_upgrade_thresholds", []) as Array:
		die.reroll_upgrade_thresholds.append(int(threshold))
	die.reroll_affinity_locked = bool(data.get("reroll_affinity_locked", false))
	die.faces.clear()
	for face_data: Variant in data.get("faces", []) as Array:
		if not (face_data is Dictionary):
			continue
		var face := DiceFaceData.new()
		face.type = int((face_data as Dictionary).get("type", int(DiceFaceData.FaceType.BLANK))) as DiceFaceData.FaceType
		face.value = int((face_data as Dictionary).get("value", 0))
		die.faces.append(face)
	if die.faces.is_empty():
		return DiceData.make_standard_d6()
	return die


func _serialize_modifiers() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for modifier: RunModifier in active_modifiers:
		serialized.append({
			"type": int(modifier.modifier_type),
		})
	return serialized


func _deserialize_modifiers(raw_data: Array) -> Array[RunModifier]:
	var deserialized: Array[RunModifier] = []
	for modifier_data: Variant in raw_data:
		if not (modifier_data is Dictionary):
			continue
		var modifier_type: int = int((modifier_data as Dictionary).get("type", -1))
		var modifier: RunModifier = _make_modifier_from_type(modifier_type)
		if modifier != null:
			deserialized.append(modifier)
	return deserialized


func _make_modifier_from_type(modifier_type: int) -> RunModifier:
	match modifier_type:
		int(RunModifier.ModifierType.GAMBLERS_RUSH):
			return RunModifier.make_gamblers_rush()
		int(RunModifier.ModifierType.EXPLOSOPHILE):
			return RunModifier.make_explosophile()
		int(RunModifier.ModifierType.IRON_BANK):
			return RunModifier.make_iron_bank()
		int(RunModifier.ModifierType.GLASS_CANNON):
			return RunModifier.make_glass_cannon()
		int(RunModifier.ModifierType.SHIELD_WALL):
			return RunModifier.make_shield_wall()
		int(RunModifier.ModifierType.MISER):
			return RunModifier.make_miser()
		int(RunModifier.ModifierType.DOUBLE_DOWN):
			return RunModifier.make_double_down()
		int(RunModifier.ModifierType.SCAVENGER):
			return RunModifier.make_scavenger()
		int(RunModifier.ModifierType.RECYCLER):
			return RunModifier.make_recycler()
		int(RunModifier.ModifierType.LAST_STAND):
			return RunModifier.make_last_stand()
		int(RunModifier.ModifierType.CHAIN_LIGHTNING):
			return RunModifier.make_chain_lightning()
		int(RunModifier.ModifierType.HIGH_ROLLER):
			return RunModifier.make_high_roller()
		int(RunModifier.ModifierType.OVERCHARGE):
			return RunModifier.make_overcharge()
	return null
