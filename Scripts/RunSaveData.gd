class_name RunSaveData
extends Resource
## Snapshot of a completed run. Extend with dice pool, powerups, etc. later.

@export var score: int = 0
@export var timestamp: String = ""
@export var stages_cleared: int = 0
@export var loops_completed: int = 0
@export var busts: int = 0
@export var best_turn_score: int = 0
@export var final_dice_names: Array[String] = []
@export var run_mode: int = 0
@export var prestige_skulls_earned: int = 0
@export var exp_earned: int = 0
@export var stop_shards_earned: int = 0
@export var held_stops_at_end: int = 0
@export var active_loop_contract_id: String = ""

func to_dict() -> Dictionary:
	return {
		"score": score,
		"timestamp": timestamp,
		"stages_cleared": stages_cleared,
		"loops_completed": loops_completed,
		"busts": busts,
		"best_turn_score": best_turn_score,
		"final_dice_names": final_dice_names,
		"run_mode": run_mode,
		"prestige_skulls_earned": prestige_skulls_earned,
		"exp_earned": exp_earned,
		"stop_shards_earned": stop_shards_earned,
		"held_stops_at_end": held_stops_at_end,
		"active_loop_contract_id": active_loop_contract_id,
	}


func load_from_dict(data: Dictionary) -> void:
	score = data.get("score", 0) as int
	timestamp = data.get("timestamp", "") as String
	stages_cleared = data.get("stages_cleared", 0) as int
	loops_completed = data.get("loops_completed", 0) as int
	busts = data.get("busts", 0) as int
	best_turn_score = data.get("best_turn_score", 0) as int
	final_dice_names.clear()
	for die_name: Variant in data.get("final_dice_names", []) as Array:
		final_dice_names.append(die_name as String)
	run_mode = data.get("run_mode", 0) as int
	prestige_skulls_earned = data.get("prestige_skulls_earned", 0) as int
	exp_earned = data.get("exp_earned", 0) as int
	stop_shards_earned = data.get("stop_shards_earned", 0) as int
	held_stops_at_end = data.get("held_stops_at_end", 0) as int
	active_loop_contract_id = data.get("active_loop_contract_id", "") as String
