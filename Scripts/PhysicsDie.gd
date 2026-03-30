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
const BUMP_BOOST_MIN_SPEED: float = 80.0
const BUMP_BOOST_IMPULSE_MIN: float = 80.0
const BUMP_BOOST_IMPULSE_MAX: float = 220.0
const BUMP_BOOST_MULTIPLIER: float = 0.1
const SETTLE_POP_SCALE: float = 1.08
const SETTLE_POP_DURATION: float = 0.12
const IMPACT_FLASH_DURATION: float = 0.08
const SCORE_POPUP_RISE: float = 35.0
const SCORE_POPUP_DURATION: float = 0.6
const MULTIPLY_VFX_DURATION: float = 0.35
const REROLL_LIFT_DURATION: float = 0.14
const EXPLODE_CHARGE_DURATION: float = 0.2
const STOP_IMPACT_DURATION: float = 0.18
const KEEP_LOCK_SNAP_DURATION: float = 0.14
const SHIELD_ABSORB_DURATION: float = 0.3

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
var _name_popup: Panel = null
var _name_popup_label: Label = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	# Physics setup: top-down (no gravity), damped sliding
	input_pickable = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
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

	# Hover popup for die name (hidden by default)
	_name_popup = Panel.new()
	_name_popup.size = Vector2(140, 24)
	_name_popup.position = Vector2(-70, -DIE_SIZE / 2.0 - 34)
	_name_popup.pivot_offset = _name_popup.size * 0.5
	_name_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_popup.visible = false
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	popup_style.border_color = _UITheme.ACTION_CYAN
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(6)
	_name_popup.add_theme_stylebox_override("panel", popup_style)
	add_child(_name_popup)

	_name_popup_label = Label.new()
	_name_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_popup_label.size = _name_popup.size
	_name_popup_label.add_theme_font_override("font", _UITheme.font_mono())
	_name_popup_label.add_theme_font_size_override("font_size", 11)
	_name_popup_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	_name_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_popup.add_child(_name_popup_label)

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
	if _name_popup_label:
		_name_popup_label.text = data.dice_name if data else ""
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
	lbl.top_level = true
	lbl.size = Vector2(64, 24)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.global_position = global_position + Vector2(-32.0, -DIE_SIZE / 2.0 - 28.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var start_y: float = lbl.global_position.y
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_y - SCORE_POPUP_RISE, SCORE_POPUP_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, SCORE_POPUP_DURATION).set_ease(Tween.EASE_IN).set_delay(0.2)
	tween.tween_callback(lbl.queue_free)


func show_chain_label(depth: int) -> void:
	var lbl := Label.new()
	lbl.text = "CHAIN x%d!" % depth
	lbl.add_theme_font_override("font", _UITheme.font_mono())
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", _UITheme.EXPLOSION_ORANGE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.top_level = true
	lbl.size = Vector2(96, 20)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.global_position = global_position + Vector2(-48.0, -DIE_SIZE / 2.0 - 34.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var start_y: float = lbl.global_position.y
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)


func play_multiply_vfx(multiplier: int) -> void:
	_play_radial_effect(_UITheme.SCORE_GOLD, "x%d" % multiplier)


func play_multiply_left_vfx(multiplier: int) -> void:
	_play_directional_left_effect(_UITheme.ROSE_ACCENT, "<x%d" % multiplier)


func play_stop_impact(is_cursed: bool) -> void:
	var color: Color = _UITheme.NEON_PURPLE if is_cursed else _UITheme.DANGER_RED
	var label_text: String = "CURSED!" if is_cursed else "STOP"
	_play_radial_effect(color, label_text)
	if _bg_panel:
		var tween: Tween = create_tween()
		tween.tween_property(_bg_panel, "modulate", Color(color, 1.0), STOP_IMPACT_DURATION * 0.45)
		tween.tween_property(_bg_panel, "modulate", Color.WHITE, STOP_IMPACT_DURATION * 0.55)


func play_insurance_trigger() -> void:
	_play_radial_effect(_UITheme.ACTION_CYAN, "INSURANCE")
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.amount = 30
	ring.lifetime = 0.4
	ring.explosiveness = 0.8
	ring.direction = Vector2.ZERO
	ring.spread = 180.0
	ring.initial_velocity_min = 80.0
	ring.initial_velocity_max = 170.0
	ring.gravity = Vector2.ZERO
	ring.color = _UITheme.ACTION_CYAN
	add_child(ring)
	ring.emitting = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)


func play_keep_lock_snap() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), KEEP_LOCK_SNAP_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, KEEP_LOCK_SNAP_DURATION * 0.55).set_ease(Tween.EASE_IN)
	_play_radial_effect(_UITheme.SUCCESS_GREEN, "LOCK")


func play_shield_absorb() -> void:
	_play_radial_effect(_UITheme.ACTION_CYAN, "SHIELD")
	var ring := CPUParticles2D.new()
	ring.one_shot = true
	ring.amount = 18
	ring.lifetime = SHIELD_ABSORB_DURATION
	ring.explosiveness = 0.85
	ring.direction = Vector2.ZERO
	ring.spread = 180.0
	ring.initial_velocity_min = 70.0
	ring.initial_velocity_max = 140.0
	ring.gravity = Vector2.ZERO
	ring.color = _UITheme.ACTION_CYAN
	add_child(ring)
	ring.emitting = true
	get_tree().create_timer(SHIELD_ABSORB_DURATION + 0.2).timeout.connect(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)


func play_reroll_lift() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), REROLL_LIFT_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2(1.03, 1.03), REROLL_LIFT_DURATION * 0.55).set_ease(Tween.EASE_IN)
	if _bg_panel:
		var mod_tween: Tween = create_tween()
		mod_tween.tween_property(_bg_panel, "modulate", Color(1.15, 1.15, 1.15, 1.0), REROLL_LIFT_DURATION * 0.5)
		mod_tween.tween_property(_bg_panel, "modulate", Color.WHITE, REROLL_LIFT_DURATION * 0.5)


func play_explode_charge() -> void:
	if _bg_panel:
		var panel_tween: Tween = create_tween()
		panel_tween.tween_property(_bg_panel, "modulate", Color(1.0, 0.55, 0.22, 1.0), EXPLODE_CHARGE_DURATION * 0.45)
		panel_tween.tween_property(_bg_panel, "modulate", Color.WHITE, EXPLODE_CHARGE_DURATION * 0.55)
	if _glyph_label:
		var glyph_tween: Tween = create_tween()
		glyph_tween.tween_property(_glyph_label, "scale", Vector2(1.2, 1.2), EXPLODE_CHARGE_DURATION * 0.45)
		glyph_tween.tween_property(_glyph_label, "scale", Vector2.ONE, EXPLODE_CHARGE_DURATION * 0.55)
	_spawn_explode_burst()


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
	if _name_popup:
		_name_popup.rotation = neg_rot

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
				_play_settle_accent()
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

	# Add a small extra bump so collisions feel punchier.
	var my_speed: float = linear_velocity.length()
	var other_speed: float = other_die.linear_velocity.length()
	if my_speed >= BUMP_BOOST_MIN_SPEED and other_speed >= BUMP_BOOST_MIN_SPEED:
		var collision_dir: Vector2 = (global_position - other_die.global_position).normalized()
		if collision_dir == Vector2.ZERO:
			collision_dir = Vector2.RIGHT.rotated(randf() * TAU)
		var bump_impulse: float = clamp(
			(my_speed + other_speed) * BUMP_BOOST_MULTIPLIER,
			BUMP_BOOST_IMPULSE_MIN,
			BUMP_BOOST_IMPULSE_MAX
		)
		if not freeze:
			apply_central_impulse(collision_dir * bump_impulse)
		if not other_die.freeze:
			other_die.apply_central_impulse(-collision_dir * bump_impulse)
		_play_impact_accent()
		other_die._play_impact_accent()

	# Both must be moving fast enough
	if my_speed < REROLL_VELOCITY_THRESHOLD:
		return
	if other_speed < REROLL_VELOCITY_THRESHOLD:
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
	if _name_popup and _name_popup_label and die_data:
		_name_popup_label.text = die_data.dice_name
		_name_popup.visible = true
	if physics_state in [DiePhysicsState.SETTLED, DiePhysicsState.KEPT] and not is_keep_locked:
		_animate_hover(Vector2(HOVER_SCALE, HOVER_SCALE))


func _on_mouse_exited() -> void:
	_is_hovered = false
	if _name_popup:
		_name_popup.visible = false
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


func _play_settle_accent() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(SETTLE_POP_SCALE, SETTLE_POP_SCALE), SETTLE_POP_DURATION * 0.45) \
		.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, SETTLE_POP_DURATION * 0.55) \
		.set_ease(Tween.EASE_IN)
	SFXManager.play_dice_settle()


func _play_impact_accent() -> void:
	if not _bg_panel:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_bg_panel, "modulate", Color(1.22, 1.22, 1.22, 1.0), IMPACT_FLASH_DURATION)
	tween.tween_property(_bg_panel, "modulate", Color.WHITE, IMPACT_FLASH_DURATION)


func _play_radial_effect(color: Color, label_text: String) -> void:
	var fx_root := Node2D.new()
	fx_root.top_level = true
	fx_root.global_position = global_position
	add_child(fx_root)

	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = color
	ring.closed = true
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 20
	for i: int in segments:
		var t: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(t), sin(t)) * 42.0)
	ring.points = points
	fx_root.add_child(ring)

	var tag := Label.new()
	tag.text = label_text
	tag.top_level = false
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(-16, -12)
	tag.add_theme_font_override("font", _UITheme.font_stats())
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", color)
	fx_root.add_child(tag)

	fx_root.scale = Vector2(0.35, 0.35)
	fx_root.modulate.a = 0.95
	var tween: Tween = fx_root.create_tween()
	tween.tween_property(fx_root, "scale", Vector2(1.2, 1.2), MULTIPLY_VFX_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "modulate:a", 0.0, MULTIPLY_VFX_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx_root.queue_free)


func _play_directional_left_effect(color: Color, label_text: String) -> void:
	var fx_root := Node2D.new()
	fx_root.top_level = true
	fx_root.global_position = global_position
	add_child(fx_root)

	var spray := CPUParticles2D.new()
	spray.one_shot = true
	spray.amount = 36
	spray.lifetime = 0.35
	spray.explosiveness = 0.85
	spray.direction = Vector2.LEFT
	spray.spread = 24.0
	spray.initial_velocity_min = 140.0
	spray.initial_velocity_max = 260.0
	spray.gravity = Vector2.ZERO
	spray.color = color
	spray.emitting = true
	fx_root.add_child(spray)

	var streak := Line2D.new()
	streak.width = 4.0
	streak.default_color = color
	streak.points = PackedVector2Array([Vector2.ZERO, Vector2(-120, 0)])
	streak.antialiased = true
	fx_root.add_child(streak)

	var tag := Label.new()
	tag.text = label_text
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(-70, -18)
	tag.add_theme_font_override("font", _UITheme.font_stats())
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", color)
	fx_root.add_child(tag)

	fx_root.modulate.a = 0.95
	var tween: Tween = fx_root.create_tween()
	tween.tween_property(fx_root, "position:x", fx_root.position.x - 20.0, MULTIPLY_VFX_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "modulate:a", 0.0, MULTIPLY_VFX_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx_root.queue_free)


func _spawn_explode_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 26
	burst.lifetime = 0.26
	burst.explosiveness = 0.9
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2.ZERO
	burst.color = _UITheme.EXPLOSION_ORANGE
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)
