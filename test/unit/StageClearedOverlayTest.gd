extends GdUnitTestSuite
## Unit tests for the redesigned StageCleared overlay.

const StageClearedScene: PackedScene = preload("res://Scenes/StageCleared.tscn")


func test_setup_stage_title_for_stage_clear() -> void:
	var overlay: ColorRect = auto_free(StageClearedScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 50, 10, false)
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	assert_str(title_label.text).is_equal("STAGE CLEARED!")


func test_setup_stage_title_for_loop_clear() -> void:
	var overlay: ColorRect = auto_free(StageClearedScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 50, 10, true)
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	assert_str(title_label.text).is_equal("LOOP CLEARED!")


func test_surplus_hidden_when_zero() -> void:
	var overlay: ColorRect = auto_free(StageClearedScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 0, false)
	var surplus_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/SurplusLabel") as Label
	assert_bool(surplus_label.visible).is_false()


func test_proceed_button_enables_after_intro() -> void:
	var overlay: ColorRect = auto_free(StageClearedScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 5, false)
	await await_millis(900)
	var proceed_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ProceedButton") as Button
	assert_bool(proceed_button.disabled).is_false()
