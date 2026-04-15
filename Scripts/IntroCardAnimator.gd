class_name IntroCardAnimator
extends Node
## Builds and animates stage intro cards (rule, target) with pop→type→hold→return→slot flow.

signal card_slotted(card_kind: String)

const _UITheme := preload("res://Scripts/UITheme.gd")

const INTRO_CARD_POP_DURATION: float = 0.26
const INTRO_CARD_TYPE_DURATION: float = 0.62
const INTRO_CARD_HOLD_DURATION: float = 0.36
const INTRO_CARD_TRAVEL_DURATION: float = 0.56
const INTRO_CARD_FADE_DURATION: float = 0.18
const INTRO_CARD_SEQUENCE_GAP: float = 0.10
const INTRO_CARD_SPLIT_Y: float = 18.0
const INTRO_CARD_TARGET_Y_OFFSET: float = -6.0
const INTRO_CARD_SIZE: Vector2 = Vector2(360.0, 132.0)
const INTRO_CARD_RETURN_SCALE: Vector2 = Vector2(0.52, 0.52)
const INTRO_CARD_SLOT_COMPRESS_DURATION: float = 0.07
const INTRO_CARD_SLOT_SETTLE_DURATION: float = 0.1
const INTRO_CARD_SLOT_HOLD_DURATION: float = 0.14
const INTRO_CARD_SLOT_SQUASH_SCALE: Vector2 = Vector2(0.48, 0.58)

var _rule_header_label: Label = null
var _target_label: Label = null
var _stage_intro_layer: Control = null
var _host: Control = null
var _hidden_resident_labels: Dictionary = {}
var _resident_label_modulates: Dictionary = {}


func setup(host: Control, rule_header_label: Label, target_label: Label) -> void:
	_host = host
	_rule_header_label = rule_header_label
	_target_label = target_label


func ensure_intro_layer() -> void:
	if _stage_intro_layer != null and is_instance_valid(_stage_intro_layer):
		return
	if _host == null:
		return
	_stage_intro_layer = Control.new()
	_stage_intro_layer.name = "StageIntroLayer"
	_stage_intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_intro_layer.top_level = true
	_stage_intro_layer.z_index = 220
	_stage_intro_layer.anchor_left = 0.0
	_stage_intro_layer.anchor_top = 0.0
	_stage_intro_layer.anchor_right = 0.0
	_stage_intro_layer.anchor_bottom = 0.0
	_stage_intro_layer.global_position = Vector2.ZERO
	_stage_intro_layer.size = _host.get_viewport_rect().size
	_host.add_child(_stage_intro_layer)


func update_layer_size() -> void:
	if _stage_intro_layer == null or not is_instance_valid(_stage_intro_layer):
		return
	if _host == null:
		return
	var viewport_size: Vector2 = _host.get_viewport_rect().size
	if _stage_intro_layer.size != viewport_size:
		_stage_intro_layer.size = viewport_size


func is_layer_active() -> bool:
	return _stage_intro_layer != null and is_instance_valid(_stage_intro_layer)


func play(rule_color: Color) -> void:
	ensure_intro_layer()
	_clear_cards()
	var rule_text: String = _extract_rule_label_text(_rule_header_label.text)
	var target_text: String = str(GameManager.stage_target_score)
	var center: Vector2 = _host.get_viewport_rect().size * 0.5
	var rule_popup_center: Vector2 = center + Vector2(0.0, -INTRO_CARD_SPLIT_Y)
	var target_popup_center: Vector2 = center + Vector2(0.0, INTRO_CARD_SPLIT_Y)
	var rule_anchor: Vector2 = _get_rule_intro_anchor_center()
	var target_anchor: Vector2 = _get_target_intro_anchor_center()
	_hide_resident_label("rule")
	_hide_resident_label("target")
	var rule_card: PanelContainer = _build_card("RULE", rule_text, rule_color)
	var target_card: PanelContainer = _build_card("TARGET", target_text, _UITheme.SCORE_GOLD)
	target_card.visible = false
	_stage_intro_layer.add_child(rule_card)
	_stage_intro_layer.add_child(target_card)
	_animate_card(
		rule_card,
		rule_anchor,
		rule_popup_center,
		0.0,
		"rule",
		Callable(self, "_animate_card").bind(target_card, target_anchor, target_popup_center, INTRO_CARD_SEQUENCE_GAP, "target")
	)


func _clear_cards() -> void:
	if _stage_intro_layer == null or not is_instance_valid(_stage_intro_layer):
		_restore_all_resident_labels()
		return
	for child: Node in _stage_intro_layer.get_children():
		child.queue_free()
	_restore_all_resident_labels()


func _build_card(title_text: String, body_text: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = INTRO_CARD_SIZE
	card.z_index = 260
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_semantic_frame_panel(Color(_UITheme.SURFACE_ASH, 0.985), Color(accent, 0.96), 14, 3)
	)
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(card_vbox)
	var heading := Label.new()
	heading.name = "HeadingLabel"
	heading.text = title_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", _UITheme.font_mono())
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(accent, 0.98))
	card_vbox.add_child(heading)
	var body := Label.new()
	body.name = "BodyLabel"
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("font", _UITheme.font_display())
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	body.visible_characters = 0
	card_vbox.add_child(body)
	return card


func _animate_card(
	card: PanelContainer,
	home_center: Vector2,
	popup_center: Vector2,
	delay: float,
	card_kind: String = "",
	on_complete: Callable = Callable()
) -> void:
	if card == null or not is_instance_valid(card):
		return
	var body: Label = card.get_node("CardMargin/CardVBox/BodyLabel") as Label
	if body == null:
		return
	var card_size: Vector2 = card.custom_minimum_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	var home_position: Vector2 = home_center - card_size * 0.5
	var popup_position: Vector2 = popup_center - card_size * 0.5
	card.global_position = home_position
	card.visible = false
	card.modulate.a = 0.0
	card.scale = INTRO_CARD_RETURN_SCALE
	body.visible_characters = 0
	var tween: Tween = card.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		card.visible = true
	)
	tween.tween_property(card, "modulate:a", 1.0, INTRO_CARD_POP_DURATION)
	tween.parallel().tween_property(card, "global_position", popup_position, INTRO_CARD_TRAVEL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, INTRO_CARD_TRAVEL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "visible_characters", body.text.length(), INTRO_CARD_TYPE_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(INTRO_CARD_HOLD_DURATION)
	tween.tween_property(card, "global_position", home_position, INTRO_CARD_TRAVEL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(card, "scale", INTRO_CARD_RETURN_SCALE, INTRO_CARD_TRAVEL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_emit_card_slot.bind(card_kind))
	tween.tween_property(card, "scale", INTRO_CARD_SLOT_SQUASH_SCALE, INTRO_CARD_SLOT_COMPRESS_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "scale", INTRO_CARD_RETURN_SCALE, INTRO_CARD_SLOT_SETTLE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(INTRO_CARD_SLOT_HOLD_DURATION)
	tween.tween_property(card, "modulate:a", 0.0, INTRO_CARD_FADE_DURATION)
	tween.tween_callback(_restore_resident_label.bind(card_kind))
	if on_complete.is_valid():
		tween.tween_callback(on_complete)
	tween.tween_callback(card.queue_free)


func _emit_card_slot(card_kind: String) -> void:
	if card_kind.is_empty():
		return
	card_slotted.emit(card_kind)


func _hide_resident_label(card_kind: String) -> void:
	var label: Label = _get_resident_label(card_kind)
	if label == null:
		return
	_hidden_resident_labels[card_kind] = true
	_resident_label_modulates[card_kind] = label.modulate
	var hidden_modulate: Color = label.modulate
	hidden_modulate.a = 0.0
	label.modulate = hidden_modulate


func _restore_resident_label(card_kind: String) -> void:
	var label: Label = _get_resident_label(card_kind)
	if label == null:
		return
	_hidden_resident_labels.erase(card_kind)
	if _resident_label_modulates.has(card_kind):
		label.modulate = _resident_label_modulates.get(card_kind, label.modulate) as Color
		_resident_label_modulates.erase(card_kind)
		return
	var visible_modulate: Color = label.modulate
	visible_modulate.a = 1.0
	label.modulate = visible_modulate


func _restore_all_resident_labels() -> void:
	_restore_resident_label("rule")
	_restore_resident_label("target")


func sync_resident_label_hidden_state(card_kind: String) -> void:
	if not bool(_hidden_resident_labels.get(card_kind, false)):
		return
	var label: Label = _get_resident_label(card_kind)
	if label == null:
		return
	_resident_label_modulates[card_kind] = label.modulate
	var hidden_modulate: Color = label.modulate
	hidden_modulate.a = 0.0
	label.modulate = hidden_modulate


func _get_resident_label(card_kind: String) -> Label:
	if card_kind == "rule":
		return _rule_header_label
	if card_kind == "target":
		return _target_label
	return null


func _get_rule_intro_anchor_center() -> Vector2:
	return _get_card_anchor_center(_rule_header_label, false, INTRO_CARD_TARGET_Y_OFFSET)


func _get_target_intro_anchor_center() -> Vector2:
	return _get_card_anchor_center(_target_label, true, INTRO_CARD_TARGET_Y_OFFSET)


func _get_card_anchor_center(anchor_control: Control, align_right_edge: bool, y_offset: float = 0.0) -> Vector2:
	if anchor_control == null:
		return _host.get_viewport_rect().size * 0.5
	var scaled_width: float = INTRO_CARD_SIZE.x * INTRO_CARD_RETURN_SCALE.x
	var anchor_rect := Rect2(anchor_control.global_position, anchor_control.size)
	var center_x: float = anchor_rect.position.x + scaled_width * 0.5
	if align_right_edge:
		center_x = anchor_rect.position.x + anchor_rect.size.x - scaled_width * 0.5
	var center_y: float = anchor_rect.position.y + anchor_rect.size.y * 0.5 + y_offset
	return Vector2(center_x, center_y)


func _extract_rule_label_text(rule_label: String) -> String:
	var clean_label: String = rule_label.strip_edges()
	if clean_label.begins_with("RULE:"):
		return clean_label.trim_prefix("RULE:").strip_edges()
	return clean_label
