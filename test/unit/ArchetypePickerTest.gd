extends GdUnitTestSuite
## Unit tests for ArchetypePicker presentation and card generation.

const PickerScene: PackedScene = preload("res://Scenes/ArchetypePicker.tscn")


func test_picker_rebuilds_three_archetype_cards() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	assert_int((picker.get_node("CenterContainer/Card/MarginContainer/Content/ArchetypeRow") as HBoxContainer).get_child_count()).is_equal(3)


func test_open_keeps_selected_mode_buttons_available() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	picker.call("open", int(GameManager.RunMode.GAUNTLET))
	var classic_button: Button = picker.get_node("CenterContainer/Card/MarginContainer/Content/ModeRow/ClassicButton") as Button
	var gauntlet_button: Button = picker.get_node("CenterContainer/Card/MarginContainer/Content/ModeRow/GauntletButton") as Button
	assert_object(classic_button).is_not_null()
	assert_object(gauntlet_button).is_not_null()
	assert_bool(gauntlet_button.modulate.r > classic_button.modulate.r).is_true()


func test_closing_prestige_restores_visible_archetype_cards() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	picker.call("_open_prestige_panel")
	await await_idle_frame()
	var prestige_panel: Node = picker.get_child(picker.get_child_count() - 1)
	prestige_panel.call("_on_close_pressed")
	await await_millis(220)
	var row: HBoxContainer = picker.get_node("CenterContainer/Card/MarginContainer/Content/ArchetypeRow") as HBoxContainer
	assert_int(row.get_child_count()).is_equal(3)
	for child: Node in row.get_children():
		var card: PanelContainer = child as PanelContainer
		assert_object(card).is_not_null()
		assert_float(card.modulate.a).is_equal(1.0)
