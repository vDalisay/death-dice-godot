class_name DieButton
extends Button
## Visual representation of a single die. Owns its own colour, text,
## toggle state, pop animation, and tumble reveal. Emits `toggled_keep` when clicked.

signal toggled_keep(die_index: int, is_kept: bool)

enum DieState { UNROLLED, REROLLABLE, KEPT, KEEP_LOCKED, AUTO_KEPT, STOPPED }

const POP_SCALE: Vector2 = Vector2(1.3, 1.3)
const POP_DURATION: float = 0.25
const TUMBLE_DURATION: float = 0.35
const TUMBLE_TICKS: int = 6
const KEPT_OPACITY: float = 0.6
const KEPT_OFFSET_Y: float = 5.0

## All possible display strings cycled during the tumble animation.
const TUMBLE_GLYPHS: Array[String] = ["1", "2", "3", "4", "5", "STOP", "★3", "SH", "x2", "💥3"]

const COLOR_UNROLLED: Color   = Color(0.6, 0.6, 0.6)
const COLOR_REROLLABLE: Color = Color(1.0, 0.65, 0.2)   # Orange
const COLOR_KEPT: Color       = Color(0.3, 0.85, 0.3)   # Bright green
const COLOR_KEEP_LOCKED: Color = Color(0.1, 0.65, 0.1)  # Dark green
const COLOR_AUTO_KEPT: Color  = Color(1.0, 0.85, 0.0)   # Gold
const COLOR_STOPPED: Color    = Color(0.9, 0.2, 0.2)    # Red

var die_index: int = -1
var die_state: DieState = DieState.UNROLLED
var custom_color: Color = Color.TRANSPARENT
var _tumble_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(90, 90)
	add_theme_font_size_override("font_size", 18)
	pressed.connect(_on_pressed)
	_apply_visual()

# ---------------------------------------------------------------------------
# Public API — called by DiceTray
# ---------------------------------------------------------------------------

func setup(index: int) -> void:
	die_index = index
	die_state = DieState.UNROLLED
	text = "?"
	_apply_visual()

func show_face(face: DiceFaceData, state: DieState) -> void:
	die_state = state
	text = face.get_display_text() if face != null else "?"
	_apply_visual()

func set_state(state: DieState) -> void:
	die_state = state
	_apply_visual()

func pop() -> void:
	pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", POP_SCALE, POP_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION).set_ease(Tween.EASE_IN)


## Rapidly cycle random face glyphs then settle on the real result.
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


## Show a floating score popup above this die (e.g. "+5").
func show_score_popup(value: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "+%d" % value
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
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


## Show a floating chain label above this die (e.g. "CHAIN x2!").
func show_chain_label(depth: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "CHAIN x%d!" % depth
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
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
# Internal
# ---------------------------------------------------------------------------

func _on_pressed() -> void:
	if die_state == DieState.REROLLABLE:
		die_state = DieState.KEPT
		_apply_visual()
		toggled_keep.emit(die_index, true)
	elif die_state == DieState.KEPT:
		die_state = DieState.REROLLABLE
		_apply_visual()
		toggled_keep.emit(die_index, false)
	elif die_state == DieState.STOPPED:
		# Cubitos-style: player can pick up a stopped die and reroll it.
		die_state = DieState.REROLLABLE
		_apply_visual()
		toggled_keep.emit(die_index, false)
	# All other states are non-interactive — ignore.

func _apply_visual() -> void:
	var is_kept_state: bool = die_state in [DieState.KEPT, DieState.KEEP_LOCKED, DieState.AUTO_KEPT]
	match die_state:
		DieState.UNROLLED:
			modulate = COLOR_UNROLLED
			disabled = true
		DieState.REROLLABLE:
			modulate = COLOR_REROLLABLE
			disabled = false
		DieState.KEPT:
			modulate = COLOR_KEPT
			disabled = false
		DieState.KEEP_LOCKED:
			modulate = COLOR_KEEP_LOCKED
			disabled = true
		DieState.AUTO_KEPT:
			modulate = COLOR_AUTO_KEPT
			disabled = true
		DieState.STOPPED:
			modulate = COLOR_STOPPED
			disabled = false
	if custom_color != Color.TRANSPARENT:
		modulate = custom_color
	# Kept dice: lower opacity and shift down; unkept: restore.
	if is_kept_state:
		modulate.a = KEPT_OPACITY
		position.y = KEPT_OFFSET_Y
	else:
		modulate.a = 1.0
		position.y = 0.0
