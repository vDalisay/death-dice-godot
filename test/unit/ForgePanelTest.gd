extends GdUnitTestSuite
## UI behavior tests for the redesigned ForgePanel modal.

const ForgeScene: PackedScene = preload("res://Scenes/ForgePanel.tscn")


func before_test() -> void:
	GameManager.dice_pool.clear()


func after_test() -> void:
	GameManager.dice_pool.clear()


func test_open_populates_dice_flow_and_disables_forge_initially() -> void:
	_seed_pool([
		DiceData.make_standard_d6(),
		DiceData.make_lucky_d6(),
		DiceData.make_heavy_d6(),
		DiceData.make_blank_canvas_d6(),
	])
	var panel: ForgePanel = auto_free(ForgeScene.instantiate()) as ForgePanel
	add_child(panel)
	await await_idle_frame()
	panel.open()
	assert_bool(panel.visible).is_true()
	assert_bool(panel._forge_button.disabled).is_true()
	var flow: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/DiceFlow") as HFlowContainer
	assert_int(flow.get_child_count()).is_equal(4)


func test_two_valid_selections_enable_forge_button() -> void:
	_seed_pool([
		DiceData.make_standard_d6(),
		DiceData.make_lucky_d6(),
		DiceData.make_heavy_d6(),
		DiceData.make_blank_canvas_d6(),
	])
	var panel: ForgePanel = auto_free(ForgeScene.instantiate()) as ForgePanel
	add_child(panel)
	await await_idle_frame()
	panel.open()
	panel._toggle_die(0)
	panel._toggle_die(1)
	assert_bool(panel._forge_button.disabled).is_false()


func test_two_epic_selections_show_block_message() -> void:
	_seed_pool([
		DiceData.make_golden_d6(),
		DiceData.make_explosive_d6(),
		DiceData.make_standard_d6(),
		DiceData.make_lucky_d6(),
	])
	# Ensure first two are Epic for deterministic test.
	GameManager.dice_pool[0].rarity = DiceData.Rarity.PURPLE
	GameManager.dice_pool[1].rarity = DiceData.Rarity.PURPLE

	var panel: ForgePanel = auto_free(ForgeScene.instantiate()) as ForgePanel
	add_child(panel)
	await await_idle_frame()
	panel.open()
	panel._toggle_die(0)
	panel._toggle_die(1)
	assert_bool(panel._forge_button.disabled).is_true()
	assert_bool(panel._result_card.visible).is_true()
	assert_str(panel._result_label.text).contains("Cannot forge two Epic dice")


func _seed_pool(dice: Array[DiceData]) -> void:
	GameManager.dice_pool.clear()
	for die: DiceData in dice:
		GameManager.dice_pool.append(die)
