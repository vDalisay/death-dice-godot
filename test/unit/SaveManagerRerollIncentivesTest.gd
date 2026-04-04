extends GdUnitTestSuite

var _saved_experience_currency: int = 0
var _saved_stop_shard_currency: int = 0
var _saved_permanent_upgrade_unlocks: Array[String] = []
var _saved_run_history: Array = []
var _saved_total_runs: int = 0
var _saved_total_busts: int = 0
var _saved_total_stages_cleared: int = 0


func before_test() -> void:
	_saved_experience_currency = SaveManager.experience_currency
	_saved_stop_shard_currency = SaveManager.stop_shard_currency
	_saved_permanent_upgrade_unlocks = SaveManager.permanent_upgrade_unlocks.duplicate()
	_saved_run_history = SaveManager.run_history.duplicate()
	_saved_total_runs = SaveManager.total_runs
	_saved_total_busts = SaveManager.total_busts
	_saved_total_stages_cleared = SaveManager.total_stages_cleared
	SaveManager.experience_currency = 0
	SaveManager.stop_shard_currency = 0
	SaveManager.permanent_upgrade_unlocks.clear()
	SaveManager.run_history.clear()
	SaveManager.total_runs = 0
	SaveManager.total_busts = 0
	SaveManager.total_stages_cleared = 0


func after_test() -> void:
	SaveManager.experience_currency = _saved_experience_currency
	SaveManager.stop_shard_currency = _saved_stop_shard_currency
	SaveManager.permanent_upgrade_unlocks = _saved_permanent_upgrade_unlocks.duplicate()
	SaveManager.run_history = _saved_run_history.duplicate()
	SaveManager.total_runs = _saved_total_runs
	SaveManager.total_busts = _saved_total_busts
	SaveManager.total_stages_cleared = _saved_total_stages_cleared


func test_make_run_snapshot_captures_reroll_incentive_state() -> void:
	GameManager.current_run_exp = 7
	GameManager.current_run_stop_shards = 2
	GameManager.held_stop_count = 1
	GameManager.active_loop_contract_id = "dead_close"
	var snapshot: RunSaveData = SaveManager.make_run_snapshot()
	assert_int(snapshot.exp_earned).is_equal(7)
	assert_int(snapshot.stop_shards_earned).is_equal(2)
	assert_int(snapshot.held_stops_at_end).is_equal(1)
	assert_str(snapshot.active_loop_contract_id).is_equal("dead_close")


func test_record_run_awards_experience_and_stop_shards() -> void:
	var run: RunSaveData = preload("res://Scripts/RunSaveData.gd").new()
	run.exp_earned = 9
	run.stop_shards_earned = 4
	SaveManager.record_run(run)
	assert_int(SaveManager.experience_currency).is_equal(9)
	assert_int(SaveManager.stop_shard_currency).is_equal(4)


func test_purchase_permanent_upgrade_spends_both_currencies() -> void:
	SaveManager.experience_currency = 10
	SaveManager.stop_shard_currency = 5
	var purchased: bool = SaveManager.purchase_permanent_upgrade("high_risk_engine", 6, 3)
	assert_bool(purchased).is_true()
	assert_int(SaveManager.experience_currency).is_equal(4)
	assert_int(SaveManager.stop_shard_currency).is_equal(2)
	assert_bool(SaveManager.has_permanent_upgrade("high_risk_engine")).is_true()