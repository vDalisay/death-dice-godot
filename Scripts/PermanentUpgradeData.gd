class_name PermanentUpgradeData
extends Resource
## Data definition for a persistent account upgrade.

@export var upgrade_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "utility"
@export var exp_cost: int = 0
@export var stop_shard_cost: int = 0
@export var tags: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"upgrade_id": upgrade_id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"exp_cost": exp_cost,
		"stop_shard_cost": stop_shard_cost,
		"tags": tags,
	}