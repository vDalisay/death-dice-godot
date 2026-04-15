class_name RollPhaseSnapshot
extends RefCounted
## Pure data marshalling for RollPhase save / resume.
## Handles serialisation of per-die arrays and turn state without any scene
## or node references, so it can live as a lightweight RefCounted service.

const DiceFaceDataScript: GDScript = preload("res://Scripts/DiceFaceData.gd")


## Build a full mid-turn roll-phase state dictionary from the host's fields.
func build_roll_phase_state(fields: Dictionary) -> Dictionary:
	return {
		"turn_state": int(fields.get("turn_state", 0)),
		"turn_number": int(fields.get("turn_number", 0)),
		"accumulated_stop_count": int(fields.get("accumulated_stop_count", 0)),
		"accumulated_shield_count": int(fields.get("accumulated_shield_count", 0)),
		"run_active": bool(fields.get("run_active", true)),
		"loop_complete_pending": bool(fields.get("loop_complete_pending", false)),
		"bank_streak": int(fields.get("bank_streak", 0)),
		"reroll_count": int(fields.get("reroll_count", 0)),
		"run_snapshot_recorded": bool(fields.get("run_snapshot_recorded", false)),
		"triggered_combo_ids": (fields.get("triggered_combo_ids", {}) as Dictionary).duplicate(true),
		"stage_had_bust": bool(fields.get("stage_had_bust", false)),
		"turn_entered_high_risk": bool(fields.get("turn_entered_high_risk", false)),
		"current_results": serialize_face_array(fields.get("current_results", []) as Array[DiceFaceData]),
		"dice_stopped": (fields.get("dice_stopped", []) as Array[bool]).duplicate(),
		"dice_keep": (fields.get("dice_keep", []) as Array[bool]).duplicate(),
		"dice_keep_locked": (fields.get("dice_keep_locked", []) as Array[bool]).duplicate(),
		"die_reroll_counts": (fields.get("die_reroll_counts", []) as Array[int]).duplicate(),
		"was_displaced": (fields.get("was_displaced", []) as Array[bool]).duplicate(),
		"cluster_child_flags": (fields.get("cluster_child_flags", []) as Array[bool]).duplicate(),
	}


## Build a clean turn-checkpoint state (for non-turn resume surfaces).
func build_turn_checkpoint_state(fields: Dictionary) -> Dictionary:
	var dice_count: int = int(fields.get("dice_count", 0))
	var empty_results: Array = []
	var stopped: Array = []
	var keep: Array = []
	var keep_locked: Array = []
	var reroll_counts: Array = []
	var displaced: Array = []
	var cluster_children: Array = []
	for _i: int in dice_count:
		empty_results.append({})
		stopped.append(false)
		keep.append(false)
		keep_locked.append(false)
		reroll_counts.append(0)
		displaced.append(false)
		cluster_children.append(false)
	return {
		"turn_state": 0,  # TurnState.IDLE
		"turn_number": int(fields.get("turn_number", 0)),
		"accumulated_stop_count": 0,
		"accumulated_shield_count": 0,
		"run_active": true,
		"loop_complete_pending": bool(fields.get("loop_complete_pending", false)),
		"bank_streak": int(fields.get("bank_streak", 0)),
		"reroll_count": 0,
		"run_snapshot_recorded": bool(fields.get("run_snapshot_recorded", false)),
		"triggered_combo_ids": {},
		"stage_had_bust": bool(fields.get("stage_had_bust", false)),
		"turn_entered_high_risk": false,
		"current_results": empty_results,
		"dice_stopped": stopped,
		"dice_keep": keep,
		"dice_keep_locked": keep_locked,
		"die_reroll_counts": reroll_counts,
		"was_displaced": displaced,
		"cluster_child_flags": cluster_children,
	}


## Restore roll-phase state from a serialised dictionary, returning a
## dictionary of field values to apply back to the host.
func restore_roll_phase_state(data: Dictionary, expected_count: int) -> Dictionary:
	var result: Dictionary = {
		"turn_state": int(data.get("turn_state", 0)),
		"turn_number": int(data.get("turn_number", 0)),
		"accumulated_stop_count": int(data.get("accumulated_stop_count", 0)),
		"accumulated_shield_count": int(data.get("accumulated_shield_count", 0)),
		"run_active": bool(data.get("run_active", true)),
		"loop_complete_pending": bool(data.get("loop_complete_pending", false)),
		"bank_streak": int(data.get("bank_streak", 0)),
		"reroll_count": int(data.get("reroll_count", 0)),
		"run_snapshot_recorded": bool(data.get("run_snapshot_recorded", false)),
		"triggered_combo_ids": data.get("triggered_combo_ids", {}) as Dictionary,
		"stage_had_bust": bool(data.get("stage_had_bust", false)),
		"turn_entered_high_risk": bool(data.get("turn_entered_high_risk", false)),
	}

	result["current_results"] = deserialize_face_array(data.get("current_results", []) as Array)

	var dice_stopped: Array[bool] = []
	for value: Variant in data.get("dice_stopped", []) as Array:
		dice_stopped.append(bool(value))
	result["dice_stopped"] = dice_stopped

	var dice_keep: Array[bool] = []
	for value: Variant in data.get("dice_keep", []) as Array:
		dice_keep.append(bool(value))
	result["dice_keep"] = dice_keep

	var dice_keep_locked: Array[bool] = []
	for value: Variant in data.get("dice_keep_locked", []) as Array:
		dice_keep_locked.append(bool(value))
	result["dice_keep_locked"] = dice_keep_locked

	var die_reroll_counts: Array[int] = []
	for value: Variant in data.get("die_reroll_counts", []) as Array:
		die_reroll_counts.append(int(value))
	result["die_reroll_counts"] = die_reroll_counts

	var was_displaced: Array[bool] = []
	for value: Variant in data.get("was_displaced", []) as Array:
		was_displaced.append(bool(value))
	result["was_displaced"] = was_displaced

	var cluster_child_flags: Array[bool] = []
	for value: Variant in data.get("cluster_child_flags", []) as Array:
		cluster_child_flags.append(bool(value))
	result["cluster_child_flags"] = cluster_child_flags

	# Resize all arrays to match expected dice pool count.
	_resize_array(result, "current_results", expected_count)
	_resize_bool_array(result, "dice_stopped", expected_count)
	_resize_bool_array(result, "dice_keep", expected_count)
	_resize_bool_array(result, "dice_keep_locked", expected_count)
	_resize_int_array(result, "die_reroll_counts", expected_count)
	_resize_bool_array(result, "was_displaced", expected_count)
	_resize_bool_array(result, "cluster_child_flags", expected_count)

	return result


func serialize_face_array(faces: Array[DiceFaceData]) -> Array:
	var serialized: Array = []
	for face: DiceFaceData in faces:
		if face == null:
			serialized.append({})
			continue
		serialized.append({
			"type": int(face.type),
			"value": int(face.value),
		})
	return serialized


func deserialize_face_array(data: Array) -> Array[DiceFaceData]:
	var faces: Array[DiceFaceData] = []
	for entry: Variant in data:
		if not (entry is Dictionary):
			faces.append(null)
			continue
		var entry_dict: Dictionary = entry as Dictionary
		if entry_dict.is_empty():
			faces.append(null)
			continue
		var face := DiceFaceData.new()
		face.type = int(entry_dict.get("type", int(DiceFaceData.FaceType.BLANK))) as DiceFaceData.FaceType
		face.value = int(entry_dict.get("value", 0))
		faces.append(face)
	return faces


func _resize_array(result: Dictionary, key: String, expected: int) -> void:
	var arr: Array = result.get(key, []) as Array
	if arr.size() != expected:
		arr.resize(expected)
	result[key] = arr


func _resize_bool_array(result: Dictionary, key: String, expected: int) -> void:
	var arr: Array[bool] = result.get(key, []) as Array[bool]
	if arr.size() != expected:
		arr.resize(expected)
	result[key] = arr


func _resize_int_array(result: Dictionary, key: String, expected: int) -> void:
	var arr: Array[int] = result.get(key, []) as Array[int]
	if arr.size() != expected:
		arr.resize(expected)
	result[key] = arr
