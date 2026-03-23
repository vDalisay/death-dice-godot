class_name DieButton
extends Button
## Visual representation of a single die. Owns its own colour, text,
## toggle state, and pop animation. Emits `toggled_keep` when clicked.

signal toggled_keep(die_index: int, is_kept: bool)

enum DieState { UNROLLED, REROLLABLE, KEPT, KEEP_LOCKED, AUTO_KEPT, STOPPED }

const POP_SCALE: Vector2 = Vector2(1.3, 1.3)
const POP_DURATION: float = 0.25

var die_index: int = -1
var die_state: DieState = DieState.UNROLLED

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
	# All other states are non-interactive — ignore.

func _apply_visual() -> void:
	match die_state:
		DieState.UNROLLED:
			modulate = Color(0.6, 0.6, 0.6)
			disabled = true
		DieState.REROLLABLE:
			modulate = Color(1.0, 0.65, 0.2)   # Orange
			disabled = false
		DieState.KEPT:
			modulate = Color(0.3, 0.85, 0.3)   # Bright green
			disabled = false
		DieState.KEEP_LOCKED:
			modulate = Color(0.1, 0.65, 0.1)   # Dark green
			disabled = true
		DieState.AUTO_KEPT:
			modulate = Color(1.0, 0.85, 0.0)   # Gold
			disabled = true
		DieState.STOPPED:
			modulate = Color(0.9, 0.2, 0.2)    # Red
			disabled = true
