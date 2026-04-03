class_name BustRiskEstimator
extends RefCounted
## Pure helper for turn-level bust risk odds and tooltip text.

const MIN_HORIZON_ROLLS: int = 1
const STOP_FACE_WEIGHT: int = 1
const CURSED_STOP_FACE_WEIGHT: int = 2
const MIN_CHANCE: float = 0.0
const MAX_CHANCE: float = 1.0
const PERCENT_MULTIPLIER: float = 100.0


func estimate_next_reroll_bust_chance(
	effective_stops: int,
	threshold: int,
	dice_pool: Array[DiceData],
	dice_keep: Array[bool],
	dice_keep_locked: Array[bool]
) -> float:
	var stops_needed: int = threshold - effective_stops
	if stops_needed <= 0:
		return 1.0

	var distribution: Array[float] = [1.0]
	for i: int in dice_pool.size():
		if _is_kept_or_locked(i, dice_keep, dice_keep_locked):
			continue
		var die_data: DiceData = dice_pool[i]
		if die_data == null or die_data.faces.is_empty():
			continue

		var face_count: float = float(die_data.faces.size())
		var zero_stops_probability: float = 0.0
		var one_stop_probability: float = 0.0
		var two_stops_probability: float = 0.0
		for face: DiceFaceData in die_data.faces:
			if face == null:
				continue
			match face.type:
				DiceFaceData.FaceType.CURSED_STOP:
					two_stops_probability += 1.0 / face_count
				DiceFaceData.FaceType.STOP:
					one_stop_probability += 1.0 / face_count
				_:
					zero_stops_probability += 1.0 / face_count

		var next_distribution: Array[float] = []
		next_distribution.resize(distribution.size() + CURSED_STOP_FACE_WEIGHT)
		next_distribution.fill(0.0)
		for s: int in distribution.size():
			var base_prob: float = distribution[s]
			next_distribution[s] += base_prob * zero_stops_probability
			next_distribution[s + STOP_FACE_WEIGHT] += base_prob * one_stop_probability
			next_distribution[s + CURSED_STOP_FACE_WEIGHT] += base_prob * two_stops_probability
		distribution = next_distribution

	var chance: float = 0.0
	for s: int in distribution.size():
		if s >= stops_needed:
			chance += distribution[s]
	return clampf(chance, MIN_CHANCE, MAX_CHANCE)


func estimate_bust_odds(
	effective_stops: int,
	threshold: int,
	reroll_count: int,
	dice_pool: Array[DiceData],
	dice_keep: Array[bool],
	dice_keep_locked: Array[bool]
) -> float:
	var next_roll_chance: float = estimate_next_reroll_bust_chance(
		effective_stops,
		threshold,
		dice_pool,
		dice_keep,
		dice_keep_locked
	)
	return estimate_projected_bust_odds(next_roll_chance, reroll_count)


func estimate_projected_bust_odds(next_roll_chance: float, reroll_count: int) -> float:
	var horizon_rolls: int = maxi(MIN_HORIZON_ROLLS, reroll_count + 1)
	var survive_all: float = pow(1.0 - next_roll_chance, float(horizon_rolls))
	return clampf(1.0 - survive_all, MIN_CHANCE, MAX_CHANCE)


func build_risk_details(
	effective_stops: int,
	shield_count: int,
	threshold: int,
	next_roll_chance: float,
	projected_odds: float,
	rerollable_count: int,
	reroll_count: int
) -> String:
	var next_roll_odds: int = int(round(next_roll_chance * PERCENT_MULTIPLIER))
	var projected_percent: int = int(round(projected_odds * PERCENT_MULTIPLIER))
	return "Bust odds (next reroll): %d%%\nProjected odds (current reroll streak): %d%%\nStops: %d/%d (shields: %d)\nRerollable dice: %d | Rerolls taken: %d" % [
		next_roll_odds,
		projected_percent,
		effective_stops,
		threshold,
		shield_count,
		rerollable_count,
		reroll_count,
	]


func _is_kept_or_locked(index: int, dice_keep: Array[bool], dice_keep_locked: Array[bool]) -> bool:
	if index < 0 or index >= dice_keep.size() or index >= dice_keep_locked.size():
		return true
	return dice_keep[index] or dice_keep_locked[index]
