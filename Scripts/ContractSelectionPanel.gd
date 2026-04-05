class_name ContractSelectionPanel
extends ColorRect
## Modal loop-contract picker. Displays three contract cards and emits the selected ID.

signal contract_selected(contract_id: String)

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const LoopContractDataType: GDScript = preload("res://Scripts/LoopContractData.gd")

@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _subtitle_label: Label = $CenterContainer/Card/MarginContainer/Content/SubtitleLabel
@onready var _cards_container: GridContainer = $CenterContainer/Card/MarginContainer/Content/ScrollContainer/CardsContainer

var _transition_tween: Tween = null
var _interaction_locked: bool = false


func _ready() -> void:
	_apply_theme()


func open(loop_number: int, offers: Array[LoopContractDataType]) -> void:
	_interaction_locked = false
	_title_label.text = "Loop %d Contract" % loop_number
	_subtitle_label.text = "Choose one contract for this loop. Only one can be active."
	_rebuild_cards(offers)
	_play_intro()


func _apply_theme() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(_UITheme.STAGE_FAMILY_BACKDROP_COLOR, _UITheme.STAGE_FAMILY_BACKDROP_ALPHA)
	_card_panel.custom_minimum_size = Vector2(_UITheme.STAGE_FAMILY_MEDIUM_PANEL_WIDTH, 440)
	_card_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_subtitle_label.add_theme_font_override("font", _UITheme.font_body())
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)


func _rebuild_cards(offers: Array[LoopContractDataType]) -> void:
	for child: Node in _cards_container.get_children():
		child.queue_free()
	for offer: LoopContractDataType in offers:
		_cards_container.add_child(_build_contract_card(offer))


func _build_contract_card(contract: LoopContractDataType) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 220)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.ACTION_CYAN, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var name_label := Label.new()
	name_label.text = contract.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	root.add_child(name_label)

	var category_label := Label.new()
	category_label.text = contract.category.to_upper()
	category_label.add_theme_font_override("font", _UITheme.font_mono())
	category_label.add_theme_font_size_override("font_size", 11)
	category_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	root.add_child(category_label)

	var description_label := Label.new()
	description_label.text = contract.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_override("font", _UITheme.font_body())
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	root.add_child(description_label)

	var reward_label := Label.new()
	reward_label.text = "+%dg  +%d EXP  +%d SHARD" % [contract.reward_gold, contract.reward_exp, contract.reward_stop_shards]
	reward_label.add_theme_font_override("font", _UITheme.font_stats())
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	root.add_child(reward_label)

	var select_button := Button.new()
	select_button.text = "Take Contract"
	select_button.add_theme_font_override("font", _UITheme.font_display())
	select_button.add_theme_font_size_override("font_size", 12)
	select_button.pressed.connect(_on_select_pressed.bind(contract.contract_id))
	root.add_child(select_button)

	return card


func _on_select_pressed(contract_id: String) -> void:
	if _interaction_locked:
		return
	_interaction_locked = true
	contract_selected.emit(contract_id)
	await _play_close_transition()
	queue_free()


func _play_intro() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_enter(self, _card_panel, 0.2, null, Vector2(1.04, 1.04))


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _card_panel, 0.16)
	await _transition_tween.finished