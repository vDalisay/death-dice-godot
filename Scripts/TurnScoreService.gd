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
const MULTIPLY_RADIUS: float = 90.0


func calculate_turn_score(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	positions: Array[Vector2],
	multiplies_stops_flags: Array[bool],
	was_displaced: Array[bool],
	has_shrapnel: bool,
	has_glass_cannon: bool,
	has_high_roller: bool,
	has_overcharge: bool,
	has_chain_lightning: bool
) -> int:
	var base_scores: Array[int] = _build_base_scores(
		results,
		stopped,
		was_displaced,
		has_shrapnel,
		has_glass_cannon,
		has_high_roller,
		has_overcharge
	)
	_apply_proximity_multipliers(base_scores, results, stopped, positions, multiplies_stops_flags)
	if has_chain_lightning:
		_apply_chain_lightning_bonus(base_scores)
	var total: int = 0
	for value: int in base_scores:
		total += value
	return total


func calculate_per_die_scores(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	positions: Array[Vector2],
	multiplies_stops_flags: Array[bool],
	was_displaced: Array[bool],
	has_shrapnel: bool,
	has_glass_cannon: bool,
	has_high_roller: bool,
	has_overcharge: bool
) -> Array[int]:
	var base_scores: Array[int] = _build_base_scores(
		results,
		stopped,
		was_displaced,
		has_shrapnel,
		has_glass_cannon,
		has_high_roller,
		has_overcharge
	)
	_apply_proximity_multipliers(base_scores, results, stopped, positions, multiplies_stops_flags)
	var per_die_scores: Array[int] = []
	per_die_scores.resize(results.size())
	for i: int in results.size():
		per_die_scores[i] = base_scores[i]
	return per_die_scores


func calculate_effective_stop_counts(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	positions: Array[Vector2],
	multiplies_stops_flags: Array[bool]
) -> Array[int]:
	var stop_counts: Array[int] = []
	stop_counts.resize(results.size())
	stop_counts.fill(0)
	for i: int in results.size():
		if i >= stopped.size() or not stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.CURSED_STOP:
			stop_counts[i] = 2
		elif face.type == DiceFaceData.FaceType.STOP:
			stop_counts[i] = 1
	for i: int in results.size():
		if i >= stopped.size() or stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face == null or face.type != DiceFaceData.FaceType.MULTIPLY:
			continue
		if i >= multiplies_stops_flags.size() or not multiplies_stops_flags[i]:
			continue
		var source_position: Vector2 = positions[i] if i < positions.size() else Vector2.ZERO
		for target_index: int in _neighbor_indices(source_position, positions, MULTIPLY_RADIUS, i):
			if target_index < stop_counts.size() and stop_counts[target_index] > 0:
				stop_counts[target_index] *= maxi(1, face.value)
	return stop_counts


func _build_base_scores(
	results: Array[DiceFaceData],
	stopped: Array[bool],
	was_displaced: Array[bool],
	has_shrapnel: bool,
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
				if has_shrapnel and i < was_displaced.size() and was_displaced[i]:
					bonus += 1
				base_scores[i] = face.value + bonus
			DiceFaceData.FaceType.AUTO_KEEP:
				base_scores[i] = face.value
			DiceFaceData.FaceType.EXPLODE:
				base_scores[i] = face.value * (OVERCHARGE_EXPLODE_MULTIPLIER if has_overcharge else 1)

	return base_scores


func _apply_proximity_multipliers(
	base_scores: Array[int],
	results: Array[DiceFaceData],
	stopped: Array[bool],
	positions: Array[Vector2],
	multiplies_stops_flags: Array[bool]
) -> void:
	for i: int in results.size():
		if i >= stopped.size() or stopped[i]:
			continue
		var face: DiceFaceData = results[i]
		if face == null or face.type != DiceFaceData.FaceType.MULTIPLY:
			continue
		var source_position: Vector2 = positions[i] if i < positions.size() else Vector2.ZERO
		for target_index: int in _neighbor_indices(source_position, positions, MULTIPLY_RADIUS, i):
			if target_index < base_scores.size():
				base_scores[target_index] *= maxi(1, face.value)
		if i < multiplies_stops_flags.size() and multiplies_stops_flags[i]:
			continue


func _neighbor_indices(center: Vector2, positions: Array[Vector2], radius: float, exclude_index: int) -> Array[int]:
	var neighbors: Array[int] = []
	var radius_sq: float = radius * radius
	for i: int in positions.size():
		if i == exclude_index:
			continue
		if positions[i].distance_squared_to(center) <= radius_sq:
			neighbors.append(i)
	return neighbors


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
