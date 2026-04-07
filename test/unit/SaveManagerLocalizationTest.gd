extends GdUnitTestSuite

var _saved_preferred_locale: String = ""


func before_test() -> void:
	_saved_preferred_locale = SaveManager.get_preferred_locale()
	SaveManager.preferred_locale = ""


func after_test() -> void:
	SaveManager.preferred_locale = _saved_preferred_locale


func test_set_preferred_locale_updates_getter() -> void:
	SaveManager.set_preferred_locale("ja")
	assert_str(SaveManager.get_preferred_locale()).is_equal("ja")


func test_clear_preferred_locale_resets_to_empty_string() -> void:
	SaveManager.set_preferred_locale("pt_BR")
	SaveManager.clear_preferred_locale()
	assert_str(SaveManager.get_preferred_locale()).is_equal("")