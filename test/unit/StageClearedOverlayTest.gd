extends GdUnitTestSuite
## Unit tests for the redesigned StageCleared overlay.

const StageClearedScene: PackedScene = preload("res://Scenes/StageCleared.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_setup_stage_title_for_stage_clear() -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 50, 10, false)
	await await_millis(450)
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	assert_str(title_label.text).is_equal("STAGE CLEARED!")
	await _dispose_overlay(overlay)


func test_setup_stage_title_for_loop_clear() -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 50, 10, true)
	await await_millis(450)
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	assert_str(title_label.text).is_equal("LOOP CLEARED!")
	await _dispose_overlay(overlay)


func test_surplus_hidden_when_zero() -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 0, false)
	var surplus_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/SurplusLabel") as Label
	assert_bool(surplus_label.visible).is_false()
	await _dispose_overlay(overlay)


func test_proceed_button_enables_after_intro() -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 5, false)
	await await_millis(900)
	var proceed_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ProceedButton") as Button
	assert_bool(proceed_button.disabled).is_false()
	await _dispose_overlay(overlay)


func test_setup_uses_loop_continue_text_for_loop_clear() -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 5, true)
	await await_millis(900)
	var proceed_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ProceedButton") as Button
	assert_str(proceed_button.text).is_equal("CONTINUE LOOP")
	await _dispose_overlay(overlay)


func test_build_glitch_text_returns_target_at_full_progress() -> void:
	var script: GDScript = load("res://Scripts/StageClearedOverlay.gd") as GDScript
	var result: String = script.build_glitch_text("STAGE CLEARED!", 1.0)
	assert_str(result).is_equal("STAGE CLEARED!")


func test_stage_cleared_overlay_localizes_titles_and_continue_copy() -> void:
	LocalizationManager.set_locale("zh_CN", false)
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("setup", 25, 5, true)
	await await_millis(900)
	var title_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/TitleLabel") as Label
	var proceed_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ProceedButton") as Button
	assert_str(title_label.text).is_equal("轮次完成！")
	assert_str(proceed_button.text).is_equal("继续轮次")
	await _dispose_overlay(overlay)


func _dispose_overlay(overlay: ColorRect) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.queue_free()
	await await_idle_frame()
