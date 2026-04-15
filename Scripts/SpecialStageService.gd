class_name SpecialStageService extends RefCounted
## Manages active special stage state and computes rule-based rewards/bonuses.
## Side effects (luck, gold) are handled by the caller (GameManager).

const SpecialStageRegistryScript: GDScript = preload("res://Scripts/SpecialStageRegistry.gd")

var active_id: String = ""
var _first_reroll_used: bool = false


func enter(rule_id: String) -> void:
	if not SpecialStageRegistryScript.call("has_rule", rule_id):
		clear()
		return
	active_id = rule_id
	_first_reroll_used = false


func clear() -> void:
	active_id = ""
	_first_reroll_used = false


func is_active() -> bool:
	return active_id != ""


func get_name() -> String:
	if not is_active():
		return ""
	return str(SpecialStageRegistryScript.call("get_rule_name", active_id))


func get_summary() -> String:
	if not is_active():
		return ""
	return str(SpecialStageRegistryScript.call("get_rule_summary", active_id))


func get_color() -> Color:
	if not is_active():
		return Color.WHITE
	return SpecialStageRegistryScript.call("get_rule_color", active_id) as Color


func begin_turn() -> void:
	_first_reroll_used = false


## Returns {luck_bonus: int, message: String}.
func check_reroll_bonus(reroll_count: int) -> Dictionary:
	if active_id != "lucky_floor":
		return {"luck_bonus": 0, "message": ""}
	if reroll_count != 1 or _first_reroll_used:
		return {"luck_bonus": 0, "message": ""}
	_first_reroll_used = true
	return {"luck_bonus": 2, "message": "Lucky Floor: first reroll +2 LUCK"}


func get_bank_preview(effective_stops: int, reroll_count: int) -> Dictionary:
	var result: Dictionary = {
		"bonus_score": 0,
		"bonus_gold": 0,
		"bonus_luck": 0,
		"status_parts": [],
	}
	match active_id:
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


func get_clear_rewards(effective_stops: int, will_clear_stage: bool) -> Dictionary:
	var result: Dictionary = {
		"bonus_gold": 0,
		"bonus_luck": 0,
		"status_parts": [],
	}
	if not will_clear_stage:
		return result
	match active_id:
		"clean_room":
			if effective_stops <= 1:
				result["bonus_gold"] = 15
				(result["status_parts"] as Array[String]).append("Clean clear +15g")
		"precision_hall":
			if effective_stops == 2:
				result["bonus_luck"] = 3
				(result["status_parts"] as Array[String]).append("Exact clear +3 LUCK")
	return result


func build_snapshot() -> Dictionary:
	return {
		"active_special_stage_id": active_id,
		"special_stage_first_reroll_used": _first_reroll_used,
	}


func restore_snapshot(data: Dictionary) -> void:
	active_id = str(data.get("active_special_stage_id", ""))
	_first_reroll_used = bool(data.get("special_stage_first_reroll_used", false))
