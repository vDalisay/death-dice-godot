class_name BustFlowResolver
extends RefCounted
## Pure helper for bust thresholds, immunity checks, and effective stop math.

const LENIENT_TURN_LIMIT: int = 3
const LENIENT_THRESHOLD_BONUS: int = 1
const GLASS_CANNON_THRESHOLD_PENALTY: int = 1
const LAST_STAND_LIFE_VALUE: int = 1
const LAST_STAND_THRESHOLD_BONUS: int = 2
const MIN_THRESHOLD: int = 1
const DEFAULT_IMMUNE_TURNS: int = 1
const CAUTION_IMMUNE_TURNS: int = 3
const IMMUNITY_STAGE: int = 1


func get_bust_threshold(
	base_threshold: int,
	turn_number: int,
	has_glass_cannon: bool,
	has_last_stand: bool,
	lives: int
) -> int:
	var threshold: int = base_threshold
	if turn_number <= LENIENT_TURN_LIMIT:
		threshold += LENIENT_THRESHOLD_BONUS
	if has_glass_cannon:
		threshold = maxi(MIN_THRESHOLD, threshold - GLASS_CANNON_THRESHOLD_PENALTY)
	if has_last_stand and lives == LAST_STAND_LIFE_VALUE:
		threshold += LAST_STAND_THRESHOLD_BONUS
	return threshold


func is_immune_turn(turn_number: int, stage: int, archetype: int) -> bool:
	var immune_turns: int = DEFAULT_IMMUNE_TURNS
	if archetype == int(GameManager.Archetype.CAUTION):
		immune_turns = CAUTION_IMMUNE_TURNS
	return turn_number <= immune_turns and stage == IMMUNITY_STAGE


func effective_stops(accumulated_stops: int, shield_count: int) -> int:
	return maxi(0, accumulated_stops - shield_count)
