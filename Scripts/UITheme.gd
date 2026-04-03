class_name UITheme
extends RefCounted
## Centralized design-system constants for the Death Dice UI overhaul.
## All colors, font paths, spacing tokens and rarity palette live here.
## Nothing in this class has side-effects — it is pure data.

# ---------------------------------------------------------------------------
# Color Palette
# ---------------------------------------------------------------------------
const BACKGROUND: Color       = Color("#0D0D1A")
const PANEL_SURFACE: Color    = Color("#1A1A2E")
const ELEVATED: Color         = Color("#2A2A3E")

const SCORE_GOLD: Color       = Color("#FFD700")
const ACTION_CYAN: Color      = Color("#00E5FF")
const DANGER_RED: Color       = Color("#FF1744")
const SUCCESS_GREEN: Color    = Color("#00E676")
const NEON_PURPLE: Color      = Color("#7C3AED")
const EXPLOSION_ORANGE: Color = Color("#FF6D00")
const ROSE_ACCENT: Color      = Color("#F43F5E")

const MUTED_TEXT: Color       = Color("#8888AA")
const BRIGHT_TEXT: Color      = Color("#E2E8F0")

# ---------------------------------------------------------------------------
# Rarity Colors
# ---------------------------------------------------------------------------
const RARITY_GREY: Color   = Color("#888888")
const RARITY_GREEN: Color  = Color("#00E676")
const RARITY_BLUE: Color   = Color("#4488FF")
const RARITY_PURPLE: Color = Color("#7C3AED")

# ---------------------------------------------------------------------------
# Font Paths (res://)
# ---------------------------------------------------------------------------
const FONT_DISPLAY_PATH: String  = "res://Fonts/PressStart2P-Regular.ttf"
const FONT_STATS_PATH: String    = "res://Fonts/ChakraPetch-Bold.ttf"
const FONT_BODY_PATH: String     = "res://Fonts/ChakraPetch-Regular.ttf"
const FONT_MONO_PATH: String     = "res://Fonts/VT323-Regular.ttf"

# ---------------------------------------------------------------------------
# Spacing Tokens (8dp grid)
# ---------------------------------------------------------------------------
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 16
const SPACE_LG: int = 24
const SPACE_XL: int = 32
const SPACE_XXL: int = 48

# ---------------------------------------------------------------------------
# Component Tokens
# ---------------------------------------------------------------------------
const CORNER_RADIUS_CARD: int  = 8
const CORNER_RADIUS_BADGE: int = 4
const CORNER_RADIUS_MODAL: int = 16
const TOUCH_TARGET_MIN: int    = 44
const BUTTON_HEIGHT: int       = 56
const SHADOW_DEPTH: int        = 4

# ---------------------------------------------------------------------------
# Styled Glyphs (replace emoji)
# ---------------------------------------------------------------------------
const GLYPH_HEART: String   = "♥"
const GLYPH_GOLD: String    = "G"
const GLYPH_SHIELD: String  = "◆"
const GLYPH_STAR: String    = "★"
const GLYPH_STOP: String    = "✕"
const GLYPH_LOCK: String    = "⊠"
const GLYPH_CHECK: String   = "✓"
const GLYPH_EXPLODE: String = "✦"
const GLYPH_FIRE: String    = "▲"
const GLYPH_DIE: String     = "⬡"
const GLYPH_CURSED: String  = "☠"

# ---------------------------------------------------------------------------
# Font Loaders  (cached on first access)
# ---------------------------------------------------------------------------
static var _font_display: Font = null
static var _font_stats: Font = null
static var _font_body: Font = null
static var _font_mono: Font = null


static func font_display() -> Font:
	if _font_display == null:
		_font_display = load(FONT_DISPLAY_PATH) as Font
	return _font_display


static func font_stats() -> Font:
	if _font_stats == null:
		_font_stats = load(FONT_STATS_PATH) as Font
	return _font_stats


static func font_body() -> Font:
	if _font_body == null:
		_font_body = load(FONT_BODY_PATH) as Font
	return _font_body


static func font_mono() -> Font:
	if _font_mono == null:
		_font_mono = load(FONT_MONO_PATH) as Font
	return _font_mono


# ---------------------------------------------------------------------------
# Rarity helper  (mirrors DiceData.Rarity enum values)
# ---------------------------------------------------------------------------
static func get_rarity_color(rarity_value: int) -> Color:
	match rarity_value:
		0: return RARITY_GREY
		1: return RARITY_GREEN
		2: return RARITY_BLUE
		3: return RARITY_PURPLE
	return RARITY_GREY


# ---------------------------------------------------------------------------
# StyleBox Factories
# ---------------------------------------------------------------------------

## Dark flat panel with optional border.
static func make_panel_stylebox(bg: Color = PANEL_SURFACE, corner: int = CORNER_RADIUS_CARD, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	if border_width > 0:
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
		sb.border_color = border_color
	return sb


static func apply_modal_panel_style(panel: PanelContainer, border_color: Color, border_width: int = 2, bg: Color = PANEL_SURFACE) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_stylebox(bg, CORNER_RADIUS_MODAL, border_color, border_width)
	)


static func apply_label_style(control: Control, font: Font, font_size: int, font_color: Color) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", font_color)


## Build and return a Theme resource with the full design-system applied.
static func build_theme() -> Theme:
	var t := Theme.new()

	# -- Default font --
	t.default_font = font_body()
	t.default_font_size = 16

	# -- Label --
	t.set_color("font_color", "Label", BRIGHT_TEXT)
	t.set_font("font", "Label", font_body())
	t.set_font_size("font_size", "Label", 16)

	# -- Button --
	var btn_normal := make_panel_stylebox(PANEL_SURFACE, CORNER_RADIUS_CARD, ACTION_CYAN, 2)
	btn_normal.content_margin_left = float(SPACE_MD)
	btn_normal.content_margin_right = float(SPACE_MD)
	btn_normal.content_margin_top = float(SPACE_SM)
	btn_normal.content_margin_bottom = float(SPACE_SM)
	var btn_hover := make_panel_stylebox(ELEVATED, CORNER_RADIUS_CARD, ACTION_CYAN, 2)
	btn_hover.content_margin_left = float(SPACE_MD)
	btn_hover.content_margin_right = float(SPACE_MD)
	btn_hover.content_margin_top = float(SPACE_SM)
	btn_hover.content_margin_bottom = float(SPACE_SM)
	var btn_pressed := make_panel_stylebox(Color("#151528"), CORNER_RADIUS_CARD, ACTION_CYAN, 2)
	btn_pressed.content_margin_left = float(SPACE_MD)
	btn_pressed.content_margin_right = float(SPACE_MD)
	btn_pressed.content_margin_top = float(SPACE_SM)
	btn_pressed.content_margin_bottom = float(SPACE_SM)
	var btn_disabled := make_panel_stylebox(PANEL_SURFACE, CORNER_RADIUS_CARD, MUTED_TEXT, 1)
	btn_disabled.content_margin_left = float(SPACE_MD)
	btn_disabled.content_margin_right = float(SPACE_MD)
	btn_disabled.content_margin_top = float(SPACE_SM)
	btn_disabled.content_margin_bottom = float(SPACE_SM)

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_color("font_color", "Button", BRIGHT_TEXT)
	t.set_color("font_hover_color", "Button", ACTION_CYAN)
	t.set_color("font_pressed_color", "Button", ACTION_CYAN)
	t.set_color("font_disabled_color", "Button", MUTED_TEXT)
	t.set_font("font", "Button", font_display())
	t.set_font_size("font_size", "Button", 14)

	# -- ProgressBar --
	var pb_bg := make_panel_stylebox(ELEVATED, CORNER_RADIUS_BADGE)
	var pb_fill := make_panel_stylebox(SUCCESS_GREEN, CORNER_RADIUS_BADGE)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# -- PanelContainer --
	t.set_stylebox("panel", "PanelContainer", make_panel_stylebox(PANEL_SURFACE, CORNER_RADIUS_CARD))

	return t
