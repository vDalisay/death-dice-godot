class_name StageProgressionService extends RefCounted
## Pure computation for stage/loop progression math.
## All methods are static — no state, no side effects.

const STAGES_LOOP_1: int = 5
const STAGES_LOOP_2_PLUS: int = 7
const BASE_STAGE_TARGET: int = 30
const STAGE_TARGET_STEP: int = 25
const STAGE_CLEAR_GOLD_BONUS: int = 20
const LOOP_BONUS_GOLD_STEP: int = 10
const GAUNTLET_LOOP_MULT_STEP: float = 0.75
const GAUNTLET_STAGE_STEP_MULT: float = 1.25
const CLASSIC_LOOP_1_TARGETS: Array[int] = [18, 26, 34, 42, 52]
const CLASSIC_LOOP_2_TARGETS: Array[int] = [24, 36, 48, 62, 78, 96, 118]
const INITIAL_CLASSIC_STAGE_TARGET: int = 18


static func get_stages_in_loop(loop: int) -> int:
	if loop <= 1:
		return STAGES_LOOP_1
	return STAGES_LOOP_2_PLUS


static func loop_multiplier(loop: int, is_gauntlet: bool) -> float:
	if is_gauntlet:
		return 1.0 + GAUNTLET_LOOP_MULT_STEP * (loop - 1)
	return 1.0 + 0.5 * (loop - 1)


static func calculate_stage_target(loop: int, row: int, is_gauntlet: bool) -> int:
	if not is_gauntlet:
		var loop_targets: Array[int] = CLASSIC_LOOP_1_TARGETS if loop <= 1 else CLASSIC_LOOP_2_TARGETS
		var base_target: int = loop_targets[clampi(row, 0, loop_targets.size() - 1)]
		if loop <= 2:
			return base_target
		var loop_two_mult: float = 1.0 + 0.5 * (2 - 1)
		return roundi(float(base_target) * (loop_multiplier(loop, false) / loop_two_mult))
	var mult: float = loop_multiplier(loop, true)
	return int(BASE_STAGE_TARGET * mult) + row * int(STAGE_TARGET_STEP * mult * GAUNTLET_STAGE_STEP_MULT)


static func get_stage_clear_bonus(loop: int, double_bonus: bool) -> int:
	var base: int = STAGE_CLEAR_GOLD_BONUS + LOOP_BONUS_GOLD_STEP * (loop - 1)
	if double_bonus:
		base *= 2
	return base
