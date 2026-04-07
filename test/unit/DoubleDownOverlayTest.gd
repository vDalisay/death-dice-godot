extends GdUnitTestSuite
## Unit tests for themed Double Down overlay behavior.

const DoubleDownScene: PackedScene = preload("res://Scenes/DoubleDownOverlay.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_open_shows_overlay_and_buttons() -> void:
	var overlay: DoubleDownOverlay = auto_free(DoubleDownScene.instantiate()) as DoubleDownOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open(30)
	var even_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/EvenButton") as Button
	var odd_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/OddButton") as Button
	assert_bool(overlay.visible).is_true()
	assert_bool(even_button.visible).is_true()
	assert_bool(odd_button.visible).is_true()


func test_open_updates_wager_prompt() -> void:
	var overlay: DoubleDownOverlay = auto_free(DoubleDownScene.instantiate()) as DoubleDownOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open(42)
	var prompt_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/PromptLabel") as Label
	assert_str(prompt_label.text).contains("42")


func test_close_button_hidden_on_open() -> void:
	var overlay: DoubleDownOverlay = auto_free(DoubleDownScene.instantiate()) as DoubleDownOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open(12)
	var close_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton") as Button
	assert_bool(close_button.visible).is_false()


func test_loss_shake_uses_rotation_not_position() -> void:
	var overlay: DoubleDownOverlay = auto_free(DoubleDownScene.instantiate()) as DoubleDownOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open(20)
	await await_idle_frame()
	var modal: PanelContainer = overlay.get_node("CenterContainer/Modal") as PanelContainer
	var pos_before: Vector2 = modal.position
	overlay.call("_play_loss_shake")
	await await_idle_frame()
	# Modal position should stay unchanged (no position-based shaking).
	assert_vector(modal.position).is_equal(pos_before)
	# Pivot should be set to center of modal for proper rotation.
	assert_vector(modal.pivot_offset).is_equal(modal.size * 0.5)


func test_double_down_overlay_localizes_buttons_and_prompt() -> void:
	LocalizationManager.set_locale("zh_CN", false)
	var overlay: DoubleDownOverlay = auto_free(DoubleDownScene.instantiate()) as DoubleDownOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open(30)
	var prompt_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/PromptLabel") as Label
	var even_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/EvenButton") as Button
	var odd_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ButtonRow/OddButton") as Button
	assert_str(prompt_label.text).contains("押注")
	assert_str(even_button.text).is_equal("双数")
	assert_str(odd_button.text).is_equal("单数")
