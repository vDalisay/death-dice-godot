class_name RollResolutionService
extends RefCounted
## Pure helper for roll-result stop/shield accounting and bust outcome resolution.

enum BustOutcome {
	SAFE,
	IMMUNE_SAVE,
	INSURANCE_SAVE,
	EVENT_SAVE,
	BUST,
}

const CURSED_STOP_WEIGHT: int = 2
const SHIELD_WALL_MULTIPLIER: int = 2
const NORMAL_SHIELD_MULTIPLIER: int = 1


func is_stop_face(face: DiceFaceData) -> bool:
	if face == null:
		return false
	return face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP


func is_cursed_stop(face: DiceFaceData) -> bool:
	return face != null and face.type == DiceFaceData.FaceType.CURSED_STOP


func stop_weight(face: DiceFaceData) -> int:
	if face == null:
		return 0
	if face.type == DiceFaceData.FaceType.CURSED_STOP:
		return CURSED_STOP_WEIGHT
	if face.type == DiceFaceData.FaceType.STOP:
		return 1
	return 0


func count_stops_in(indices: Array[int], stopped: Array[bool], results: Array[DiceFaceData]) -> int:
	var total: int = 0
	for i: int in indices:
		if i < 0 or i >= stopped.size() or i >= results.size():
			continue
		if not stopped[i]:
			continue
		total += stop_weight(results[i])
	return total


func count_shields(results: Array[DiceFaceData], has_shield_wall: bool) -> int:
	var multiplier: int = SHIELD_WALL_MULTIPLIER if has_shield_wall else NORMAL_SHIELD_MULTIPLIER
	var total: int = 0
	for face: DiceFaceData in results:
		if face != null and face.type == DiceFaceData.FaceType.SHIELD:
			total += face.value * multiplier
	return total


func has_cursed_stop_in(indices: Array[int], results: Array[DiceFaceData]) -> bool:
	for i: int in indices:
		if i < 0 or i >= results.size():
			continue
		if is_cursed_stop(results[i]):
			return true
	return false


func resolve_bust_outcome(
	effective_stops: int,
	threshold: int,
	is_immune: bool,
	insurance_index: int,
	event_free_bust_available: bool
) -> BustOutcome:
	if effective_stops < threshold:
		return BustOutcome.SAFE
	if is_immune:
		return BustOutcome.IMMUNE_SAVE
	if insurance_index >= 0:
		return BustOutcome.INSURANCE_SAVE
	if event_free_bust_available:
		return BustOutcome.EVENT_SAVE
	return BustOutcome.BUST


func absorbed_stop_count(roll_stop_count: int, shield_count: int) -> int:
	if roll_stop_count <= 0 or shield_count <= 0:
		return 0
	var remaining: int = maxi(0, roll_stop_count - shield_count)
	return roll_stop_count - remaining
