class_name SettingsPanel
extends PanelContainer

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")

const TITLE_FONT_SIZE: int = 20
const BODY_FONT_SIZE: int = 15
const LANGUAGE_LABEL_FONT_SIZE: int = 15
const LANGUAGE_OPTION_FONT_SIZE: int = 14
const CLOSE_BUTTON_FONT_SIZE: int = 14

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _description_label: Label = $CenterContainer/Card/MarginContainer/Content/DescriptionLabel
@onready var _language_label: Label = $CenterContainer/Card/MarginContainer/Content/LanguageRow/LanguageLabel
@onready var _language_option: OptionButton = $CenterContainer/Card/MarginContainer/Content/LanguageRow/LanguageOption
@onready var _close_button: Button = $CenterContainer/Card/MarginContainer/Content/CloseButton

var _is_syncing_language_option: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_language_option.item_selected.connect(_on_language_selected)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_theme()
	_populate_language_options()
	_refresh_localized_labels()


func open_panel() -> void:
	_sync_language_option_selection()
	visible = true
	_close_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_close_pressed() -> void:
	close_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close_panel()


func _apply_theme() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_UITheme.apply_modal_panel_style(_card, _UITheme.ACTION_CYAN)
	_UITheme.apply_label_style(_title_label, _UITheme.font_display(), TITLE_FONT_SIZE, _UITheme.ACTION_CYAN)
	_UITheme.apply_label_style(_description_label, _UITheme.font_body(), BODY_FONT_SIZE, _UITheme.MUTED_TEXT)
	_UITheme.apply_label_style(_language_label, _UITheme.font_stats(), LANGUAGE_LABEL_FONT_SIZE, _UITheme.BRIGHT_TEXT)
	_UITheme.apply_label_style(_language_option, _UITheme.font_stats(), LANGUAGE_OPTION_FONT_SIZE, _UITheme.BRIGHT_TEXT)
	_UITheme.apply_label_style(_close_button, _UITheme.font_display(), CLOSE_BUTTON_FONT_SIZE, _UITheme.BRIGHT_TEXT)
	_language_option.add_theme_stylebox_override(
		"normal",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, _UITheme.ACTION_CYAN, 1)
	)
	_language_option.add_theme_stylebox_override(
		"hover",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, _UITheme.SCORE_GOLD, 1)
	)
	_language_option.add_theme_stylebox_override(
		"pressed",
		_UITheme.make_panel_stylebox(_UITheme.SURFACE_DIGITAL, _UITheme.CORNER_RADIUS_BADGE, _UITheme.SCORE_GOLD, 1)
	)
	_language_option.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	_language_option.add_theme_color_override("font_hover_color", _UITheme.BRIGHT_TEXT)
	_language_option.add_theme_color_override("font_pressed_color", _UITheme.BRIGHT_TEXT)
	_language_option.add_theme_color_override("font_focus_color", _UITheme.BRIGHT_TEXT)


func _populate_language_options() -> void:
	_is_syncing_language_option = true
	_language_option.clear()
	for locale_option: Dictionary in LocalizationManager.get_supported_locale_options():
		_language_option.add_item(str(locale_option.get("label", "")))
		var item_index: int = _language_option.item_count - 1
		_language_option.set_item_metadata(item_index, str(locale_option.get("code", "en")))
	_sync_language_option_selection()
	_is_syncing_language_option = false


func _sync_language_option_selection() -> void:
	var current_locale: String = LocalizationManager.get_current_locale() if LocalizationManager != null else "en"
	for index: int in _language_option.item_count:
		if str(_language_option.get_item_metadata(index)) != current_locale:
			continue
		_language_option.select(index)
		return
	if _language_option.item_count > 0:
		_language_option.select(0)


func _refresh_localized_labels() -> void:
	_title_label.text = tr("SETTINGS")
	_description_label.text = tr("SETTINGS_HELP_TEXT")
	_language_label.text = tr("LANGUAGE_LABEL")
	_close_button.text = tr("CLOSE_ACTION")
	_sync_language_option_selection()


func _on_language_selected(index: int) -> void:
	if _is_syncing_language_option:
		return
	var locale_code: String = str(_language_option.get_item_metadata(index))
	if LocalizationManager != null:
		LocalizationManager.set_locale(locale_code)


func _on_locale_changed(_new_locale: String) -> void:
	_is_syncing_language_option = true
	_sync_language_option_selection()
	_is_syncing_language_option = false
	_refresh_localized_labels()