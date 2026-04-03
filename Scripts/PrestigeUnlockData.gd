class_name PrestigeUnlockData
extends Resource
## Data definition for a permanent prestige unlock.

@export var unlock_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var skull_cost: int = 0


static func make(id: String, name: String, desc: String, cost: int) -> PrestigeUnlockData:
	var data := PrestigeUnlockData.new()
	data.unlock_id = id
	data.display_name = name
	data.description = desc
	data.skull_cost = cost
	return data


static func get_all() -> Array[PrestigeUnlockData]:
	return [
		PrestigeUnlockData.make("starting_gold", "Gold Reserve", "+20 gold at run start.", 5),
		PrestigeUnlockData.make("shop_tier", "Market Insider", "Loop 2+ shop dice can appear from loop 1.", 8),
		PrestigeUnlockData.make("reward_reroll", "Second Glance", "1 free dice reward reroll per run.", 10),
		PrestigeUnlockData.make("reroute_token", "Cartographer", "1 free map reroute per run.", 12),
		PrestigeUnlockData.make("new_events", "Chaos Magnet", "Unlocks extra blessing/curse events.", 15),
		PrestigeUnlockData.make("new_archetype", "Fortune's Fool", "Unlocks a high-luck archetype.", 20),
		PrestigeUnlockData.make("skull_cosmetic", "Death's Glow", "Unlocks skull shimmer cosmetic purchases.", 10),
	]
