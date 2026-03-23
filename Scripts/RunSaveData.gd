class_name RunSaveData
extends Resource
## Snapshot of a completed run. Extend with dice pool, powerups, etc. later.

@export var score: int = 0
@export var timestamp: String = ""

# Future fields:
# @export var dice_pool: Array[DiceData] = []
# @export var powerups: Array[String] = []
# @export var stages_cleared: int = 0

func to_dict() -> Dictionary:
	return {
		"score": score,
		"timestamp": timestamp,
	}
