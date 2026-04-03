class_name PrestigePanel
extends PanelContainer
## Permanent unlock shop purchased with skull currency.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")
const PrestigeUnlockDataScript: GDScript = preload("res://Scripts/PrestigeUnlockData.gd")

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _currency_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CurrencyLabel
@onready var _cards_container: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/CardsContainer
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/CloseButton


func _ready() -> void:
	_apply_theme_styling()
	_close_button.pressed.connect(_on_close_pressed)
	SaveManager.prestige_currency_changed.connect(_on_currency_changed)
	_rebuild_cards()


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.ACTION_CYAN, 2)
	)

	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_currency_label.add_theme_font_override("font", _UITheme.font_stats())
	_currency_label.add_theme_font_size_override("font_size", 18)
	_currency_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)

	_close_button.add_theme_font_override("font", _UITheme.font_display())
	_close_button.add_theme_font_size_override("font_size", 13)


func _on_currency_changed(_new_total: int) -> void:
	_rebuild_cards()


func _rebuild_cards() -> void:
	_currency_label.text = "Skulls: %d" % SaveManager.prestige_currency
	for child: Node in _cards_container.get_children():
		child.queue_free()
	for unlock: Resource in PrestigeUnlockDataScript.get_all():
		_cards_container.add_child(_build_unlock_card(unlock))


func _build_unlock_card(unlock: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 160)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.ACTION_CYAN, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var name_label := Label.new()
	name_label.text = unlock.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	root.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = unlock.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", _UITheme.font_body())
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	root.add_child(desc_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)

	var cost_label := Label.new()
	cost_label.text = "%d skulls" % unlock.skull_cost
	cost_label.add_theme_font_override("font", _UITheme.font_stats())
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	footer.add_child(cost_label)

	var button := Button.new()
	var owned: bool = SaveManager.has_prestige_unlock(unlock.unlock_id)
	if owned:
		button.text = "Owned"
		button.disabled = true
	else:
		button.text = "Buy"
		button.disabled = SaveManager.prestige_currency < unlock.skull_cost
		button.pressed.connect(func() -> void:
			if SaveManager.purchase_prestige_unlock(unlock.unlock_id):
				_rebuild_cards()
		)
	button.add_theme_font_override("font", _UITheme.font_display())
	button.add_theme_font_size_override("font_size", 12)
	footer.add_child(button)

	return card


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
