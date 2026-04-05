class_name LoopContractCatalog
extends RefCounted
## Static catalog and offer rules for loop contracts.

const LoopContractDataScript: GDScript = preload("res://Scripts/LoopContractData.gd")
const LoopContractDataType: GDScript = preload("res://Scripts/LoopContractData.gd")


static func make(
	id: String,
	name: String,
	description: String,
	category: String,
	reward_gold: int,
	reward_exp: int,
	reward_stop_shards: int,
	target_value: int,
	tags: Array[String] = []
) -> LoopContractDataType:
	var data: LoopContractDataType = LoopContractDataScript.new()
	data.contract_id = id
	data.display_name = name
	data.description = description
	data.category = category
	data.reward_gold = reward_gold
	data.reward_exp = reward_exp
	data.reward_stop_shards = reward_stop_shards
	data.target_value = target_value
	data.tags = tags.duplicate()
	return data


static func get_all() -> Array[LoopContractDataType]:
	return [
		make("safe_hands", "Safe Hands", "Bank 3 turns this loop with 0-1 effective stops.", "steady", 20, 1, 0, 3, ["bank", "low_stop"]),
		make("one_more_time", "One More Time", "Bank once after at least 2 rerolls.", "greedy", 18, 1, 0, 1, ["bank", "reroll_depth"]),
		make("dead_close", "Dead Close", "Bank once while exactly 1 stop from bust.", "exact", 24, 1, 1, 1, ["bank", "exact_stop"]),
		make("even_flow", "Even Flow", "Bank 2 turns with equal odd and even kept number dice.", "steady", 18, 1, 0, 2, ["bank", "parity"]),
		make("clean_finish", "Clean Finish", "Clear a stage without busting.", "steady", 24, 2, 0, 1, ["stage_clear", "clean"]),
		make("exact_heat", "Exact Heat", "Bank once with exactly 2 effective stops.", "exact", 24, 1, 1, 1, ["bank", "exact_stop"]),
		make("third_spin", "Third Spin", "Bank after exactly 3 rerolls.", "greedy", 24, 1, 0, 1, ["bank", "reroll_depth"]),
		make("pressure_player", "Pressure Player", "Enter HIGH risk and still bank safely once this loop.", "steady", 28, 2, 1, 1, ["bank", "high_risk"]),
		make("shield_line", "Shield Line", "Bank with exactly 1 shield and 2 raw stops.", "exact", 28, 2, 1, 1, ["bank", "shield", "exact_stop"]),
		make("comeback", "Comeback", "Bust once this stage and still clear it.", "steady", 30, 2, 1, 1, ["stage_clear", "comeback"]),
	]


static func get_by_id(contract_id: String) -> LoopContractDataType:
	for contract: LoopContractDataType in get_all():
		if contract.contract_id == contract_id:
			return contract
	return null


static func get_offers_for_loop(loop_number: int, offer_count: int = 3) -> Array[LoopContractDataType]:
	var offer_ids: Array[String] = []
	if loop_number <= 1:
		offer_ids = ["safe_hands", "one_more_time", "dead_close", "even_flow"]
	elif loop_number == 2:
		offer_ids = ["comeback", "third_spin", "shield_line", "clean_finish"]
	else:
		offer_ids = ["pressure_player", "third_spin", "exact_heat", "clean_finish"]
	var offers: Array[LoopContractDataType] = []
	for contract_id: String in offer_ids:
		if offers.size() >= offer_count:
			break
		var contract: LoopContractDataType = get_by_id(contract_id)
		if contract != null:
			offers.append(contract)
	return offers