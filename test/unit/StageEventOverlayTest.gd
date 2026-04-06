extends GdUnitTestSuite
## Unit tests for StageEventOverlay bargain events and GameManager event flags.

const StageEventScript: GDScript = preload("res://Scripts/StageEventOverlay.gd")
const StageEventScene: PackedScene = preload("res://Scenes/StageEventOverlay.tscn")

var _gm: Node
var _overlay: Node

## Snapshot of autoload state so we can restore in after_test.
var _orig_dice_pool: Array[DiceData] = []
var _orig_gold: int = 0
var _orig_lives: int = 0
var _orig_stage_target: int = 0
var _orig_next_stage_target_multiplier: float = 1.0
var _orig_next_stage_first_bank_gold_multiplier: float = 1.0
var _orig_next_stage_clear_gold_multiplier: float = 1.0
var _orig_next_stage_starting_stop_pressure: int = 0
var _orig_run_stop_shards: int = 0


func before_test() -> void:
	# Local GameManager instance for flag-only tests.
	_gm = auto_free(preload("res://Scripts/GameManager.gd").new())
	_overlay = auto_free(StageEventScript.new())
	# Save autoload state before overlay effect tests touch it.
	_orig_dice_pool = GameManager.dice_pool.duplicate()
	_orig_gold = GameManager.gold
	_orig_lives = GameManager.lives
	_orig_stage_target = GameManager.stage_target_score
	_orig_next_stage_target_multiplier = GameManager.event_next_stage_target_multiplier
	_orig_next_stage_first_bank_gold_multiplier = GameManager.event_next_stage_first_bank_gold_multiplier
	_orig_next_stage_clear_gold_multiplier = GameManager.event_next_stage_clear_gold_multiplier
	_orig_next_stage_starting_stop_pressure = GameManager.event_next_stage_starting_stop_pressure
	_orig_run_stop_shards = GameManager.current_run_stop_shards


func after_test() -> void:
	# Restore autoload state to avoid bleeding between tests.
	GameManager.dice_pool = _orig_dice_pool
	GameManager.gold = _orig_gold
	GameManager.lives = _orig_lives
	GameManager.stage_target_score = _orig_stage_target
	GameManager.event_free_bust = false
	GameManager.event_target_multiplier = 1.0
	GameManager.event_next_stage_target_multiplier = _orig_next_stage_target_multiplier
	GameManager.event_next_stage_first_bank_gold_multiplier = _orig_next_stage_first_bank_gold_multiplier
	GameManager.event_next_stage_clear_gold_multiplier = _orig_next_stage_clear_gold_multiplier
	GameManager.event_next_stage_starting_stop_pressure = _orig_next_stage_starting_stop_pressure
	GameManager.current_run_stop_shards = _orig_run_stop_shards


# ---------------------------------------------------------------------------
# Event flag management
# ---------------------------------------------------------------------------

func test_event_flags_default_values() -> void:
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_first_bank_gold_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_clear_gold_multiplier).is_equal(1.0)
	assert_int(_gm.event_next_stage_starting_stop_pressure).is_equal(0)


func test_reset_event_flags() -> void:
	_gm.event_free_bust = true
	_gm.event_target_multiplier = 1.15
	_gm.event_next_stage_target_multiplier = 1.2
	_gm.event_next_stage_first_bank_gold_multiplier = 1.35
	_gm.event_next_stage_clear_gold_multiplier = 2.0
	_gm.event_next_stage_starting_stop_pressure = 1
	_gm._reset_event_flags()
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_first_bank_gold_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_clear_gold_multiplier).is_equal(1.0)
	assert_int(_gm.event_next_stage_starting_stop_pressure).is_equal(0)


func test_reset_run_clears_event_flags() -> void:
	_gm.event_free_bust = true
	_gm.event_target_multiplier = 1.15
	_gm.event_next_stage_target_multiplier = 1.2
	_gm.event_next_stage_first_bank_gold_multiplier = 1.35
	_gm.event_next_stage_clear_gold_multiplier = 2.0
	_gm.event_next_stage_starting_stop_pressure = 1
	_gm.reset_run()
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_target_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_first_bank_gold_multiplier).is_equal(1.0)
	assert_float(_gm.event_next_stage_clear_gold_multiplier).is_equal(1.0)
	assert_int(_gm.event_next_stage_starting_stop_pressure).is_equal(0)


# ---------------------------------------------------------------------------
# Blessing effects (use real GameManager autoload since overlay references it)
# ---------------------------------------------------------------------------

func test_boost_number_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	GameManager.dice_pool.append(die)
	var original_values: Array[int] = []
	for face: DiceFaceData in die.faces:
		original_values.append(face.value)
	_overlay._boost_number_faces(1)
	for i: int in die.faces.size():
		if die.faces[i].type == DiceFaceData.FaceType.NUMBER:
			assert_int(die.faces[i].value).is_equal(original_values[i] + 1)


func test_boost_shield_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	# Replace first non-stop face with a shield for testing.
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.NUMBER:
			face.type = DiceFaceData.FaceType.SHIELD
			face.value = 1
			break
	GameManager.dice_pool.append(die)
	_overlay._boost_shield_faces(1)
	var found_shield: bool = false
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.SHIELD:
			assert_int(face.value).is_equal(2)
			found_shield = true
			break
	assert_bool(found_shield).is_true()


func test_gain_random_dice() -> void:
	var before_size: int = GameManager.dice_pool.size()
	var gained_dice: Array[DiceData] = _overlay._gain_random_dice(2)
	assert_int(GameManager.dice_pool.size()).is_equal(before_size + 2)
	assert_int(gained_dice.size()).is_equal(2)
	for die: DiceData in gained_dice:
		assert_bool(GameManager.dice_pool.has(die)).is_true()


func test_gain_random_dice_summary_lists_awarded_dice() -> void:
	var gained_dice: Array[DiceData] = [DiceData.make_standard_d6(), DiceData.make_blank_canvas_d6()]
	var summary: String = _overlay._build_effect_summary(
		{"summary": "EVENT: The Collector marked your next stage for a premium die"},
		{"gained_dice": gained_dice}
	)
	assert_str(summary).contains(gained_dice[0].dice_name)
	assert_str(summary).contains(gained_dice[1].dice_name)


func test_free_bust_sets_flag() -> void:
	_overlay._apply_effect({"type": 2})
	assert_bool(GameManager.event_free_bust).is_true()


func test_gain_gold_adds_30() -> void:
	var before_gold: int = GameManager.gold
	_overlay._apply_effect({"type": 4})
	assert_int(GameManager.gold).is_equal(before_gold + 30)


# ---------------------------------------------------------------------------
# Curse effects (use real GameManager autoload)
# ---------------------------------------------------------------------------

func test_lose_random_die() -> void:
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	var before_size: int = GameManager.dice_pool.size()
	_overlay._lose_random_die()
	assert_int(GameManager.dice_pool.size()).is_equal(before_size - 1)


func test_lose_die_wont_go_below_one() -> void:
	# Reduce pool to exactly 1 die.
	GameManager.dice_pool.clear()
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	_overlay._lose_random_die()
	assert_int(GameManager.dice_pool.size()).is_equal(1)


func test_add_cursed_stop_to_random_die() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	GameManager.dice_pool.clear()
	GameManager.dice_pool.append(die)
	_overlay._add_cursed_stop_to_random_die()
	var has_cursed: bool = false
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.CURSED_STOP:
			has_cursed = true
			break
	assert_bool(has_cursed).is_true()


func test_boost_targets_sets_multiplier() -> void:
	GameManager.stage_target_score = 100
	_overlay._apply_effect({"type": 7})
	assert_float(GameManager.event_target_multiplier).is_equal(1.15)
	assert_int(GameManager.stage_target_score).is_equal(115)


func test_set_next_stage_target_multiplier_sets_flag() -> void:
	_overlay._apply_effect({"type": StageEventScript.EffectType.SET_NEXT_STAGE_TARGET_MULTIPLIER, "multiplier": 1.2})
	assert_float(GameManager.event_next_stage_target_multiplier).is_equal(1.2)


func test_set_next_stage_first_bank_gold_multiplier_sets_flag() -> void:
	_overlay._apply_effect({"type": StageEventScript.EffectType.SET_NEXT_STAGE_FIRST_BANK_GOLD_MULTIPLIER, "multiplier": 1.35})
	assert_float(GameManager.event_next_stage_first_bank_gold_multiplier).is_equal(1.35)


func test_set_next_stage_clear_gold_multiplier_sets_flag() -> void:
	_overlay._apply_effect({"type": StageEventScript.EffectType.SET_NEXT_STAGE_CLEAR_GOLD_MULTIPLIER, "multiplier": 2.0})
	assert_float(GameManager.event_next_stage_clear_gold_multiplier).is_equal(2.0)


func test_gain_stop_shards_adds_to_run_total() -> void:
	GameManager.current_run_stop_shards = 0
	_overlay._apply_effect({"type": StageEventScript.EffectType.GAIN_STOP_SHARDS, "amount": 25})
	assert_int(GameManager.current_run_stop_shards).is_equal(25)


func test_set_next_stage_starting_stop_pressure_sets_flag() -> void:
	_overlay._apply_effect({"type": StageEventScript.EffectType.SET_NEXT_STAGE_STARTING_STOP_PRESSURE, "amount": 1})
	assert_int(GameManager.event_next_stage_starting_stop_pressure).is_equal(1)


func test_reset_momentum_effect_sets_momentum_to_zero() -> void:
	GameManager.momentum = 3
	_overlay._apply_effect({"type": StageEventScript.EffectType.RESET_MOMENTUM})
	assert_int(GameManager.momentum).is_equal(0)


func test_lose_life_decrements() -> void:
	GameManager.reset_stage_hands()
	_overlay._apply_effect({"type": 8})
	assert_int(GameManager.hands).is_equal(4)


func test_lose_life_emits_lives_changed() -> void:
	GameManager.reset_stage_hands()
	monitor_signals(GameManager, false)
	_overlay._apply_effect({"type": 8})
	assert_signal(GameManager).is_emitted("hands_changed", [4])


func test_lose_life_does_not_end_run_when_budget_reduced_between_stages() -> void:
	GameManager.reset_stage_hands()
	monitor_signals(GameManager, false)
	_overlay._apply_effect({"type": 8})
	assert_int(GameManager.hands).is_equal(4)
	assert_signal(GameManager).is_not_emitted("run_ended")


func test_lose_gold_removes_20() -> void:
	GameManager.gold = 50
	_overlay._apply_effect({"type": 9})
	assert_int(GameManager.gold).is_equal(30)


func test_lose_gold_emits_gold_changed() -> void:
	GameManager.gold = 50
	monitor_signals(GameManager, false)
	_overlay._apply_effect({"type": 9})
	assert_signal(GameManager).is_emitted("gold_changed", [30])


func test_lose_gold_clamps_to_zero() -> void:
	GameManager.gold = 5
	_overlay._apply_effect({"type": 9})
	assert_int(GameManager.gold).is_equal(0)


# ---------------------------------------------------------------------------
# Overlay data selection
# ---------------------------------------------------------------------------

func test_event_pool_is_non_empty() -> void:
	var event_pool: Array[Dictionary] = _overlay._build_event_pool()
	assert_bool(event_pool.size() > 0).is_true()


func test_each_event_has_three_choices() -> void:
	for event_data: Dictionary in _overlay._build_event_pool():
		assert_bool(event_data.has("title")).is_true()
		assert_bool(event_data.has("flavor")).is_true()
		assert_bool(event_data.has("choices")).is_true()
		assert_int((event_data.get("choices", []) as Array).size()).is_equal(3)


func test_each_choice_has_required_keys() -> void:
	for event_data: Dictionary in _overlay._build_event_pool():
		for choice: Dictionary in event_data.get("choices", []) as Array[Dictionary]:
			assert_bool(choice.has("category")).is_true()
			assert_bool(choice.has("name")).is_true()
			assert_bool(choice.has("icon")).is_true()
			assert_bool(choice.has("upside")).is_true()
			assert_bool(choice.has("downside")).is_true()
			assert_bool(choice.has("effects")).is_true()
			assert_bool(not (choice.get("upside", "") as String).is_empty()).is_true()
			assert_bool(not (choice.get("effects", []) as Array).is_empty()).is_true()


func test_choice_description_uses_trade_language() -> void:
	var description: String = _overlay._build_choice_description({
		"upside": "+20g now",
		"downside": "Lose 1 random die",
	})
	assert_str(description).contains("UP: +20g now")
	assert_str(description).contains("DOWN: Lose 1 random die")


func test_gain_random_dice_choice_waits_for_result_continue() -> void:
	var overlay: ColorRect = auto_free(StageEventScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	var event_data: Dictionary = {
		"title": "THE COLLECTOR",
		"flavor": "A lacquered broker offers clean money and one dangerous gift.",
		"choices": [
			{
				"category": StageEventScript.CHOICE_PREMIUM,
				"name": "Take the Marked Prize",
				"icon": "🎲",
				"color_key": "ACTION_CYAN",
				"upside": "+1 random die",
				"downside": "Next stage target +12%",
				"summary": "EVENT: The Collector marked your next stage for a premium die",
				"effects": [
					{"type": StageEventScript.EffectType.GAIN_RANDOM_DICE, "count": 1},
					{"type": StageEventScript.EffectType.BOOST_TARGETS, "multiplier": 1.12},
				],
			},
			{
				"category": StageEventScript.CHOICE_SAFE,
				"name": "Take the Cash",
				"icon": "💰",
				"color_key": "SCORE_GOLD",
				"upside": "+20g now",
				"downside": "No extra risk",
				"summary": "EVENT: The Collector paid 20g",
				"effects": [{"type": StageEventScript.EffectType.GAIN_GOLD, "amount": 20}],
			},
			{
				"category": StageEventScript.CHOICE_BARGAIN,
				"name": "Sell a Die",
				"icon": "🗡",
				"color_key": "EXPLOSION_ORANGE",
				"upside": "+55g immediately",
				"downside": "Lose 1 random die",
				"summary": "EVENT: The Collector bought a die for 55g",
				"effects": [
					{"type": StageEventScript.EffectType.LOSE_DIE, "count": 1},
					{"type": StageEventScript.EffectType.GAIN_GOLD, "amount": 55},
				],
			},
		],
	}
	overlay.set("_current_event", event_data)
	overlay.call("_apply_event_copy", event_data)
	var premium_card: PanelContainer = overlay.call("_build_choice_card", (event_data["choices"] as Array)[0], 0) as PanelContainer
	var safe_card: PanelContainer = overlay.call("_build_choice_card", (event_data["choices"] as Array)[1], 1) as PanelContainer
	var bargain_card: PanelContainer = overlay.call("_build_choice_card", (event_data["choices"] as Array)[2], 2) as PanelContainer
	var choice_row: HBoxContainer = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ChoiceRow") as HBoxContainer
	choice_row.add_child(premium_card)
	choice_row.add_child(safe_card)
	choice_row.add_child(bargain_card)
	overlay.set("_choice_cards", [premium_card, safe_card, bargain_card])
	monitor_signals(overlay, false)
	overlay.call("_on_choice_made", 0)
	await get_tree().create_timer(0.75).timeout
	assert_signal(overlay).is_not_emitted("event_resolved")
	var continue_button: Button = overlay.get("_continue_button") as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.visible).is_true()
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	assert_str(title_label.text).is_equal("REWARD GAINED")
	continue_button.pressed.emit()
	assert_signal(overlay).is_emitted("event_resolved")
