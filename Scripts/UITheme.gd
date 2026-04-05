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
const ART_ROOT_PATH: String      = "res://Art/"
const ART_UI_PATH: String        = ART_ROOT_PATH + "UI/"
const ART_DICE_PATH: String      = ART_ROOT_PATH + "Dice/"

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
const CORNER_RADIUS_CARD: int  = 12
const CORNER_RADIUS_BADGE: int = 8
const CORNER_RADIUS_MODAL: int = 12
const TOUCH_TARGET_MIN: int    = 44
const BUTTON_HEIGHT: int       = 56
const SHADOW_DEPTH: int        = 4

const MACHINE_BORDER_WIDTH: int = 2
const MACHINE_BORDER_CYAN: Color = Color("#00E5FF88")
const MACHINE_BORDER_DANGER: Color = Color("#FF174488")

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


static func get_panel_frame(id: String) -> Texture2D:
	var path: String = ART_UI_PATH + "Frames/" + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func get_icon(id: String) -> Texture2D:
	var path: String = ART_UI_PATH + "Icons/" + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func get_die_sprite(face_id: String, variant: String = "default") -> Texture2D:
	var path: String = ART_DICE_PATH + face_id.to_lower() + "_" + variant.to_lower() + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
static func make_panel_stylebox(bg: Color = PANEL_SURFACE, corner: int = CORNER_RADIUS_CARD, border_color: Color = MACHINE_BORDER_CYAN, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	sb.shadow_color = Color("#05050A")
	sb.shadow_size = SHADOW_DEPTH
	sb.shadow_offset = Vector2i(0, 0)
	if border_width > 0:
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
		sb.border_color = border_color
	return sb


static func apply_modal_panel_style(panel: PanelContainer, border_color: Color = MACHINE_BORDER_DANGER, border_width: int = MACHINE_BORDER_WIDTH, bg: Color = PANEL_SURFACE) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		make_panel_stylebox(bg, CORNER_RADIUS_MODAL, border_color, border_width)
	)


static func make_textured_panel_stylebox(frame_id: String, fallback_bg: Color = PANEL_SURFACE) -> StyleBox:
	var frame: Texture2D = get_panel_frame(frame_id)
	if frame == null:
		return make_panel_stylebox(fallback_bg)
	var sb := StyleBoxTexture.new()
	sb.texture = frame
	sb.texture_margin_left = 12.0
	sb.texture_margin_right = 12.0
	sb.texture_margin_top = 12.0
	sb.texture_margin_bottom = 12.0
	return sb


static func apply_label_style(control: Control, font: Font, font_size: int, font_color: Color) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", font_color)


# ---------------------------------------------------------------------------
# Stage Family Tokens (route-board visual language)
# ---------------------------------------------------------------------------
const STAGE_FAMILY_BACKDROP_COLOR: Color = Color("#090A0F")
const STAGE_FAMILY_BACKDROP_ALPHA: float = 0.52
const STAGE_FAMILY_ATMOS_TOP_SHADE: Color = Color(0.0, 0.0, 0.0, 0.24)
const STAGE_FAMILY_ATMOS_BOTTOM_SHADE: Color = Color(0.0, 0.0, 0.0, 0.34)

const STAGE_FAMILY_MARGIN_X: int = 24
const STAGE_FAMILY_MARGIN_Y: int = 20
const STAGE_FAMILY_WIDE_PANEL_WIDTH: int = 1080
const STAGE_FAMILY_MEDIUM_PANEL_WIDTH: int = 920

const STAGE_FAMILY_HEADER_FILL: Color = Color("#120F15", 0.94)
const STAGE_FAMILY_BOARD_FILL: Color = Color("#17131A", 0.96)
const STAGE_FAMILY_INSPECTOR_FILL: Color = Color("#151117", 0.97)
const STAGE_FAMILY_FOOTER_FILL: Color = Color("#100D13", 0.94)

const STAGE_FAMILY_HEADER_BORDER: Color = Color("#564535")
const STAGE_FAMILY_BOARD_BORDER: Color = Color("#5C4A38")
const STAGE_FAMILY_INSPECTOR_BORDER: Color = Color("#473A2F")
const STAGE_FAMILY_FOOTER_BORDER: Color = Color("#43372C")

const STAGE_FAMILY_TITLE_COLOR: Color = Color("#E5D9B7")
const STAGE_FAMILY_CONTEXT_COLOR: Color = Color("#A8A099")
const STAGE_FAMILY_ACCENT_TEXT: Color = Color("#8F7C63")
const STAGE_FAMILY_BODY_TEXT: Color = Color("#D4C8B7")
const STAGE_FAMILY_MUTED_TEXT: Color = Color("#8A7F73")


# ---------------------------------------------------------------------------
# Stage Map Specific Tokens
# ---------------------------------------------------------------------------
const STAGE_MAP_NODE_SIZE: float = 92.0
const STAGE_MAP_MIN_SPACING: float = 116.0
const STAGE_MAP_PADDING_V: float = 34.0

const STAGE_MAP_LINE_WIDTH: float = 3.0
const STAGE_MAP_LINE_WIDTH_ACTIVE: float = 4.5
const STAGE_MAP_LINE_COLOR: Color = Color("#3A3129", 0.55)
const STAGE_MAP_LINE_COLOR_VISITED: Color = Color("#7F6C57", 0.42)
const STAGE_MAP_LINE_COLOR_ACTIVE: Color = Color("#89C6C7", 0.80)
const STAGE_MAP_LINE_COLOR_SELECTED: Color = Color("#D7A769", 0.92)
const STAGE_MAP_LINE_COLOR_FUTURE: Color = Color("#201D22", 0.58)

const STAGE_MAP_ALPHA_VISITED: float = 0.42
const STAGE_MAP_ALPHA_FUTURE: float = 0.34
const STAGE_MAP_ALPHA_UNREACHABLE: float = 0.60

const STAGE_MAP_GLOW_CURRENT_ROW: Color = Color("#89C6C7")
const STAGE_MAP_GLOW_SELECTED: Color = Color("#E1D0A2")
const STAGE_MAP_GLOW_REROUTE: Color = Color("#D7A769")

const STAGE_MAP_ICON_FONT_SIZE: int = 11
const STAGE_MAP_STATE_FONT_SIZE: int = 10
const STAGE_MAP_PANEL_INTRO_DURATION: float = 0.22
const STAGE_MAP_NODE_REVEAL_STAGGER: float = 0.04
const STAGE_MAP_NODE_REVEAL_DURATION: float = 0.16

const STAGE_MAP_MEDALLION_CORNER_SHOP: int = 10
const STAGE_MAP_MEDALLION_CORNER_RANDOM: int = 22
const STAGE_MAP_MEDALLION_CORNER_FORGE: int = 6
const STAGE_MAP_MEDALLION_CORNER_REST: int = 26
const STAGE_MAP_MEDALLION_CORNER_SPECIAL: int = 14
const STAGE_MAP_MEDALLION_CORNER_DEFAULT: int = 12


static func make_stage_family_panel_style(variant: String, corner: int, border_width: int = 1) -> StyleBoxFlat:
	var fill: Color = STAGE_FAMILY_BOARD_FILL
	var border: Color = STAGE_FAMILY_BOARD_BORDER
	match variant:
		"header":
			fill = STAGE_FAMILY_HEADER_FILL
			border = STAGE_FAMILY_HEADER_BORDER
		"board":
			fill = STAGE_FAMILY_BOARD_FILL
			border = STAGE_FAMILY_BOARD_BORDER
		"inspector":
			fill = STAGE_FAMILY_INSPECTOR_FILL
			border = STAGE_FAMILY_INSPECTOR_BORDER
		"footer":
			fill = STAGE_FAMILY_FOOTER_FILL
			border = STAGE_FAMILY_FOOTER_BORDER
	var width: int = maxi(border_width, 0)
	return make_panel_stylebox(fill, corner, border, width)


static func get_stage_map_medallion_corner(node_type: int) -> int:
	match node_type:
		0:
			return STAGE_MAP_MEDALLION_CORNER_SHOP
		1:
			return STAGE_MAP_MEDALLION_CORNER_RANDOM
		2:
			return STAGE_MAP_MEDALLION_CORNER_FORGE
		3:
			return STAGE_MAP_MEDALLION_CORNER_REST
		4:
			return STAGE_MAP_MEDALLION_CORNER_SPECIAL
		_:
			return STAGE_MAP_MEDALLION_CORNER_DEFAULT


static func get_stage_map_medallion_size(node_type: int) -> Vector2:
	match node_type:
		0:
			return Vector2(80.0, 68.0)
		1:
			return Vector2(70.0, 82.0)
		2:
			return Vector2(82.0, 82.0)
		3:
			return Vector2(72.0, 72.0)
		4:
			return Vector2(86.0, 86.0)
		_:
			return Vector2(76.0, 76.0)


static func apply_stage_map_label_style(label: Label, role: String) -> void:
	label.add_theme_font_override("font", _resolve_stage_map_font(role))
	label.add_theme_font_size_override("font_size", _resolve_stage_map_font_size(role))
	label.add_theme_color_override("font_color", _resolve_stage_map_label_color(role))


static func _resolve_stage_map_font(role: String) -> Font:
	match role:
		"title", "node_title", "button":
			return font_display()
		"context", "seal", "board", "eyebrow", "node_type", "legend":
			return font_mono()
		_:
			return font_body()


static func _resolve_stage_map_font_size(role: String) -> int:
	match role:
		"title":
			return 18
		"context":
			return 18
		"seal", "board":
			return 20
		"eyebrow":
			return 18
		"node_title":
			return 16
		"node_type":
			return 18
		"rule", "flavor", "summary", "hint":
			return 15
		"legend":
			return 16
		"button":
			return 12
		_:
			return 15


static func _resolve_stage_map_label_color(role: String) -> Color:
	match role:
		"title":
			return STAGE_FAMILY_TITLE_COLOR
		"context":
			return STAGE_FAMILY_CONTEXT_COLOR
		"seal":
			return STAGE_FAMILY_ACCENT_TEXT
		"board":
			return Color("#907A60")
		"eyebrow":
			return STAGE_FAMILY_ACCENT_TEXT
		"node_title":
			return Color("#EAE1C8")
		"node_type":
			return Color("#B7AB95")
		"flavor":
			return Color("#C9BEAE")
		"summary":
			return Color("#E3D8C4")
		"rule":
			return STAGE_MAP_GLOW_REROUTE
		"hint":
			return STAGE_FAMILY_BODY_TEXT
		"legend":
			return STAGE_FAMILY_MUTED_TEXT
		_:
			return BRIGHT_TEXT


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
