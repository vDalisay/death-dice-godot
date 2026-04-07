extends GdUnitTestSuite

const CareerPanelScene: PackedScene = preload("res://Scenes/CareerPanel.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_panel_refreshes_labels_after_locale_switch() -> void:
	var panel: CareerPanel = auto_free(CareerPanelScene.instantiate()) as CareerPanel
	add_child(panel)
	await await_idle_frame()
	LocalizationManager.set_locale("zh_CN", false)
	await await_idle_frame()
	assert_str(panel._title_label.text).is_equal("生涯统计")
	assert_str(panel._close_button.text).is_equal("关闭")
	assert_str(panel._achievements_header.text).is_equal("成就")