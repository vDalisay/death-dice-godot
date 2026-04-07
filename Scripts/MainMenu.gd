class_name MainMenu
extends Control

const GAME_SCENE_PATH: String = "res://Scenes/Main.tscn"
const _UITheme := preload("res://Scripts/UITheme.gd")

const TITLE_FONT_SIZE: int = 48
const BODY_FONT_SIZE: int = 16
const BUTTON_FONT_SIZE: int = 18

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _status_label: Label = $CenterContainer/Card/MarginContainer/Content/StatusLabel
@onready var _play_button: Button = $CenterContainer/Card/MarginContainer/Content/ButtonColumn/PlayButton
@onready var _codex_button: Button = $CenterContainer/Card/MarginContainer/Content/ButtonColumn/CodexButton
@onready var _career_button: Button = $CenterContainer/Card/MarginContainer/Content/ButtonColumn/CareerButton
@onready var _settings_button: Button = $CenterContainer/Card/MarginContainer/Content/ButtonColumn/SettingsButton
@onready var _career_panel: CareerPanel = $CareerPanel
@onready var _codex_panel: DiceCodexPanel = $DiceCodexPanel
@onready var _settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	theme = _UITheme.build_theme()
	_play_button.pressed.connect(_on_play_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_career_button.pressed.connect(_on_career_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_career_panel.closed.connect(_on_overlay_closed)
	_codex_panel.closed.connect(_on_overlay_closed)
	_settings_panel.closed.connect(_on_overlay_closed)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_theme()
	_refresh_text()


func _apply_theme() -> void:
	_UITheme.apply_modal_panel_style(_card, _UITheme.ACTION_CYAN)
	_UITheme.apply_label_style(_title_label, _UITheme.font_display(), TITLE_FONT_SIZE, _UITheme.ACTION_CYAN)
	_UITheme.apply_label_style(_status_label, _UITheme.font_body(), BODY_FONT_SIZE, _UITheme.MUTED_TEXT)
	for button: Button in [_play_button, _codex_button, _career_button, _settings_button]:
		_UITheme.apply_label_style(button, _UITheme.font_display(), BUTTON_FONT_SIZE, _UITheme.BRIGHT_TEXT)


func _refresh_text() -> void:
	_title_label.text = _translate_or_fallback("MAIN_MENU_TITLE", "Death Dice")
	_status_label.text = _translate_or_fallback("MAIN_MENU_STATUS_READY", "Start a fresh run or jump back into your current one.")
	_play_button.text = _translate_or_fallback("PLAY_ACTION", "Play")
	_codex_button.text = tr("CODEX")
	_career_button.text = tr("CAREER")
	_settings_button.text = tr("SETTINGS")


func _translate_or_fallback(key: String, fallback: String) -> String:
	var translated: String = tr(key)
	if translated == key:
		return fallback
	return translated


func _on_play_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_codex_pressed() -> void:
	_codex_panel.open_panel()


func _on_career_pressed() -> void:
	_career_panel.open_panel()


func _on_settings_pressed() -> void:
	_settings_panel.open_panel()


func _on_overlay_closed() -> void:
	_play_button.grab_focus()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_text()