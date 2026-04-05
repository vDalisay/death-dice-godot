class_name ContractProgressService
extends RefCounted
## Pure contract progress tracking and completion evaluation.

const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")


func make_initial_progress(contract_id: String) -> Dictionary:
	var contract: LoopContractData = LoopContractCatalogScript.get_by_id(contract_id)
	if contract == null:
		return {}
	return {
		"contract_id": contract.contract_id,
		"current": 0,
		"target": contract.target_value,
		"completed": false,
	}


func on_bank(contract_id: String, progress: Dictionary, context: Dictionary) -> Dictionary:
	var next_progress: Dictionary = _ensure_progress(contract_id, progress)
	if next_progress.is_empty() or bool(next_progress.get("completed", false)):
		return next_progress

	match contract_id:
		"safe_hands":
			if int(context.get("effective_stops", 0)) <= 1:
				_increment_progress(next_progress)
		"one_more_time":
			if int(context.get("reroll_count", 0)) >= 2:
				_complete_progress(next_progress)
		"dead_close":
			if int(context.get("effective_stops", 0)) == int(context.get("threshold", 0)) - 1:
				_complete_progress(next_progress)
		"even_flow":
			var even_count: int = int(context.get("even_count", 0))
			var odd_count: int = int(context.get("odd_count", 0))
			if even_count > 0 and even_count == odd_count:
				_increment_progress(next_progress)
		"exact_heat":
			if int(context.get("effective_stops", 0)) == 2:
				_complete_progress(next_progress)
		"third_spin":
			if int(context.get("reroll_count", 0)) == 3:
				_complete_progress(next_progress)
		"pressure_player":
			if bool(context.get("entered_high_risk", false)):
				_complete_progress(next_progress)
		"shield_line":
			if int(context.get("shield_count", 0)) == 1 and int(context.get("raw_stops", 0)) == 2:
				_complete_progress(next_progress)
	return next_progress


func on_bust(contract_id: String, progress: Dictionary, context: Dictionary) -> Dictionary:
	var next_progress: Dictionary = _ensure_progress(contract_id, progress)
	if next_progress.is_empty() or bool(next_progress.get("completed", false)):
		return next_progress
	if contract_id == "comeback" and bool(context.get("stage_had_bust", false)):
		next_progress["stage_bust_recorded"] = true
	return next_progress


func on_stage_clear(contract_id: String, progress: Dictionary, context: Dictionary) -> Dictionary:
	var next_progress: Dictionary = _ensure_progress(contract_id, progress)
	if next_progress.is_empty() or bool(next_progress.get("completed", false)):
		return next_progress
	match contract_id:
		"clean_finish":
			if not bool(context.get("stage_had_bust", false)):
				_complete_progress(next_progress)
		"comeback":
			if bool(context.get("stage_had_bust", false)):
				_complete_progress(next_progress)
	return next_progress


func format_progress_text(contract_id: String, progress: Dictionary) -> String:
	var contract: LoopContractData = LoopContractCatalogScript.get_by_id(contract_id)
	if contract == null:
		return ""
	var current: int = int(progress.get("current", 0))
	var target: int = int(progress.get("target", contract.target_value))
	var completed: bool = bool(progress.get("completed", false))
	if completed:
		return "%s COMPLETE" % contract.display_name
	return "%s %d/%d" % [contract.display_name, current, target]


func _ensure_progress(contract_id: String, progress: Dictionary) -> Dictionary:
	if contract_id.is_empty():
		return {}
	if progress.is_empty():
		return make_initial_progress(contract_id)
	return progress.duplicate(true)


func _increment_progress(progress: Dictionary, amount: int = 1) -> void:
	var current: int = int(progress.get("current", 0)) + amount
	var target: int = int(progress.get("target", 1))
	progress["current"] = mini(current, target)
	if current >= target:
		progress["completed"] = true


func _complete_progress(progress: Dictionary) -> void:
	progress["current"] = int(progress.get("target", 1))
	progress["completed"] = true