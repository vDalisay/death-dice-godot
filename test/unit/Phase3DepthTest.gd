extends GdUnitTestSuite
## Tests for Phase 3 — Strategic Roguelite Depth:
## Modifiers (integration), archetypes, CURSED_STOP, curse events.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()


func _make_face(type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


# ---------------------------------------------------------------------------
# GameManager modifier helpers
# ---------------------------------------------------------------------------

func test_has_modifier_false_when_empty() -> void:
	GameManager.active_modifiers.clear()
	assert_bool(GameManager.has_modifier(RunModifier.ModifierType.IRON_BANK)).is_false()


func test_add_modifier_success() -> void:
	GameManager.active_modifiers.clear()
	var mod: RunModifier = RunModifier.make_iron_bank()
	var added: bool = GameManager.add_modifier(mod)
	assert_bool(added).is_true()
	assert_bool(GameManager.has_modifier(RunModifier.ModifierType.IRON_BANK)).is_true()
	GameManager.active_modifiers.clear()


func test_add_modifier_capped_at_max() -> void:
	GameManager.active_modifiers.clear()
	GameManager.add_modifier(RunModifier.make_iron_bank())
	GameManager.add_modifier(RunModifier.make_shield_wall())
	GameManager.add_modifier(RunModifier.make_miser())
	assert_bool(GameManager.can_add_modifier()).is_false()
	var result: bool = GameManager.add_modifier(RunModifier.make_explosophile())
	assert_bool(result).is_false()
	assert_int(GameManager.active_modifiers.size()).is_equal(GameManager.MAX_MODIFIERS)
	GameManager.active_modifiers.clear()


func test_reset_run_clears_modifiers() -> void:
	GameManager.active_modifiers.clear()
	GameManager.add_modifier(RunModifier.make_iron_bank())
	GameManager.reset_run()
	assert_bool(GameManager.active_modifiers.is_empty()).is_true()


# ---------------------------------------------------------------------------
# Archetype starting pools
# ---------------------------------------------------------------------------

func test_caution_archetype_pool() -> void:
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	assert_int(GameManager.dice_pool.size()).is_equal(6)
	for die: DiceData in GameManager.dice_pool:
		assert_str(die.dice_name).is_equal("Standard D6")


func test_risk_it_archetype_pool() -> void:
	GameManager.chosen_archetype = GameManager.Archetype.RISK_IT
	GameManager.reset_run()
	assert_int(GameManager.dice_pool.size()).is_equal(5)
	for die: DiceData in GameManager.dice_pool:
		assert_str(die.dice_name).is_equal("Gambler D6")
	# Cleanup
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()


func test_blank_slate_archetype_pool() -> void:
	GameManager.chosen_archetype = GameManager.Archetype.BLANK_SLATE
	GameManager.reset_run()
	assert_int(GameManager.dice_pool.size()).is_equal(8)
	for die: DiceData in GameManager.dice_pool:
		assert_str(die.dice_name).is_equal("Blank Canvas D6")
	# Cleanup
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()


func test_risk_it_doubles_gold() -> void:
	GameManager.chosen_archetype = GameManager.Archetype.RISK_IT
	GameManager.reset_run()
	GameManager.stage_target_score = 9999
	var gold_before: int = GameManager.gold
	GameManager.add_score(10)
	# Risk It: 2x gold from score → 20g
	assert_int(GameManager.gold - gold_before).is_equal(20)
	# Cleanup
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()


func test_blank_slate_doubles_clear_bonus() -> void:
	GameManager.chosen_archetype = GameManager.Archetype.BLANK_SLATE
	GameManager.reset_run()
	var bonus: int = GameManager.get_stage_clear_bonus()
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	var normal_bonus: int = GameManager.get_stage_clear_bonus()
	assert_int(bonus).is_equal(normal_bonus * 2)
	GameManager.reset_run()


# ---------------------------------------------------------------------------
# CURSED_STOP face type
# ---------------------------------------------------------------------------

func test_cursed_stop_display_text() -> void:
	var face: DiceFaceData = _make_face(DiceFaceData.FaceType.CURSED_STOP, 0)
	assert_str(face.get_display_text()).is_equal("☠STOP")


func test_cursed_stop_counts_in_stop_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	# Replace one non-stop face with CURSED_STOP
	die.faces[0].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[0].value = 0
	# Standard has 1 STOP + 1 CURSED_STOP = 2
	assert_int(die._count_stop_faces()).is_equal(2)


func test_cursed_stop_has_stop_face() -> void:
	var die: DiceData = DiceData.new()
	die.dice_name = "Test"
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.CURSED_STOP
	die.faces.append(face)
	assert_bool(die.has_stop_face()).is_true()


func test_cursed_stop_face_power_lower_than_stop() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	var cursed: DiceFaceData = _make_face(DiceFaceData.FaceType.CURSED_STOP, 0)
	var stop: DiceFaceData = _make_face(DiceFaceData.FaceType.STOP, 0)
	assert_int(die._face_power(cursed)).is_less(die._face_power(stop))


func test_upgrade_cursed_stop_becomes_stop() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	die.faces[0].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[0].value = 0
	var upgraded: bool = die.upgrade_weakest_face()
	assert_bool(upgraded).is_true()
	# The cursed face should now be a regular STOP.
	assert_int(die.faces[0].type).is_equal(DiceFaceData.FaceType.STOP)


# ---------------------------------------------------------------------------
# Glass Cannon modifier
# ---------------------------------------------------------------------------

func test_glass_cannon_reduces_threshold() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	# Without Glass Cannon, turn 1-3 threshold = 4, turn 4+ = 3.
	root.turn_number = 4
	var normal: int = root._get_bust_threshold()
	GameManager.add_modifier(RunModifier.make_glass_cannon())
	var reduced: int = root._get_bust_threshold()
	assert_int(reduced).is_equal(normal - 1)
	GameManager.active_modifiers.clear()


# ---------------------------------------------------------------------------
# Shield Wall modifier
# ---------------------------------------------------------------------------

func test_shield_wall_doubles_shields() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	# Set up a shield face.
	var shield: DiceFaceData = _make_face(DiceFaceData.FaceType.SHIELD, 1)
	root.current_results[0] = shield
	root.dice_stopped[0] = false
	var normal_shields: int = root._count_shields()
	GameManager.add_modifier(RunModifier.make_shield_wall())
	var boosted_shields: int = root._count_shields()
	assert_int(boosted_shields).is_equal(normal_shields * 2)
	GameManager.active_modifiers.clear()


# ---------------------------------------------------------------------------
# Iron Bank modifier
# ---------------------------------------------------------------------------

func test_iron_bank_bonus_no_rerolls() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	GameManager.add_modifier(RunModifier.make_iron_bank())
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		GameManager.active_modifiers.clear()
		return
	# Force clean state: all dice are NUMBER 2, no stops.
	root.accumulated_stop_count = 0
	root._reroll_count = 0
	for i: int in GameManager.dice_pool.size():
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 2)
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)
	# pool_size dice × 2 = base, iron bank +50% → int(base * 1.5)
	var expected: int = int(GameManager.dice_pool.size() * 2 * 1.5)
	assert_int(GameManager.total_score).is_equal(expected)
	GameManager.active_modifiers.clear()


# ---------------------------------------------------------------------------
# Miser modifier
# ---------------------------------------------------------------------------

func test_miser_tracks_shop_spending() -> void:
	GameManager.active_modifiers.clear()
	GameManager.add_modifier(RunModifier.make_miser())
	GameManager._shop_gold_spent = 0
	GameManager.track_shop_spend(10)
	assert_int(GameManager._shop_gold_spent).is_equal(10)
	GameManager.active_modifiers.clear()


func test_miser_bonus_triggers_under_threshold() -> void:
	GameManager.active_modifiers.clear()
	GameManager.add_modifier(RunModifier.make_miser())
	GameManager._shop_gold_spent = 10
	GameManager.on_shop_exited()
	assert_bool(GameManager._miser_bonus_pending).is_true()
	# Enter next shop — bonus should be awarded.
	var gold_before: int = GameManager.gold
	GameManager.on_shop_entered()
	assert_int(GameManager.gold - gold_before).is_equal(GameManager.MISER_BONUS_GOLD)
	assert_bool(GameManager._miser_bonus_pending).is_false()
	GameManager.active_modifiers.clear()


func test_miser_no_bonus_over_threshold() -> void:
	GameManager.active_modifiers.clear()
	GameManager.add_modifier(RunModifier.make_miser())
	GameManager._shop_gold_spent = 20
	GameManager.on_shop_exited()
	assert_bool(GameManager._miser_bonus_pending).is_false()
	GameManager.active_modifiers.clear()


# ---------------------------------------------------------------------------
# Gambler's Rush modifier
# ---------------------------------------------------------------------------

func test_gamblers_rush_gold_on_bank() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	GameManager.add_modifier(RunModifier.make_gamblers_rush())
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		GameManager.active_modifiers.clear()
		return
	root.accumulated_stop_count = 3
	root._reroll_count = 1
	for i: int in GameManager.dice_pool.size():
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999
	var gold_before: int = GameManager.gold
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)
	# Score = pool_size, gold from score = pool_size, gambler's rush = +3 (3 stops)
	var gold_gained: int = GameManager.gold - gold_before
	assert_int(gold_gained).is_equal(GameManager.dice_pool.size() + 3)
	GameManager.active_modifiers.clear()


# ---------------------------------------------------------------------------
# ShopItemData modifier factories
# ---------------------------------------------------------------------------

func test_shop_item_buy_modifier() -> void:
	var mod: RunModifier = RunModifier.make_iron_bank()
	var item: ShopItemData = ShopItemData.make_buy_modifier(mod)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_MODIFIER)
	assert_str(item.item_name).is_equal("Iron Bank")
	assert_object(item.modifier).is_not_null()


func test_shop_item_cleanse_curse() -> void:
	var item: ShopItemData = ShopItemData.make_cleanse_curse()
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.CLEANSE_CURSE)
	assert_int(item.cost).is_equal(15)


# ---------------------------------------------------------------------------
# Archetype unlock requirements
# ---------------------------------------------------------------------------

func test_caution_always_unlocked() -> void:
	assert_int(GameManager.ARCHETYPE_UNLOCK_LOOPS[GameManager.Archetype.CAUTION]).is_equal(0)


func test_risk_it_unlock_requires_1_loop() -> void:
	assert_int(GameManager.ARCHETYPE_UNLOCK_LOOPS[GameManager.Archetype.RISK_IT]).is_equal(1)


func test_blank_slate_unlock_requires_3_loops() -> void:
	assert_int(GameManager.ARCHETYPE_UNLOCK_LOOPS[GameManager.Archetype.BLANK_SLATE]).is_equal(3)


# ---------------------------------------------------------------------------
# SaveManager max_loops_completed tracking
# ---------------------------------------------------------------------------

func test_save_manager_tracks_max_loops() -> void:
	SaveManager.max_loops_completed = 0
	var run: Resource = SaveManager.RunSaveDataScript.new()
	run.score = 100
	run.timestamp = "2026-01-01"
	run.stages_cleared = 5
	run.loops_completed = 2
	SaveManager.record_run(run)
	assert_int(SaveManager.max_loops_completed).is_equal(2)
	SaveManager.max_loops_completed = 0
