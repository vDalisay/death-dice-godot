extends GdUnitTestSuite

const EvenOddScene: PackedScene = preload("res://Scenes/EvenOddBetOverlay.tscn")
const HeatScene: PackedScene = preload("res://Scenes/HeatBetOverlay.tscn")
const InsuranceScene: PackedScene = preload("res://Scenes/InsuranceBetOverlay.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("zh_CN", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_even_odd_overlay_localizes_open_state() -> void:
	var overlay: EvenOddBetOverlay = auto_free(EvenOddScene.instantiate()) as EvenOddBetOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open()
	var info_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/InfoLabel") as Label
	var confirm_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ConfirmButton") as Button
	assert_str(info_label.text).contains("结算时")
	assert_str(confirm_button.text).is_equal("确认押注")


func test_heat_overlay_localizes_open_state() -> void:
	GameManager.gold = 100
	var overlay: HeatBetOverlay = auto_free(HeatScene.instantiate()) as HeatBetOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open()
	var picked_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/PickedLabel") as Label
	var confirm_button: Button = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ConfirmButton") as Button
	assert_str(picked_label.text).contains("选择")
	assert_str(confirm_button.text).contains("确认押注")


func test_insurance_overlay_localizes_open_state() -> void:
	var overlay: InsuranceBetOverlay = auto_free(InsuranceScene.instantiate()) as InsuranceBetOverlay
	add_child(overlay)
	await await_idle_frame()
	overlay.open()
	var info_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/InfoLabel") as Label
	var odds_label: Label = overlay.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/OddsLabel") as Label
	assert_str(info_label.text).contains("现在支付")
	assert_str(odds_label.text).is_equal("仅覆盖本关。结算或爆点后失效。")