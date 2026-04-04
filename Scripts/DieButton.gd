class_name DieButton
extends Button
## Visual representation of a single die as a themed card-style tile.
## Owns colour, text, toggle state, pop animation, tumble reveal, and
## face-type glyph indicator. Emits `toggled_keep` when clicked.

const _UITheme := preload("res://Scripts/UITheme.gd")

signal toggled_keep(die_index: int, is_kept: bool)

enum DieState { UNROLLED, REROLLABLE, KEPT, KEEP_LOCKED, AUTO_KEPT, STOPPED }

const POP_SCALE: Vector2 = Vector2(1.15, 1.15)
const POP_DURATION: float = 0.2
const TUMBLE_DURATION: float = 0.35
const TUMBLE_TICKS: int = 6
const KEPT_OPACITY: float = 0.7
const KEPT_OFFSET_Y: float = 4.0
const HOVER_SCALE: Vector2 = Vector2(1.05, 1.05)
const PRESS_SCALE: Vector2 = Vector2(0.95, 0.95)
const SCALE_DURATION: float = 0.12

## All possible display strings cycled during the tumble animation.
const TUMBLE_GLYPHS: Array[String] = ["1", "2", "3", "4", "5", "STOP", "★3", "SH", "x2", "✦3", "♥"]

## Face type → corner glyph
const FACE_TYPE_GLYPHS: Dictionary = {
	0: "",          # NUMBER
	1: "",          # BLANK
	2: "✕",         # STOP
	3: "★",         # AUTO_KEEP
	4: "◆",         # SHIELD
	5: "×",         # MULTIPLY
	6: "✦",         # EXPLODE
	7: "←×",        # MULTIPLY_LEFT
	8: "☠",         # CURSED_STOP
	9: "!",         # INSURANCE
	10: "🍀",        # LUCK
	11: "♥",        # HEART
}

## State fill colors (dark-on-dark palette)
const FILL_UNROLLED: Color    = Color("#2A2A3E")
const FILL_REROLLABLE: Color  = Color("#1A1A2E")
const FILL_KEPT: Color        = Color("#0A2A0A")
const FILL_KEEP_LOCKED: Color = Color("#0A2A0A")
const FILL_AUTO_KEPT: Color   = Color("#1A1A2E")
const FILL_STOPPED: Color     = Color("#2A0A0A")

## State border colors
const BORDER_UNROLLED: Color    = Color("#444466")
const BORDER_REROLLABLE: Color  = Color.TRANSPARENT  # Uses rarity color
const BORDER_KEPT: Color        = Color("#00E676")
const BORDER_KEEP_LOCKED: Color = Color("#00E676")
const BORDER_AUTO_KEPT: Color   = Color("#FFD700")
const BORDER_STOPPED: Color     = Color("#FF1744")

var die_index: int = -1
var die_state: DieState = DieState.UNROLLED
var custom_color: Color = Color.TRANSPARENT
var rarity_color: Color = Color.TRANSPARENT
var _current_face: DiceFaceData = null
var _die_name: String = ""
var _tumble_tween: Tween = null
var _scale_tween: Tween = null
var _glow_tween: Tween = null

@onready var _face_type_icon: Label = $FaceTypeIcon
@onready var _die_name_label: Label = $DieName


func _ready() -> void:
	custom_minimum_size = Vector2(100, 100)
	clip_text = true
	pivot_offset = custom_minimum_size / 2.0
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_base_styling()
	_die_name_label.text = _die_name
	_apply_visual()


func _apply_base_styling() -> void:
	add_theme_font_override("font", _UITheme.font_stats())
	add_theme_font_size_override("font_size", 28)
	_face_type_icon.add_theme_font_size_override("font_size", 14)
	_die_name_label.add_theme_font_override("font", _UITheme.font_mono())
	_die_name_label.add_theme_font_size_override("font_size", 11)
	_die_name_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)


# ---------------------------------------------------------------------------
# Public API — called by DiceTray
# ---------------------------------------------------------------------------

func setup(index: int) -> void:
	die_index = index
	die_state = DieState.UNROLLED
	_current_face = null
	text = "?"
	if _face_type_icon:
		_face_type_icon.text = ""
	if _die_name_label:
		_die_name_label.text = _die_name
	_apply_visual()


func set_die_name(die_name: String) -> void:
	_die_name = die_name
	if _die_name_label:
		_die_name_label.text = _die_name


func show_face(face: DiceFaceData, state: DieState) -> void:
	die_state = state
	_current_face = face
	text = face.get_display_text() if face != null else "?"
	if _face_type_icon and face != null:
		_face_type_icon.text = FACE_TYPE_GLYPHS.get(face.type, "")
	elif _face_type_icon:
		_face_type_icon.text = ""
	_apply_visual()


func set_state(state: DieState) -> void:
	die_state = state
	_apply_visual()


func pop() -> void:
	pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", POP_SCALE, POP_DURATION * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION * 0.6).set_ease(Tween.EASE_IN)


func tumble(final_face: DiceFaceData, state: DieState) -> void:
	if _tumble_tween and _tumble_tween.is_valid():
		_tumble_tween.kill()
	_tumble_tween = create_tween()
	var interval: float = TUMBLE_DURATION / TUMBLE_TICKS
	for tick: int in TUMBLE_TICKS:
		_tumble_tween.tween_callback(_set_random_glyph).set_delay(interval)
	_tumble_tween.tween_callback(show_face.bind(final_face, state))
	_tumble_tween.tween_callback(pop)


func _set_random_glyph() -> void:
	text = TUMBLE_GLYPHS[randi() % TUMBLE_GLYPHS.size()]


func show_score_popup(value: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "+%d" % value
	lbl.add_theme_font_override("font", _UITheme.font_stats())
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.top_level = true
	add_child(lbl)
	var start_pos: Vector2 = global_position + Vector2(-5, -25)
	lbl.global_position = start_pos
	pop()
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_pos.y - 35.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.tween_callback(lbl.queue_free)


func show_chain_label(depth: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "CHAIN x%d!" % depth
	lbl.add_theme_font_override("font", _UITheme.font_mono())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", _UITheme.EXPLOSION_ORANGE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.top_level = true
	add_child(lbl)
	var start_pos: Vector2 = global_position + Vector2(-10, -30)
	lbl.global_position = start_pos
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_pos.y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	_press_bounce()
	if die_state == DieState.REROLLABLE:
		die_state = DieState.KEPT
		_apply_visual()
		toggled_keep.emit(die_index, true)
	elif die_state == DieState.KEPT:
		die_state = DieState.REROLLABLE
		_apply_visual()
		toggled_keep.emit(die_index, false)
	elif die_state == DieState.STOPPED:
		die_state = DieState.REROLLABLE
		_apply_visual()
		toggled_keep.emit(die_index, false)


func _press_bounce() -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", PRESS_SCALE, SCALE_DURATION * 0.6).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, SCALE_DURATION * 0.8).set_ease(Tween.EASE_IN)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_animate_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE)


func _animate_scale(target: Vector2) -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target, SCALE_DURATION).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Visual Styling
# ---------------------------------------------------------------------------

func _apply_visual() -> void:
	var is_kept_state: bool = die_state in [DieState.KEPT, DieState.KEEP_LOCKED, DieState.AUTO_KEPT]

	# Determine state-based fill and border
	var fill: Color = FILL_UNROLLED
	var border: Color = BORDER_UNROLLED
	var border_width: int = 2
	var text_color: Color = _UITheme.BRIGHT_TEXT
	var icon_color: Color = _UITheme.MUTED_TEXT
	var corner_glyph: String = ""

	match die_state:
		DieState.UNROLLED:
			fill = FILL_UNROLLED
			border = BORDER_UNROLLED
			text_color = Color(text_color, 0.5)
			disabled = true
		DieState.REROLLABLE:
			fill = FILL_REROLLABLE
			border = rarity_color if rarity_color != Color.TRANSPARENT else _UITheme.ACTION_CYAN
			border_width = 3
			disabled = false
		DieState.KEPT:
			fill = FILL_KEPT
			border = BORDER_KEPT
			border_width = 3
			corner_glyph = _UITheme.GLYPH_CHECK
			icon_color = _UITheme.SUCCESS_GREEN
			disabled = false
		DieState.KEEP_LOCKED:
			fill = FILL_KEEP_LOCKED
			border = BORDER_KEEP_LOCKED
			border_width = 3
			corner_glyph = _UITheme.GLYPH_LOCK
			icon_color = _UITheme.SUCCESS_GREEN
			disabled = true
		DieState.AUTO_KEPT:
			fill = FILL_AUTO_KEPT
			border = BORDER_AUTO_KEPT
			border_width = 3
			icon_color = _UITheme.SCORE_GOLD
			disabled = true
		DieState.STOPPED:
			fill = FILL_STOPPED
			border = BORDER_STOPPED
			border_width = 3
			text_color = _UITheme.DANGER_RED
			icon_color = _UITheme.DANGER_RED
			disabled = false

	# Sub-state for specific face types
	if _current_face != null:
		match _current_face.type:
			DiceFaceData.FaceType.INSURANCE:
				if die_state == DieState.AUTO_KEPT:
					fill = Color("#0A2A2A")
					border = _UITheme.ACTION_CYAN
					corner_glyph = "!"
					icon_color = _UITheme.ACTION_CYAN
			DiceFaceData.FaceType.CURSED_STOP:
				if die_state == DieState.STOPPED:
					fill = Color("#1A0A2A")
					border = _UITheme.NEON_PURPLE
					icon_color = _UITheme.NEON_PURPLE

	# Apply override glyph only if state corner_glyph not already set by state
	if _face_type_icon:
		if corner_glyph != "":
			_face_type_icon.text = corner_glyph
		# Otherwise keep whatever was set from show_face()
		_face_type_icon.add_theme_color_override("font_color", icon_color)

	# Apply text color
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", text_color)
	add_theme_color_override("font_pressed_color", text_color)

	# Build and apply StyleBoxFlat for all button states
	_apply_card_style(fill, border, border_width)

	# Kept dice: lower opacity and shift down
	if is_kept_state:
		modulate.a = KEPT_OPACITY
		position.y = KEPT_OFFSET_Y
	else:
		modulate.a = 1.0
		position.y = 0.0

	# Start/stop glow animation for stopped dice
	if die_state == DieState.STOPPED:
		_start_glow_pulse(border)
	elif die_state == DieState.AUTO_KEPT and _current_face != null and _current_face.type == DiceFaceData.FaceType.INSURANCE:
		_start_glow_pulse(_UITheme.ACTION_CYAN)
	else:
		_stop_glow_pulse()


func _apply_card_style(fill: Color, border: Color, border_width: int) -> void:
	var style_names: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
	for i: int in style_names.size():
		var style_name: String = style_names[i]
		var sb := StyleBoxFlat.new()
		# Slightly lighter fill for hover
		if style_name == "hover":
			sb.bg_color = fill.lightened(0.1)
		elif style_name == "pressed":
			sb.bg_color = fill.darkened(0.1)
		else:
			sb.bg_color = fill
		sb.corner_radius_top_left = _UITheme.CORNER_RADIUS_CARD
		sb.corner_radius_top_right = _UITheme.CORNER_RADIUS_CARD
		sb.corner_radius_bottom_left = _UITheme.CORNER_RADIUS_CARD
		sb.corner_radius_bottom_right = _UITheme.CORNER_RADIUS_CARD
		if border != Color.TRANSPARENT and border_width > 0:
			sb.border_width_left = border_width
			sb.border_width_right = border_width
			sb.border_width_top = border_width
			sb.border_width_bottom = border_width
			sb.border_color = border
		# Content margin to keep text away from edges
		sb.content_margin_left = 6.0
		sb.content_margin_right = 6.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 18.0  # Room for die name at bottom
		# Shadow
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = _UITheme.SHADOW_DEPTH
		add_theme_stylebox_override(style_name, sb)


func _start_glow_pulse(color: Color) -> void:
	if _glow_tween and _glow_tween.is_valid():
		return  # Already pulsing
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(self, "modulate", Color(color, 0.8), 0.3)
	_glow_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)


func _stop_glow_pulse() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
