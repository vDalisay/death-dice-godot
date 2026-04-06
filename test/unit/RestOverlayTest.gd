extends GdUnitTestSuite
## Unit tests for the rest result overlay.

const RestOverlayScene: PackedScene = preload("res://Scenes/RestOverlay.tscn")


func test_rest_overlay_setup_reports_hand_and_gold_changes() -> void:
	var overlay: ColorRect = RestOverlayScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("open", 1, 10, 1, 2)
	await await_millis(260)
	var summary_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/SummaryLabel") as Label
	var detail_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/DetailLabel") as Label
	var continue_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ContinueButton") as Button
	assert_str(summary_label.text).contains("10g")
	assert_str(detail_label.text).contains("1 -> 2")
	assert_bool(continue_button.disabled).is_false()
	overlay.queue_free()
	await await_idle_frame()


func test_rest_overlay_reports_capped_healing() -> void:
	var overlay: ColorRect = RestOverlayScene.instantiate() as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("open", 1, 10, 3, 3)
	await await_millis(260)
	var summary_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/SummaryLabel") as Label
	assert_str(summary_label.text).contains("No hand recovered")
	overlay.queue_free()
	await await_idle_frame()