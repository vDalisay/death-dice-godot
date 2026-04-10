extends GdUnitTestSuite

const LocalizationManagerScript: GDScript = preload("res://Scripts/LocalizationManager.gd")

var _manager: Node = null


func before_test() -> void:
	_manager = auto_free(LocalizationManagerScript.new()) as LocalizationManager


func test_normalize_locale_maps_steam_codes_and_regions() -> void:
	assert_str(_manager.normalize_locale("schinese")).is_equal("zh_CN")
	assert_str(_manager.normalize_locale("tchinese")).is_equal("zh_TW")
	assert_str(_manager.normalize_locale("pt-br")).is_equal("pt_BR")
	assert_str(_manager.normalize_locale("ES-419")).is_equal("es_419")
	assert_str(_manager.normalize_locale("fr-ca")).is_equal("fr_CA")


func test_find_supported_locale_falls_back_to_language_code() -> void:
	var supported_locales: PackedStringArray = PackedStringArray(["en", "fr", "pt_BR", "zh_CN"])
	assert_str(_manager.find_supported_locale("fr_CA", supported_locales)).is_equal("fr")
	assert_str(_manager.find_supported_locale("pt_BR", supported_locales)).is_equal("pt_BR")
	assert_str(_manager.find_supported_locale("zh-Hans", supported_locales)).is_equal("zh_CN")


func test_resolve_initial_locale_uses_saved_user_preference_when_present() -> void:
	var supported_locales: PackedStringArray = PackedStringArray(["en", "fr", "de"])
	var resolved_locale: String = _manager.resolve_initial_locale("fr", supported_locales)
	assert_str(resolved_locale).is_equal("fr")


func test_resolve_initial_locale_defaults_to_english_when_no_saved_preference_exists() -> void:
	var supported_locales: PackedStringArray = PackedStringArray(["en", "de", "ja"])
	var resolved_locale: String = _manager.resolve_initial_locale("", supported_locales)
	assert_str(resolved_locale).is_equal("en")


func test_resolve_initial_locale_falls_back_to_default_when_saved_preference_is_unsupported() -> void:
	var supported_locales: PackedStringArray = PackedStringArray(["en", "fr"])
	var resolved_locale: String = _manager.resolve_initial_locale("pl_PL", supported_locales)
	assert_str(resolved_locale).is_equal("en")