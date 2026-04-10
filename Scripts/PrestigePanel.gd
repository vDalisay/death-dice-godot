class_name PrestigePanel
extends PanelContainer
## Permanent unlock shop purchased with skull currency.

signal closed()

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const PrestigeUnlockDataScript: GDScript = preload("res://Scripts/PrestigeUnlockData.gd")
const PermanentUpgradeDataScript: GDScript = preload("res://Scripts/PermanentUpgradeData.gd")
const PermanentUpgradeDataType: GDScript = preload("res://Scripts/PermanentUpgradeData.gd")

@onready var _backdrop: ColorRect = $Backdrop
@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _currency_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CurrencyLabel
@onready var _meta_currency_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/MetaCurrencyLabel
@onready var _cards_container: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/SectionsVBox/PrestigeCardsContainer
@onready var _upgrade_cards_container: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/SectionsVBox/UpgradeCardsContainer
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/CloseButton

var _transition_tween: Tween = null
var _is_closing: bool = false


func _exit_tree() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.custom_step(99.0)
		_transition_tween = null


func _ready() -> void:
	_apply_theme_styling()
	_close_button.pressed.connect(_on_close_pressed)
	SaveManager.prestige_currency_changed.connect(_on_currency_changed)
	SaveManager.experience_currency_changed.connect(_on_currency_changed)
	SaveManager.stop_shard_currency_changed.connect(_on_currency_changed)
	_rebuild_cards()
	_play_open_transition()


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_backdrop.color = Color(_UITheme.STAGE_FAMILY_BACKDROP_COLOR, _UITheme.STAGE_FAMILY_BACKDROP_ALPHA)
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)

	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_title_label.text = "META LAB"

	_currency_label.add_theme_font_override("font", _UITheme.font_stats())
	_currency_label.add_theme_font_size_override("font_size", 18)
	_currency_label.add_theme_color_override("font_color", _UITheme.STAGE_MAP_GLOW_CURRENT_ROW)

	_meta_currency_label.add_theme_font_override("font", _UITheme.font_stats())
	_meta_currency_label.add_theme_font_size_override("font_size", 18)
	_meta_currency_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)

	_close_button.add_theme_font_override("font", _UITheme.font_display())
	_close_button.add_theme_font_size_override("font_size", 13)


func _on_currency_changed(_new_total: int) -> void:
	_rebuild_cards()


func _rebuild_cards() -> void:
	_currency_label.text = "Skulls: %d" % SaveManager.prestige_currency
	_meta_currency_label.text = "EXP %d  |  Shards %d" % [SaveManager.experience_currency, SaveManager.stop_shard_currency]
	for child: Node in _cards_container.get_children():
		child.queue_free()
	for child: Node in _upgrade_cards_container.get_children():
		child.queue_free()
	for unlock: Resource in PrestigeUnlockDataScript.get_all():
		_cards_container.add_child(_build_unlock_card(unlock))
	for upgrade: PermanentUpgradeDataType in PermanentUpgradeDataScript.get_all():
		_upgrade_cards_container.add_child(_build_upgrade_card(upgrade))


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


func _build_upgrade_card(upgrade: PermanentUpgradeDataType) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 176)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(Color("#15281F"), _UITheme.CORNER_RADIUS_CARD, _UITheme.SUCCESS_GREEN, 1)
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
	name_label.name = "UpgradeNameLabel"
	name_label.text = upgrade.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	root.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade.description
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
	cost_label.name = "UpgradeCostLabel"
	cost_label.text = "%d EXP | %d Shards" % [upgrade.exp_cost, upgrade.stop_shard_cost]
	cost_label.add_theme_font_override("font", _UITheme.font_stats())
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", _UITheme.SUCCESS_GREEN)
	footer.add_child(cost_label)

	var button := Button.new()
	button.name = "UpgradeBuyButton"
	var owned: bool = SaveManager.has_permanent_upgrade(upgrade.upgrade_id)
	if owned:
		button.text = "Owned"
		button.disabled = true
	else:
		button.text = "Unlock"
		button.disabled = SaveManager.experience_currency < upgrade.exp_cost or SaveManager.stop_shard_currency < upgrade.stop_shard_cost
		button.pressed.connect(func() -> void:
			if SaveManager.purchase_permanent_upgrade(upgrade.upgrade_id, upgrade.exp_cost, upgrade.stop_shard_cost):
				_rebuild_cards()
		)
	button.add_theme_font_override("font", _UITheme.font_display())
	button.add_theme_font_size_override("font_size", 12)
	footer.add_child(button)

	return card


func _on_close_pressed() -> void:
	if _is_closing:
		return
	_is_closing = true
	_close_button.disabled = true
	await _play_close_transition()
	closed.emit()
	queue_free()


func _play_open_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_enter(self, _modal, 0.18, null, Vector2(1.03, 1.03))


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _modal, 0.16)
	await _transition_tween.finished
