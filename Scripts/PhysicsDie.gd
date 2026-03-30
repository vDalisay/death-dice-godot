class_name PhysicsDie
extends RigidBody2D
## A single die rendered as a RigidBody2D in the physics arena.
## Top-down view: gravity=0, linear_damp slides to a stop.
## Handles face display, tumble animation, collision reroll,
## click interaction for keep/reroll toggle, and settling detection.

const _UITheme := preload("res://Scripts/UITheme.gd")

signal toggled_keep(die_index: int, is_kept: bool)
signal settled()
signal collision_rerolled(die_index: int, new_face: DiceFaceData)

# ---------------------------------------------------------------------------
# Enums / Constants
# ---------------------------------------------------------------------------

enum DiePhysicsState { FLYING, SETTLING, SETTLED, RESOLVING, KEPT }

const DIE_SIZE: float = 90.0
const COLLISION_RADIUS: float = 45.0
const SETTLE_VELOCITY_THRESHOLD: float = 15.0
const SETTLE_TIME_REQUIRED: float = 0.3
const REROLL_VELOCITY_THRESHOLD: float = 150.0
const COLLISION_COOLDOWN: float = 0.2

const TUMBLE_DURATION: float = 0.35
const TUMBLE_TICKS: int = 6
const POP_SCALE: float = 1.15
const POP_DURATION: float = 0.2
const HOVER_SCALE: float = 1.08
const PRESS_SCALE: float = 0.92
const SCALE_DURATION: float = 0.12
const KEPT_OPACITY: float = 0.7

const TUMBLE_GLYPHS: Array[String] = [
	"1", "2", "3", "4", "5", "STOP", "★3", "SH", "x2", "✦3",
]

## Face type → corner glyph (mirrors DieButton mapping)
const FACE_TYPE_GLYPHS: Dictionary = {
	0: "",      # NUMBER
	1: "",      # BLANK
	2: "✕",     # STOP
	3: "★",     # AUTO_KEEP
	4: "◆",     # SHIELD
	5: "×",     # MULTIPLY
	6: "✦",     # EXPLODE
	7: "←×",    # MULTIPLY_LEFT
	8: "☠",     # CURSED_STOP
	9: "!",     # INSURANCE
}

## Visual state colors
const FILL_DEFAULT: Color   = Color("#1A1A2E")
const FILL_KEPT: Color      = Color("#0A2A0A")
const FILL_STOPPED: Color   = Color("#2A0A0A")
const FILL_AUTO_KEPT: Color = Color("#1A1A2E")

const BORDER_DEFAULT: Color   = Color("#444466")
const BORDER_KEPT: Color      = Color("#00E676")
const BORDER_STOPPED: Color   = Color("#FF1744")
const BORDER_AUTO_KEPT: Color = Color("#FFD700")
const BORDER_LOCKED: Color    = Color("#00E676")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var die_index: int = -1
var die_data: DiceData = null
var current_face: DiceFaceData = null
var physics_state: DiePhysicsState = DiePhysicsState.FLYING
var is_kept: bool = false
var is_keep_locked: bool = false
var is_stopped: bool = false
var rarity_color: Color = Color.TRANSPARENT

var _settle_timer: float = 0.0
var _collision_cooldowns: Dictionary = {}  # body_rid -> float
var _tumble_tween: Tween = null
var _scale_tween: Tween = null
var _glow_tween: Tween = null
var _is_hovered: bool = false

# ---------------------------------------------------------------------------
# Visual nodes (created in _ready)
# ---------------------------------------------------------------------------

var _bg_panel: Panel = null
var _face_label: Label = null
var _glyph_label: Label = null
var _name_label: Label = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	# Physics setup: top-down (no gravity), damped sliding
	gravity_scale = 0.0
	linear_damp = 3.5
	angular_damp = 4.0
	contact_monitor = true
	max_contacts_reported = 4
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 0.6

	# Collision shape
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLISION_RADIUS
	_collision_shape.shape = circle
	add_child(_collision_shape)

	# Visual: background panel
	_bg_panel = Panel.new()
	_bg_panel.size = Vector2(DIE_SIZE, DIE_SIZE)
	_bg_panel.position = Vector2(-DIE_SIZE / 2.0, -DIE_SIZE / 2.0)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	# Face value label (centered)
	_face_label = Label.new()
	_face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_label.size = Vector2(DIE_SIZE, DIE_SIZE)
	_face_label.position = Vector2(-DIE_SIZE / 2.0, -DIE_SIZE / 2.0)
	_face_label.pivot_offset = Vector2(DIE_SIZE / 2.0, DIE_SIZE / 2.0)
	_face_label.add_theme_font_override("font", _UITheme.font_stats())
	_face_label.add_theme_font_size_override("font_size", 26)
	_face_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_label.text = "?"
	add_child(_face_label)

	# Corner glyph label (top-right)
	_glyph_label = Label.new()
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_glyph_label.size = Vector2(DIE_SIZE - 8, 20)
	_glyph_label.position = Vector2(-DIE_SIZE / 2.0 + 4, -DIE_SIZE / 2.0 + 4)
	_glyph_label.pivot_offset = Vector2((DIE_SIZE - 8) / 2.0, 10.0)
	_glyph_label.add_theme_font_size_override("font_size", 13)
	_glyph_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph_label)

	# Die name label (bottom center)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(DIE_SIZE, 16)
	_name_label.position = Vector2(-DIE_SIZE / 2.0, DIE_SIZE / 2.0 - 18)
	_name_label.pivot_offset = Vector2(DIE_SIZE / 2.0, 8.0)
	_name_label.add_theme_font_override("font", _UITheme.font_mono())
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	# Signals
	body_entered.connect(_on_body_entered)
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_apply_visual()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func setup(index: int, data: DiceData) -> void:
	die_index = index
	die_data = data
	current_face = null
	is_kept = false
	is_keep_locked = false
	is_stopped = false
	physics_state = DiePhysicsState.FLYING
	rarity_color = data.get_rarity_color_value() if data else Color.TRANSPARENT
	if _name_label:
		_name_label.text = data.dice_name if data else ""
	if _face_label:
		_face_label.text = "?"
	if _glyph_label:
		_glyph_label.text = ""
	_apply_visual()


func show_face(face: DiceFaceData) -> void:
	current_face = face
	if _face_label:
		_face_label.text = face.get_display_text() if face else "?"
	if _glyph_label and face:
		_glyph_label.text = FACE_TYPE_GLYPHS.get(face.type, "")
	elif _glyph_label:
		_glyph_label.text = ""
	_apply_visual()


func set_physics_state(new_state: DiePhysicsState) -> void:
	physics_state = new_state
	if new_state == DiePhysicsState.KEPT:
		is_kept = true
		freeze = true
	elif new_state == DiePhysicsState.SETTLED:
		freeze = true
	elif new_state == DiePhysicsState.FLYING:
		freeze = false
	_apply_visual()


func tumble(final_face: DiceFaceData) -> void:
	if _tumble_tween and _tumble_tween.is_valid():
		_tumble_tween.kill()
	_tumble_tween = create_tween()
	var interval: float = TUMBLE_DURATION / TUMBLE_TICKS
	for tick: int in TUMBLE_TICKS:
		_tumble_tween.tween_callback(_set_random_glyph).set_delay(interval)
	_tumble_tween.tween_callback(show_face.bind(final_face))
	_tumble_tween.tween_callback(pop)


func pop() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(POP_SCALE, POP_SCALE), POP_DURATION * 0.4) \
		.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, POP_DURATION * 0.6) \
		.set_ease(Tween.EASE_IN)


func show_score_popup(value: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % value
	lbl.add_theme_font_override("font", _UITheme.font_stats())
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-20, -DIE_SIZE / 2.0 - 25)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var start_y: float = lbl.position.y
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "position:y", start_y - 35.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.tween_callback(lbl.queue_free)


func show_chain_label(depth: int) -> void:
	var lbl := Label.new()
	lbl.text = "CHAIN x%d!" % depth
	lbl.add_theme_font_override("font", _UITheme.font_mono())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", _UITheme.EXPLOSION_ORANGE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-30, -DIE_SIZE / 2.0 - 30)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var start_y: float = lbl.position.y
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "position:y", start_y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)


func start_glow_pulse(color: Color) -> void:
	_stop_glow_pulse()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(self, "modulate", Color(color, 0.85), 0.3)
	_glow_tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _stop_glow_pulse() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	modulate = Color.WHITE


# ---------------------------------------------------------------------------
# Physics process — settling detection
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Keep text labels upright regardless of body rotation (dice body rotates freely)
	var neg_rot: float = -rotation
	if _face_label:
		_face_label.rotation = neg_rot
	if _glyph_label:
		_glyph_label.rotation = neg_rot
	if _name_label:
		_name_label.rotation = neg_rot

	# Update collision cooldowns
	var expired: Array[RID] = []
	for rid: RID in _collision_cooldowns:
		_collision_cooldowns[rid] -= delta
		if _collision_cooldowns[rid] <= 0.0:
			expired.append(rid)
	for rid: RID in expired:
		_collision_cooldowns.erase(rid)

	# Settling detection
	if physics_state == DiePhysicsState.FLYING:
		if linear_velocity.length() < SETTLE_VELOCITY_THRESHOLD:
			_settle_timer += delta
			if _settle_timer >= SETTLE_TIME_REQUIRED:
				physics_state = DiePhysicsState.SETTLED
				freeze = true
				settled.emit()
		else:
			_settle_timer = 0.0


# ---------------------------------------------------------------------------
# Collision reroll (cosmetic only — does NOT count toward stops)
# ---------------------------------------------------------------------------

func _on_body_entered(other: Node) -> void:
	if not other is PhysicsDie:
		return
	var other_die: PhysicsDie = other as PhysicsDie
	# Both must be moving fast enough
	if linear_velocity.length() < REROLL_VELOCITY_THRESHOLD:
		return
	if other_die.linear_velocity.length() < REROLL_VELOCITY_THRESHOLD:
		return

	# Cooldown check (use other's RID)
	var other_rid: RID = other_die.get_rid()
	if _collision_cooldowns.has(other_rid):
		return
	_collision_cooldowns[other_rid] = COLLISION_COOLDOWN

	# Reroll this die's face (cosmetic)
	if die_data and not is_keep_locked:
		var new_face: DiceFaceData = die_data.roll()
		tumble(new_face)
		current_face = new_face
		collision_rerolled.emit(die_index, new_face)
		SFXManager.play_dice_collide()


# ---------------------------------------------------------------------------
# Input — click to toggle keep/reroll
# ---------------------------------------------------------------------------

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click()


func _handle_click() -> void:
	_press_bounce()
	if physics_state != DiePhysicsState.SETTLED and physics_state != DiePhysicsState.KEPT:
		return
	if is_keep_locked:
		return

	if is_stopped:
		# Pick up stopped die (Cubitos-style)
		is_stopped = false
		is_kept = false
		toggled_keep.emit(die_index, false)
	elif is_kept:
		is_kept = false
		toggled_keep.emit(die_index, false)
	else:
		is_kept = true
		toggled_keep.emit(die_index, true)
	_apply_visual()


func _press_bounce() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), SCALE_DURATION * 0.6) \
		.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, SCALE_DURATION * 0.8) \
		.set_ease(Tween.EASE_IN)


func _on_mouse_entered() -> void:
	_is_hovered = true
	if physics_state in [DiePhysicsState.SETTLED, DiePhysicsState.KEPT] and not is_keep_locked:
		_animate_hover(Vector2(HOVER_SCALE, HOVER_SCALE))


func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_hover(Vector2.ONE)


func _animate_hover(target_scale: Vector2) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target_scale, SCALE_DURATION).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Visual styling
# ---------------------------------------------------------------------------

func _apply_visual() -> void:
	if not _bg_panel:
		return

	var fill: Color = FILL_DEFAULT
	var border_color: Color = rarity_color if rarity_color != Color.TRANSPARENT else BORDER_DEFAULT
	var border_width: int = 2
	var text_color: Color = _UITheme.BRIGHT_TEXT
	var glyph_color: Color = _UITheme.MUTED_TEXT

	if is_stopped:
		fill = FILL_STOPPED
		border_color = BORDER_STOPPED
		border_width = 3
		text_color = _UITheme.DANGER_RED
		glyph_color = _UITheme.DANGER_RED
		start_glow_pulse(BORDER_STOPPED)
	elif is_keep_locked:
		if current_face and current_face.type in [
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD,
			DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT,
			DiceFaceData.FaceType.EXPLODE,
		]:
			fill = FILL_AUTO_KEPT
			border_color = BORDER_AUTO_KEPT
			border_width = 3
			glyph_color = _UITheme.SCORE_GOLD
		elif current_face and current_face.type == DiceFaceData.FaceType.INSURANCE:
			fill = Color("#0A2A2A")
			border_color = _UITheme.ACTION_CYAN
			border_width = 3
			glyph_color = _UITheme.ACTION_CYAN
			start_glow_pulse(_UITheme.ACTION_CYAN)
		else:
			fill = FILL_KEPT
			border_color = BORDER_LOCKED
			border_width = 3
			glyph_color = _UITheme.SUCCESS_GREEN
		_stop_glow_pulse()
	elif is_kept:
		fill = FILL_KEPT
		border_color = BORDER_KEPT
		border_width = 3
		glyph_color = _UITheme.SUCCESS_GREEN
		_stop_glow_pulse()
	else:
		_stop_glow_pulse()

	# Special: CURSED_STOP
	if current_face and current_face.type == DiceFaceData.FaceType.CURSED_STOP and is_stopped:
		fill = Color("#1A0A2A")
		border_color = _UITheme.NEON_PURPLE
		glyph_color = _UITheme.NEON_PURPLE

	# Opacity for kept dice
	if is_kept or is_keep_locked:
		modulate.a = KEPT_OPACITY
	elif not is_stopped:
		modulate.a = 1.0

	# Apply panel stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(_UITheme.CORNER_RADIUS_CARD)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 2)
	_bg_panel.add_theme_stylebox_override("panel", sb)

	# Apply text colors
	if _face_label:
		_face_label.add_theme_color_override("font_color", text_color)
	if _glyph_label:
		_glyph_label.add_theme_color_override("font_color", glyph_color)


func _set_random_glyph() -> void:
	if _face_label:
		_face_label.text = TUMBLE_GLYPHS[randi() % TUMBLE_GLYPHS.size()]
