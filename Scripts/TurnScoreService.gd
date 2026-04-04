class_name TurnScoreService
extends RefCounted
## Pure scoring helper for RollPhase.
## Keeps score math centralized and reusable.

const GLASS_CANNON_NUMBER_BONUS: int = 2
const HIGH_ROLLER_VALUE_THRESHOLD: int = 4
const HIGH_ROLLER_NUMBER_BONUS: int = 3
const OVERCHARGE_EXPLODE_MULTIPLIER: int = 2
const CHAIN_LIGHTNING_GROUP_MIN: int = 3
const CHAIN_LIGHTNING_BONUS_PER_DIE: int = 3


func calculate_turn_score(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	has_glass_cannon: bool,
	has_high_roller: bool,
	has_overcharge: bool,
	has_chain_lightning: bool
) -> int:
	var base_scores: Array[int] = _build_base_scores(
		results,
		stopped,
		has_glass_cannon,
		has_high_roller,
		has_overcharge
	)
	if has_chain_lightning:
		_apply_chain_lightning_bonus(base_scores)
	var multiplier: int = _global_multiplier(results, stopped)
	var total: int = 0
	for value: int in base_scores:
		total += value
	return total * multiplier


func calculate_per_die_scores(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	has_glass_cannon: bool,
	has_high_roller: bool,
	has_overcharge: bool
) -> Array[int]:
	var base_scores: Array[int] = _build_base_scores(
		results,
		stopped,
		has_glass_cannon,
		has_high_roller,
		has_overcharge
	)
	var multiplier: int = _global_multiplier(results, stopped)
	var per_die_scores: Array[int] = []
	per_die_scores.resize(results.size())
	for i: int in results.size():
		per_die_scores[i] = base_scores[i] * multiplier
	return per_die_scores


func _build_base_scores(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	has_glass_cannon: bool,
	has_high_roller: bool,
	has_overcharge: bool
) -> Array[int]:
	var base_scores: Array[int] = []
	base_scores.resize(results.size())
	base_scores.fill(0)

	for i: int in results.size():
		if stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.NUMBER:
				var bonus: int = 0
				if has_glass_cannon:
					bonus += GLASS_CANNON_NUMBER_BONUS
				if has_high_roller and face.value >= HIGH_ROLLER_VALUE_THRESHOLD:
					bonus += HIGH_ROLLER_NUMBER_BONUS
				base_scores[i] = face.value + bonus
			DiceFaceData.FaceType.AUTO_KEEP:
				base_scores[i] = face.value
			DiceFaceData.FaceType.EXPLODE:
				base_scores[i] = face.value * (OVERCHARGE_EXPLODE_MULTIPLIER if has_overcharge else 1)

	# MULTIPLY_LEFT applies to the immediate left neighbor's base score.
	for i: int in results.size():
		if stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY_LEFT and i > 0 and not stopped[i - 1]:
			base_scores[i - 1] *= face.value

	return base_scores


func _global_multiplier(results: Array[DiceFaceData], stopped: Array[bool]) -> int:
	var multiplier: int = 1
	for i: int in results.size():
		if stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face != null and face.type == DiceFaceData.FaceType.MULTIPLY:
			multiplier *= face.value
	return multiplier


func _apply_chain_lightning_bonus(base_scores: Array[int]) -> void:
	var grouped_indices: Dictionary = {}
	for i: int in base_scores.size():
		var value: int = base_scores[i]
		if value == 0:
			continue
		if not grouped_indices.has(value):
			grouped_indices[value] = []
		grouped_indices[value].append(i)

	for value: int in grouped_indices:
		var indices: Array = grouped_indices[value]
		if indices.size() < CHAIN_LIGHTNING_GROUP_MIN:
			continue
		for index: int in indices:
			base_scores[index] += CHAIN_LIGHTNING_BONUS_PER_DIE
