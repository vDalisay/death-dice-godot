extends GdUnitTestSuite
## Unit tests for ArchetypePicker presentation and card generation.

const PickerScene: PackedScene = preload("res://Scenes/ArchetypePicker.tscn")

var _saved_chosen_archetype: int = 0


func before_test() -> void:
	_saved_chosen_archetype = int(GameManager.chosen_archetype)
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION


func after_test() -> void:
	GameManager.chosen_archetype = _saved_chosen_archetype as GameManager.Archetype


func test_picker_rebuilds_five_archetype_cards() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	assert_int((picker.get_node("CenterContainer/Card/MarginContainer/Content/ArchetypeRow") as HBoxContainer).get_child_count()).is_equal(5)


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
	assert_int(row.get_child_count()).is_equal(5)
	for child: Node in row.get_children():
		var card: PanelContainer = child as PanelContainer
		assert_object(card).is_not_null()
		assert_float(card.modulate.a).is_equal(1.0)


func test_open_with_continue_shows_continue_button() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	picker.call("open", int(GameManager.RunMode.CLASSIC), true)
	var continue_button: Button = picker.get("_continue_button") as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.visible).is_true()


func test_seed_toggle_enables_and_clears_seed_input() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	var seed_input: LineEdit = picker.get("_seed_input") as LineEdit
	assert_object(seed_input).is_not_null()
	assert_bool(seed_input.editable).is_false()
	picker.call("_on_seed_toggled", true)
	assert_bool(seed_input.editable).is_true()
	seed_input.text = "abc"
	picker.call("_on_seed_toggled", false)
	assert_bool(seed_input.editable).is_false()
	assert_str(seed_input.text).is_equal("")


func test_continue_button_press_locks_interaction_for_continue_path() -> void:
	var picker: ColorRect = auto_free(PickerScene.instantiate()) as ColorRect
	add_child(picker)
	await await_idle_frame()
	picker.call("open", int(GameManager.RunMode.CLASSIC), true)
	var continue_button: Button = picker.get("_continue_button") as Button
	continue_button.pressed.emit()
	assert_bool(bool(picker.get("_interaction_locked"))).is_true()
