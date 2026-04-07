class_name HighlightsReelTest
extends GdUnitTestSuite
## Tests for the Highlights Reel feature: end-of-run summary with career
## best comparisons.

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_format_stat_new_best() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_stat("Score", 100, 50)
	assert_str(result).contains("NEW BEST!")
	assert_str(result).contains("100")
	panel.free()


func test_format_stat_not_best() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_stat("Score", 30, 100)
	assert_str(result).contains("(Best: 100)")
	assert_str(result).contains("30")
	assert_str(result).not_contains("NEW BEST!")
	panel.free()


func test_format_stat_ties_career_best() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_stat("Score", 100, 100)
	assert_str(result).contains("NEW BEST!")
	panel.free()


func test_format_stat_zero_not_best() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_stat("Score", 0, 0)
	assert_str(result).not_contains("NEW BEST!")
	panel.free()


func test_format_delta_positive() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_delta(120, 100)
	assert_str(result).contains("+20")
	panel.free()


func test_format_delta_tie() -> void:
	var panel_script: GDScript = preload("res://Scripts/HighlightsPanel.gd")
	var panel: HighlightsPanel = panel_script.new()
	var result: String = panel._format_delta(100, 100)
	assert_str(result).contains("Tied best")
	panel.free()
