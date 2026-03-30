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
