class_name PauseMenu
extends Control

signal resume_requested()
signal settings_requested()
signal quit_requested()

const _UITheme := preload("res://Scripts/UITheme.gd")

const TITLE_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 18

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _resume_button: Button = $CenterContainer/Card/MarginContainer/Content/ResumeButton
@onready var _settings_button: Button = $CenterContainer/Card/MarginContainer/Content/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Card/MarginContainer/Content/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_theme()
	refresh_text()


func open_panel() -> void:
	visible = true
	_resume_button.grab_focus()


func close_panel() -> void:
	visible = false


func refresh_text() -> void:
	_title_label.text = _translate_or_fallback("PAUSED_TITLE", "Paused")
	_resume_button.text = _translate_or_fallback("RESUME_ACTION", "Resume")
	_settings_button.text = tr("SETTINGS")
	_quit_button.text = _translate_or_fallback("QUIT_ACTION", "Quit")


func _translate_or_fallback(key: String, fallback: String) -> String:
	var translated: String = tr(key)
	if translated == key:
		return fallback
	return translated


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	resume_requested.emit()


func _apply_theme() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_UITheme.apply_modal_panel_style(_card, _UITheme.SCORE_GOLD)
	_UITheme.apply_label_style(_title_label, _UITheme.font_display(), TITLE_FONT_SIZE, _UITheme.SCORE_GOLD)
	for button: Button in [_resume_button, _settings_button, _quit_button]:
		_UITheme.apply_label_style(button, _UITheme.font_display(), BUTTON_FONT_SIZE, _UITheme.BRIGHT_TEXT)


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _on_locale_changed(_new_locale: String) -> void:
	refresh_text()