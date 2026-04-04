class_name LoopContractData
extends Resource
## Data definition for a loop contract offer.

@export var contract_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "steady"
@export var reward_gold: int = 0
@export var reward_exp: int = 0
@export var reward_stop_shards: int = 0
@export var target_value: int = 0
@export var tags: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"contract_id": contract_id,
		"display_name": display_name,
		"description": description,
		"category": category,
		"reward_gold": reward_gold,
		"reward_exp": reward_exp,
		"reward_stop_shards": reward_stop_shards,
		"target_value": target_value,
		"tags": tags,
	}