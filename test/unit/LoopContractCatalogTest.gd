extends GdUnitTestSuite

const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")
const LoopContractData := preload("res://Scripts/LoopContractData.gd")

var _saved_is_seeded_run: bool = false
var _saved_run_seed_text: String = ""
var _saved_seed_version: int = 1
var _saved_rng_stream_states: Dictionary = {}


func before_test() -> void:
	_saved_is_seeded_run = GameManager.is_seeded_run
	_saved_run_seed_text = GameManager.run_seed_text
	_saved_seed_version = GameManager.run_seed_version
	_saved_rng_stream_states = GameManager.snapshot_rng_stream_states()


func after_test() -> void:
	if _saved_run_seed_text.is_empty():
		GameManager.clear_active_run_identity()
	else:
		GameManager.restore_run_identity(
			_saved_run_seed_text,
			_saved_is_seeded_run,
			_saved_seed_version,
			_saved_rng_stream_states
		)


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


func test_loop_one_pool_expands_to_five_contracts() -> void:
	var pool_ids: Array[String] = LoopContractCatalogScript.get_pool_ids_for_loop(1)
	assert_int(pool_ids.size()).is_equal(5)
	assert_array(pool_ids).contains(["safe_hands", "one_more_time", "dead_close", "even_flow", "clean_finish"])


func test_lookup_by_id_returns_reward_payload() -> void:
	var contract: LoopContractData = LoopContractCatalogScript.get_by_id("pressure_player")
	assert_object(contract).is_not_null()
	assert_int(contract.reward_gold).is_equal(28)
	assert_int(contract.reward_stop_shards).is_equal(1)


func test_loop_one_can_offer_four_contracts_with_upgrade() -> void:
	var offers: Array[LoopContractData] = LoopContractCatalogScript.get_offers_for_loop(1, 4)
	assert_int(offers.size()).is_equal(4)
	assert_str(offers[3].contract_id).is_equal("even_flow")


func test_random_offers_for_loop_use_seeded_unique_pool_subset() -> void:
	GameManager.restore_run_identity("contract-pool-seed", true, 1)
	var first_offers: Array[LoopContractData] = LoopContractCatalogScript.get_random_offers_for_loop(1, 3)
	GameManager.restore_run_identity("contract-pool-seed", true, 1)
	var second_offers: Array[LoopContractData] = LoopContractCatalogScript.get_random_offers_for_loop(1, 3)
	var pool_ids: Array[String] = LoopContractCatalogScript.get_pool_ids_for_loop(1)
	var first_ids: Array[String] = []
	var second_ids: Array[String] = []
	var unique_ids: Dictionary = {}
	for offer: LoopContractData in first_offers:
		first_ids.append(offer.contract_id)
		unique_ids[offer.contract_id] = true
		assert_bool(pool_ids.has(offer.contract_id)).is_true()
	for offer: LoopContractData in second_offers:
		second_ids.append(offer.contract_id)
	assert_int(first_offers.size()).is_equal(3)
	assert_int(unique_ids.size()).is_equal(3)
	assert_str(",".join(first_ids)).is_equal(",".join(second_ids))