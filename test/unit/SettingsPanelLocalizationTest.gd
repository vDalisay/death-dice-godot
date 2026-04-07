extends GdUnitTestSuite

const SettingsPanelScene: PackedScene = preload("res://Scenes/SettingsPanel.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_panel_refreshes_labels_after_locale_switch() -> void:
	var panel: Node = auto_free(SettingsPanelScene.instantiate()) as Node
	add_child(panel)
	await await_idle_frame()
	LocalizationManager.set_locale("zh_CN", false)
	await await_idle_frame()
	assert_str((panel.get("_title_label") as Label).text).is_equal("设置")
	assert_str((panel.get("_language_label") as Label).text).is_equal("语言")
	assert_str((panel.get("_close_button") as Button).text).is_equal("关闭")


func test_language_dropdown_tracks_and_updates_locale() -> void:
	var panel: Node = auto_free(SettingsPanelScene.instantiate()) as Node
	add_child(panel)
	await await_idle_frame()
	var option_button: OptionButton = panel.get("_language_option") as OptionButton
	assert_int(option_button.selected).is_equal(0)
	panel.call("_on_language_selected", 1)
	await await_idle_frame()
	assert_str(LocalizationManager.get_current_locale()).is_equal("zh_CN")
	assert_int(option_button.selected).is_equal(1)