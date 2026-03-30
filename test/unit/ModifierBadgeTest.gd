extends GdUnitTestSuite
## Unit tests for modifier badge rendering and slot state.

const BadgeScene: PackedScene = preload("res://Scenes/ModifierBadge.tscn")


func test_setup_modifier_sets_glyph_text() -> void:
	var badge: PanelContainer = auto_free(BadgeScene.instantiate()) as PanelContainer
	add_child(badge)
	await await_idle_frame()
	badge.setup_modifier(RunModifier.make_iron_bank())
	var glyph: Label = badge.get_node("CenterContainer/BadgeBody/GlyphLabel") as Label
	assert_str(glyph.text).is_equal("Fe")


func test_setup_empty_clears_glyph_text() -> void:
	var badge: PanelContainer = auto_free(BadgeScene.instantiate()) as PanelContainer
	add_child(badge)
	await await_idle_frame()
	badge.setup_modifier(RunModifier.make_miser())
	badge.setup_empty()
	var glyph: Label = badge.get_node("CenterContainer/BadgeBody/GlyphLabel") as Label
	assert_str(glyph.text).is_equal("")


func test_child_nodes_ignore_mouse_for_full_slot_hover() -> void:
	var badge: PanelContainer = auto_free(BadgeScene.instantiate()) as PanelContainer
	add_child(badge)
	await await_idle_frame()
	var center: CenterContainer = badge.get_node("CenterContainer") as CenterContainer
	var body: PanelContainer = badge.get_node("CenterContainer/BadgeBody") as PanelContainer
	var glyph: Label = badge.get_node("CenterContainer/BadgeBody/GlyphLabel") as Label
	assert_int(center.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(body.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(glyph.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
