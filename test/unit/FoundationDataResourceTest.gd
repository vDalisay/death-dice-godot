extends GdUnitTestSuite

const LoopContractData := preload("res://Scripts/LoopContractData.gd")
const PermanentUpgradeData := preload("res://Scripts/PermanentUpgradeData.gd")


func test_loop_contract_data_to_dict_includes_reward_fields() -> void:
	var data: LoopContractData = auto_free(preload("res://Scripts/LoopContractData.gd").new())
	data.contract_id = "safe_hands"
	data.reward_gold = 15
	data.reward_exp = 2
	data.reward_stop_shards = 1
	var serialized: Dictionary = data.to_dict()
	assert_str(serialized["contract_id"] as String).is_equal("safe_hands")
	assert_int(int(serialized["reward_gold"])).is_equal(15)
	assert_int(int(serialized["reward_exp"])).is_equal(2)
	assert_int(int(serialized["reward_stop_shards"])).is_equal(1)


func test_permanent_upgrade_data_to_dict_includes_dual_costs() -> void:
	var data: PermanentUpgradeData = auto_free(preload("res://Scripts/PermanentUpgradeData.gd").new())
	data.upgrade_id = "high_risk_engine"
	data.exp_cost = 12
	data.stop_shard_cost = 4
	var serialized: Dictionary = data.to_dict()
	assert_str(serialized["upgrade_id"] as String).is_equal("high_risk_engine")
	assert_int(int(serialized["exp_cost"])).is_equal(12)
	assert_int(int(serialized["stop_shard_cost"])).is_equal(4)


func test_permanent_upgrade_catalog_exposes_contract_scout() -> void:
	var upgrade: PermanentUpgradeData = PermanentUpgradeData.get_by_id("contract_scout")
	assert_object(upgrade).is_not_null()
	assert_str(upgrade.display_name).is_equal("Contract Scout")
	assert_int(upgrade.exp_cost).is_equal(12)
	assert_int(upgrade.stop_shard_cost).is_equal(4)