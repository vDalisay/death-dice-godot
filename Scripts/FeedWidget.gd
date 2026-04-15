class_name FeedWidget
extends Node
## Manages the event-feed badge lane: push, TTL expiry, and rebuild.

const _UITheme := preload("res://Scripts/UITheme.gd")

const FEED_TAG_TTL_SECONDS: float = 7.5
const FEED_MAX_TAGS: int = 6

var _feed_container: HBoxContainer = null
var _feed_row: CenterContainer = null
var _feed_title: Label = null
var _feed_entries: Array[Dictionary] = []
var _feed_entry_counter: int = 0


func setup(feed_container: HBoxContainer, feed_row: CenterContainer, feed_title: Label) -> void:
	_feed_container = feed_container
	_feed_row = feed_row
	_feed_title = feed_title


func push_event_effect(summary: String, status_color: Color = _UITheme.STATUS_INFO, ttl_seconds: float = FEED_TAG_TTL_SECONDS) -> void:
	push_feed_tag("EVENT", summary, status_color, ttl_seconds)


func push_score_causality_tag(label_raw: String, value_text: String, status_color: Color = _UITheme.SCORE_GOLD, ttl_seconds: float = FEED_TAG_TTL_SECONDS) -> void:
	var label_text: String = label_raw.strip_edges()
	var value_label: String = value_text.strip_edges()
	if label_text.is_empty() and value_label.is_empty():
		return
	var detail: String = value_label if label_text.is_empty() else "%s %s" % [label_text, value_label]
	push_feed_tag("SCORE", detail.strip_edges(), status_color, ttl_seconds)


func push_combo_effect(combo_name: String, status_color: Color = _UITheme.ROSE_ACCENT, ttl_seconds: float = FEED_TAG_TTL_SECONDS) -> void:
	var label_text: String = combo_name.strip_edges()
	if label_text.is_empty():
		return
	push_feed_tag("COMBO", label_text, status_color, ttl_seconds)


func push_feed_tag(category: String, message: String, tint: Color, ttl_seconds: float = FEED_TAG_TTL_SECONDS) -> void:
	var trimmed_message: String = message.strip_edges()
	if trimmed_message.is_empty():
		return
	var expires_at: int = Time.get_ticks_msec() + int(maxf(0.2, ttl_seconds) * 1000.0)
	var entry: Dictionary = {
		"id": _feed_entry_counter,
		"category": category.strip_edges(),
		"message": trimmed_message,
		"tint": tint,
		"expires_at": expires_at,
	}
	_feed_entry_counter += 1
	_feed_entries.append(entry)
	while _feed_entries.size() > FEED_MAX_TAGS:
		_feed_entries.remove_at(0)
	_rebuild_feed_tags()


func prune_expired() -> void:
	if _feed_entries.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var filtered: Array[Dictionary] = []
	for entry: Dictionary in _feed_entries:
		if int(entry.get("expires_at", 0)) > now:
			filtered.append(entry)
	if filtered.size() == _feed_entries.size():
		return
	_feed_entries = filtered
	_rebuild_feed_tags()


func update_visibility() -> void:
	if _feed_row == null:
		return
	_feed_row.visible = true
	_feed_title.self_modulate = Color.WHITE if not _feed_entries.is_empty() else Color(1.0, 1.0, 1.0, 0.7)


func _rebuild_feed_tags() -> void:
	if _feed_container == null:
		return
	for child: Node in _feed_container.get_children():
		child.queue_free()
	for entry: Dictionary in _feed_entries:
		_feed_container.add_child(_build_feed_badge(entry))
	update_visibility()


func _build_feed_badge(entry: Dictionary) -> PanelContainer:
	var category_text: String = (entry.get("category", "EVENT") as String).to_upper()
	var message_text: String = entry.get("message", "") as String
	var tint: Color = entry.get("tint", _UITheme.STATUS_NEUTRAL) as Color
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(0.0, 24.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_semantic_frame_panel(Color(_UITheme.SURFACE_INSET_ASH, 0.94), Color(tint, 0.88), _UITheme.CORNER_RADIUS_BADGE, 1)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	badge.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var category_label := Label.new()
	category_label.text = category_text
	category_label.add_theme_font_override("font", _UITheme.font_mono())
	category_label.add_theme_font_size_override("font_size", 11)
	category_label.add_theme_color_override("font_color", Color(tint, 0.95))
	row.add_child(category_label)
	var message_label := Label.new()
	message_label.text = message_text
	message_label.add_theme_font_override("font", _UITheme.font_body())
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	row.add_child(message_label)
	return badge
