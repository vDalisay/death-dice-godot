extends GdUnitTestSuite

const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")


func test_loop_one_offers_three_teaching_contracts() -> void:
	var offers: Array[LoopContractData] = LoopContractCatalogScript.get_offers_for_loop(1)
	assert_int(offers.size()).is_equal(3)
	assert_str(offers[0].contract_id).is_equal("safe_hands")
	assert_str(offers[1].contract_id).is_equal("one_more_time")
	assert_str(offers[2].contract_id).is_equal("dead_close")


func test_loop_two_offers_cover_distinct_categories() -> void:
	var offers: Array[LoopContractData] = LoopContractCatalogScript.get_offers_for_loop(2)
	var categories: Array[String] = []
	for offer: LoopContractData in offers:
		categories.append(offer.category)
	assert_int(offers.size()).is_equal(3)
	assert_bool(categories.has("steady")).is_true()
	assert_bool(categories.has("greedy")).is_true()
	assert_bool(categories.has("exact")).is_true()


func test_lookup_by_id_returns_reward_payload() -> void:
	var contract: LoopContractData = LoopContractCatalogScript.get_by_id("pressure_player")
	assert_object(contract).is_not_null()
	assert_int(contract.reward_gold).is_equal(28)
	assert_int(contract.reward_stop_shards).is_equal(1)