extends Node
## Central locale selection and runtime switching.

const SteamIntegrationScript: GDScript = preload("res://Scripts/SteamIntegration.gd")

const DEFAULT_LOCALE: String = "en"
const LOCALE_DISPLAY_NAMES: Dictionary = {
	"en": "English",
	"zh_CN": "简体中文",
}
var SUPPORTED_LOCALES: PackedStringArray = PackedStringArray(["en", "zh_CN"])

signal locale_changed(new_locale: String)

var current_locale: String = DEFAULT_LOCALE


func _ready() -> void:
	apply_startup_locale()


func apply_startup_locale() -> String:
	var saved_locale: String = SaveManager.get_preferred_locale()
	var resolved_locale: String = resolve_initial_locale(
		saved_locale,
		SteamIntegrationScript.get_current_game_language_api_code(),
		OS.get_locale(),
		SUPPORTED_LOCALES
	)
	_apply_locale(resolved_locale, false)
	return current_locale


func get_current_locale() -> String:
	return current_locale


func get_default_locale() -> String:
	return DEFAULT_LOCALE


func get_supported_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES


func get_supported_locale_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for locale_code: String in SUPPORTED_LOCALES:
		options.append({
			"code": locale_code,
			"label": str(LOCALE_DISPLAY_NAMES.get(locale_code, locale_code)),
		})
	return options


func set_locale(locale_code: String, persist: bool = true) -> String:
	var resolved_locale: String = find_supported_locale(locale_code, SUPPORTED_LOCALES)
	if resolved_locale.is_empty():
		resolved_locale = _resolve_default_locale(SUPPORTED_LOCALES)
	_apply_locale(resolved_locale, persist)
	return current_locale


func clear_preferred_locale() -> String:
	SaveManager.clear_preferred_locale()
	return apply_startup_locale()


func resolve_initial_locale(
	saved_locale: String,
	_steam_api_language: String,
	_os_locale: String,
	supported_locales: PackedStringArray = SUPPORTED_LOCALES
) -> String:
	var resolved_saved_locale: String = find_supported_locale(saved_locale, supported_locales)
	if not resolved_saved_locale.is_empty():
		return resolved_saved_locale

	return _resolve_default_locale(supported_locales)


func find_supported_locale(
	locale_code: String,
	supported_locales: PackedStringArray = SUPPORTED_LOCALES
) -> String:
	var normalized_locale: String = normalize_locale(locale_code)
	if normalized_locale.is_empty():
		return ""
	if supported_locales.has(normalized_locale):
		return normalized_locale

	var language_code: String = normalized_locale.get_slice("_", 0)
	if supported_locales.has(language_code):
		return language_code

	match normalized_locale:
		"zh_SG", "zh_HANS", "zh_HANS_CN":
			if supported_locales.has("zh_CN"):
				return "zh_CN"
		"zh_HK", "zh_HANT", "zh_HANT_TW":
			if supported_locales.has("zh_TW"):
				return "zh_TW"

	return ""


func normalize_locale(locale_code: String) -> String:
	var normalized_locale: String = locale_code.strip_edges().replace("-", "_")
	if normalized_locale.is_empty():
		return ""

	var lowered_locale: String = normalized_locale.to_lower()
	match lowered_locale:
		"schinese", "zh_cn", "zh_hans", "zh_hans_cn", "chinese_simplified":
			return "zh_CN"
		"tchinese", "zh_tw", "zh_hant", "zh_hant_tw", "chinese_traditional":
			return "zh_TW"
		"brazilian", "pt_br":
			return "pt_BR"
		"latam", "es_419":
			return "es_419"
		"koreana":
			return "ko"

	var locale_parts: PackedStringArray = lowered_locale.split("_", false)
	if locale_parts.is_empty():
		return ""
	if locale_parts.size() == 1:
		return locale_parts[0]
	return "%s_%s" % [locale_parts[0], locale_parts[1].to_upper()]


func _apply_locale(locale_code: String, persist: bool) -> void:
	var target_locale: String = find_supported_locale(locale_code, SUPPORTED_LOCALES)
	if target_locale.is_empty():
		target_locale = _resolve_default_locale(SUPPORTED_LOCALES)

	var locale_changed_required: bool = current_locale != target_locale or TranslationServer.get_locale() != target_locale
	current_locale = target_locale
	TranslationServer.set_locale(target_locale)
	if persist:
		SaveManager.set_preferred_locale(target_locale)
	if locale_changed_required:
		locale_changed.emit(target_locale)


func _resolve_default_locale(supported_locales: PackedStringArray) -> String:
	if supported_locales.has(DEFAULT_LOCALE):
		return DEFAULT_LOCALE
	if not supported_locales.is_empty():
		return supported_locales[0]
	return DEFAULT_LOCALE