extends GdUnitTestSuite
## Timing tests for bank score animation pacing.

const MainScene: PackedScene = preload("res://Scenes/Main.tscn")
const SpecialStageCatalogScript: GDScript = preload("res://Scripts/SpecialStageCatalog.gd")
const BustOverlayScript: GDScript = preload("res://Scripts/BustOverlay.gd")

var _saved_is_seeded_run: bool = false
var _saved_run_seed_text: String = ""
var _saved_seed_version: int = 1
var _saved_rng_stream_states: Dictionary = {}
var _saved_stage_variant: int = 0
var _saved_special_stage_id: String = ""
var _saved_skip_archetype_picker: bool = false


func before_test() -> void:
	_saved_is_seeded_run = GameManager.is_seeded_run
	_saved_run_seed_text = GameManager.run_seed_text
	_saved_seed_version = GameManager.run_seed_version
	_saved_rng_stream_states = GameManager.snapshot_rng_stream_states()
	_saved_stage_variant = GameManager.current_stage_variant
	_saved_special_stage_id = GameManager.active_special_stage_id
	_saved_skip_archetype_picker = GameManager.skip_archetype_picker


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
	GameManager.set_current_stage_variant(_saved_stage_variant)
	if _saved_special_stage_id.is_empty():
		GameManager.clear_special_stage()
	else:
		GameManager.enter_special_stage(_saved_special_stage_id)
	GameManager.skip_archetype_picker = _saved_skip_archetype_picker


func test_score_tick_base_interval_speeds_up_for_larger_dice_pools() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	var small_pool_interval: float = root._score_tick_base_interval(4, 4)
	var large_pool_interval: float = root._score_tick_base_interval(4, 10)
	assert_float(large_pool_interval).is_less(small_pool_interval)
	assert_float(large_pool_interval).is_greater_equal(RollPhase.SCORE_ANIM_BASE_INTERVAL_FLOOR)


func test_idle_status_context_prefers_active_stage_summary_over_roll_prompt() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	GameManager.set_current_stage_variant(SpecialStageCatalogScript.Variant.CLEAN_ROOM)
	GameManager.enter_special_stage("precision_hall")
	var idle_status: Dictionary = root._get_idle_status_context()
	assert_str(str(idle_status.get("message", ""))).contains("SPECIAL STAGE")
	assert_str(str(idle_status.get("message", ""))).contains(GameManager.get_active_special_stage_summary())
	assert_bool(bool(idle_status.get("has_stage_context", false))).is_true()


func test_bank_cascade_total_duration_waits_for_checkpoint_statuses() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	root._triggered_combo_ids = {"power_pair": true}
	var total_duration: float = root._get_bank_cascade_total_duration(0.6, 2, 1.1)
	var expected_duration: float = 0.6 + float(4) * RollPhase.BANK_CASCADE_STEP_DELAY
	assert_float(total_duration).is_equal(expected_duration)


func test_run_end_highlights_defer_while_banked_state_is_counting() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	root.turn_state = RollPhase.TurnState.BANKED
	root._on_run_ended()
	assert_bool(root.highlights_panel.visible).is_false()
	assert_object(root._pending_run_end_snapshot).is_not_null()


func test_bust_run_end_sequence_waits_for_overlay_before_highlights() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	root.turn_state = RollPhase.TurnState.BUST
	root._on_run_ended()
	root._show_pending_run_end_sequence(4)
	await await_idle_frame()
	assert_bool(root.highlights_panel.visible).is_false()
	await get_tree().create_timer(_run_end_overlay_duration()).timeout
	await await_idle_frame()
	assert_bool(root.highlights_panel.visible).is_true()


func test_banked_run_end_sequence_waits_for_delay_and_overlay() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	root.turn_state = RollPhase.TurnState.BANKED
	root._on_run_ended()
	root._schedule_pending_run_end_sequence(0.2)
	await get_tree().create_timer(0.1).timeout
	await await_idle_frame()
	assert_bool(root.highlights_panel.visible).is_false()
	await get_tree().create_timer(0.2 + _run_end_overlay_duration()).timeout
	await await_idle_frame()
	assert_bool(root.highlights_panel.visible).is_true()


func _run_end_overlay_duration() -> float:
	return BustOverlayScript.PRE_FLASH_DELAY + BustOverlayScript.DROP_DURATION + 1.45