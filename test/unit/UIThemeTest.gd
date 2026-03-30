extends GdUnitTestSuite
## Unit tests for UITheme design-system constants and factories.

const _UITheme := preload("res://Scripts/UITheme.gd")


# ---------------------------------------------------------------------------
# Color Constants
# ---------------------------------------------------------------------------

func test_background_is_dark() -> void:
	# Background should be very dark (low luminance)
	assert_float(_UITheme.BACKGROUND.get_luminance()).is_less(0.1)


func test_action_cyan_is_bright() -> void:
	assert_float(_UITheme.ACTION_CYAN.get_luminance()).is_greater(0.5)


func test_palette_has_no_transparent_colors() -> void:
	var colors: Array[Color] = [
		_UITheme.BACKGROUND, _UITheme.PANEL_SURFACE, _UITheme.ELEVATED,
		_UITheme.SCORE_GOLD, _UITheme.ACTION_CYAN, _UITheme.DANGER_RED,
		_UITheme.SUCCESS_GREEN, _UITheme.NEON_PURPLE, _UITheme.EXPLOSION_ORANGE,
		_UITheme.ROSE_ACCENT, _UITheme.MUTED_TEXT, _UITheme.BRIGHT_TEXT,
	]
	for c: Color in colors:
		assert_float(c.a).is_equal(1.0)


# ---------------------------------------------------------------------------
# Rarity Colors
# ---------------------------------------------------------------------------

func test_rarity_color_mapping() -> void:
	assert_object(_UITheme.get_rarity_color(0)).is_equal(_UITheme.RARITY_GREY)
	assert_object(_UITheme.get_rarity_color(1)).is_equal(_UITheme.RARITY_GREEN)
	assert_object(_UITheme.get_rarity_color(2)).is_equal(_UITheme.RARITY_BLUE)
	assert_object(_UITheme.get_rarity_color(3)).is_equal(_UITheme.RARITY_PURPLE)


func test_rarity_unknown_defaults_to_grey() -> void:
	assert_object(_UITheme.get_rarity_color(99)).is_equal(_UITheme.RARITY_GREY)


# ---------------------------------------------------------------------------
# Spacing Tokens
# ---------------------------------------------------------------------------

func test_spacing_tokens_increase() -> void:
	assert_int(_UITheme.SPACE_XS).is_less(_UITheme.SPACE_SM)
	assert_int(_UITheme.SPACE_SM).is_less(_UITheme.SPACE_MD)
	assert_int(_UITheme.SPACE_MD).is_less(_UITheme.SPACE_LG)
	assert_int(_UITheme.SPACE_LG).is_less(_UITheme.SPACE_XL)
	assert_int(_UITheme.SPACE_XL).is_less(_UITheme.SPACE_XXL)


# ---------------------------------------------------------------------------
# Glyph Constants
# ---------------------------------------------------------------------------

func test_glyphs_are_non_empty() -> void:
	var glyphs: Array[String] = [
		_UITheme.GLYPH_HEART, _UITheme.GLYPH_GOLD, _UITheme.GLYPH_SHIELD,
		_UITheme.GLYPH_STAR, _UITheme.GLYPH_STOP, _UITheme.GLYPH_LOCK,
		_UITheme.GLYPH_CHECK, _UITheme.GLYPH_EXPLODE, _UITheme.GLYPH_FIRE,
		_UITheme.GLYPH_DIE, _UITheme.GLYPH_CURSED,
	]
	for g: String in glyphs:
		assert_str(g).is_not_empty()


func test_glyphs_contain_no_emoji() -> void:
	# Glyphs should be short Unicode chars, not multi-codepoint emoji
	var glyphs: Array[String] = [
		_UITheme.GLYPH_HEART, _UITheme.GLYPH_GOLD, _UITheme.GLYPH_SHIELD,
		_UITheme.GLYPH_STAR, _UITheme.GLYPH_STOP, _UITheme.GLYPH_LOCK,
		_UITheme.GLYPH_CHECK, _UITheme.GLYPH_EXPLODE, _UITheme.GLYPH_FIRE,
		_UITheme.GLYPH_DIE, _UITheme.GLYPH_CURSED,
	]
	for g: String in glyphs:
		assert_int(g.length()).is_less_equal(2)


# ---------------------------------------------------------------------------
# Font Loaders
# ---------------------------------------------------------------------------

func test_font_display_loads() -> void:
	var f: Font = _UITheme.font_display()
	assert_object(f).is_not_null()


func test_font_body_loads() -> void:
	var f: Font = _UITheme.font_body()
	assert_object(f).is_not_null()


func test_font_stats_loads() -> void:
	var f: Font = _UITheme.font_stats()
	assert_object(f).is_not_null()


func test_font_mono_loads() -> void:
	var f: Font = _UITheme.font_mono()
	assert_object(f).is_not_null()


# ---------------------------------------------------------------------------
# StyleBox Factory
# ---------------------------------------------------------------------------

func test_make_panel_stylebox_returns_stylebox_flat() -> void:
	var sb: StyleBoxFlat = _UITheme.make_panel_stylebox()
	assert_object(sb).is_not_null()
	assert_object(sb).is_instanceof(StyleBoxFlat)


func test_make_panel_stylebox_applies_bg_color() -> void:
	var sb: StyleBoxFlat = _UITheme.make_panel_stylebox(Color.RED)
	assert_object(sb.bg_color).is_equal(Color.RED)


func test_make_panel_stylebox_applies_corner_radius() -> void:
	var sb: StyleBoxFlat = _UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, 12)
	assert_int(sb.corner_radius_top_left).is_equal(12)
	assert_int(sb.corner_radius_bottom_right).is_equal(12)


func test_make_panel_stylebox_applies_border() -> void:
	var sb: StyleBoxFlat = _UITheme.make_panel_stylebox(
		_UITheme.PANEL_SURFACE, 8, _UITheme.ACTION_CYAN, 3
	)
	assert_int(sb.border_width_left).is_equal(3)
	assert_int(sb.border_width_top).is_equal(3)
	assert_object(sb.border_color).is_equal(_UITheme.ACTION_CYAN)


func test_make_panel_stylebox_no_border_by_default() -> void:
	var sb: StyleBoxFlat = _UITheme.make_panel_stylebox()
	assert_int(sb.border_width_left).is_equal(0)


# ---------------------------------------------------------------------------
# build_theme()
# ---------------------------------------------------------------------------

func test_build_theme_returns_theme() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_object(t).is_not_null()
	assert_object(t).is_instanceof(Theme)


func test_build_theme_has_default_font() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_object(t.default_font).is_not_null()


func test_build_theme_has_label_color() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_bool(t.has_color("font_color", "Label")).is_true()


func test_build_theme_has_button_styles() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_bool(t.has_stylebox("normal", "Button")).is_true()
	assert_bool(t.has_stylebox("hover", "Button")).is_true()
	assert_bool(t.has_stylebox("pressed", "Button")).is_true()
	assert_bool(t.has_stylebox("disabled", "Button")).is_true()


func test_build_theme_has_progressbar_styles() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_bool(t.has_stylebox("background", "ProgressBar")).is_true()
	assert_bool(t.has_stylebox("fill", "ProgressBar")).is_true()


func test_build_theme_has_panel_container_style() -> void:
	var t: Theme = _UITheme.build_theme()
	assert_bool(t.has_stylebox("panel", "PanelContainer")).is_true()
