class_name PermanentUpgradeData
extends Resource
## Data definition for a persistent account upgrade.

const CATALOG: Array[Dictionary] = [
	{
		"upgrade_id": "reroll_ledger",
		"display_name": "Reroll Ledger",
		"description": "Bank after 2+ rerolls to earn +2 run EXP.",
		"category": "economy",
		"exp_cost": 6,
		"stop_shard_cost": 1,
		"tags": ["reroll", "exp"],
	},
	{
		"upgrade_id": "close_call_study",
		"display_name": "Close Call Study",
		"description": "Bank a HIGH-risk turn to earn +1 run EXP.",
		"category": "economy",
		"exp_cost": 8,
		"stop_shard_cost": 2,
		"tags": ["high_risk", "exp"],
	},
	{
		"upgrade_id": "shard_magnet",
		"display_name": "Shard Magnet",
		"description": "Near-death banks grant +1 extra Stop Shard.",
		"category": "economy",
		"exp_cost": 10,
		"stop_shard_cost": 3,
		"tags": ["near_death", "stop_shard"],
	},
	{
		"upgrade_id": "contract_scout",
		"display_name": "Contract Scout",
		"description": "Loop contract picks offer 4 cards instead of 3.",
		"category": "contracts",
		"exp_cost": 12,
		"stop_shard_cost": 4,
		"tags": ["contracts", "offers"],
	},
]

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


static func make(
	id: String,
	name: String,
	desc: String,
	group: String,
	exp_cost_value: int,
	stop_shard_cost_value: int,
	tag_list: Array[String] = []
) -> PermanentUpgradeData:
	var data := new()
	data.upgrade_id = id
	data.display_name = name
	data.description = desc
	data.category = group
	data.exp_cost = exp_cost_value
	data.stop_shard_cost = stop_shard_cost_value
	data.tags = tag_list.duplicate()
	return data


static func get_all() -> Array[PermanentUpgradeData]:
	var upgrades: Array[PermanentUpgradeData] = []
	for entry: Dictionary in CATALOG:
		var tag_values: Array[String] = []
		for tag: Variant in entry.get("tags", []) as Array:
			tag_values.append(tag as String)
		upgrades.append(make(
			entry.get("upgrade_id", "") as String,
			entry.get("display_name", "") as String,
			entry.get("description", "") as String,
			entry.get("category", "utility") as String,
			entry.get("exp_cost", 0) as int,
			entry.get("stop_shard_cost", 0) as int,
			tag_values
		))
	return upgrades


static func get_by_id(upgrade_id_value: String) -> PermanentUpgradeData:
	for upgrade: PermanentUpgradeData in get_all():
		if upgrade.upgrade_id == upgrade_id_value:
			return upgrade
	return null