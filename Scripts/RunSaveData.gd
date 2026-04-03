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
	}
