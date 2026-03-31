class_name PhysicsDie
extends RigidBody2D
## A single die rendered as a RigidBody2D in the physics arena.
## Top-down view: gravity=0, linear_damp slides to a stop.
## Handles face display, tumble animation, collision reroll,
## click interaction for keep/reroll toggle, and settling detection.

const _UITheme := preload("res://Scripts/UITheme.gd")

signal toggled_keep(die_index: int, is_kept: bool)
signal shift_toggled_keep(die_index: int, is_kept: bool)
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
const BUMP_BOOST_MIN_SPEED: float = 34.0
const BUMP_BOOST_IMPULSE_MIN: float = 150.0
const BUMP_BOOST_IMPULSE_MAX: float = 400.0
const BUMP_BOOST_MULTIPLIER: float = 0.14
const BUMP_TANGENT_JITTER: float = 0.22
const BUMP_DAMPEN_FACTOR: float = 0.6
const BUMP_DAMPEN_VELOCITY_FACTOR: float = 0.75
const JITTER_SPEED_CAP: float = 80.0
const JITTER_FORCE_SETTLE_TIME: float = 2.0
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
const KEEP_OPACITY_TWEEN_DURATION: float = 0.12
const NAME_POPUP_FADE_DURATION: float = 0.1
const NAME_POPUP_GAP: float = 8.0
const SHIELD_ABSORB_DURATION: float = 0.3
const REROLL_LIFT_OPACITY: float = 0.55
const LAUNCH_BURST_DURATION: float = 0.28
const EXPLODE_WOBBLE_STEP: float = 0.04
const EXPLODE_WOBBLE_OFFSET: float = 4.0
const LANDING_SLAM_MAX_SCALE: float = 1.16
const LANDING_SLAM_MAX_OFFSET_Y: float = 5.0
const LANDING_SLAM_MIN_TRIGGER_SPEED: float = 120.0
const LANDING_SLAM_SPEED_RANGE: float = 720.0
const LANDING_SLAM_CURVE_EXPONENT: float = 1.3
const LANDING_SLAM_LATERAL_MAX_OFFSET_X: float = 3.0
const LANDING_SLAM_DURATION_MIN_FACTOR: float = 0.8
const LANDING_SLAM_DURATION_MAX_FACTOR: float = 1.25

const TUMBLE_DURATION: float = 0.35
const TUMBLE_TICKS: int = 6
const TUMBLE_MIN_INTERVAL: float = 0.04
const TUMBLE_MAX_INTERVAL: float = 0.3
const TUMBLE_SPEED_FAST: float = 400.0
const TUMBLE_SPEED_SLOW: float = 20.0
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
var _jitter_timer: float = 0.0
var _collision_cooldowns: Dictionary = {}  # body_rid -> float
var _bump_count: int = 0
var _wall_bounce_count: int = 0
var _tumble_timer: float = 0.0
var _pending_face: DiceFaceData = null
var _tumble_tween: Tween = null
var _scale_tween: Tween = null
var _glow_tween: Tween = null
var _opacity_tween: Tween = null
var _popup_tween: Tween = null
var _is_hovered: bool = false
var _peak_speed_since_launch: float = 0.0
var _last_motion_velocity: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Visual nodes (created in _ready)
# ---------------------------------------------------------------------------

var _bg_panel: Panel = null
var _face_label: Label = null
var _glyph_label: Label = null
var _name_popup: Panel = null
var _name_popup_faces: HBoxContainer = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	# Physics setup: top-down (no gravity), damped sliding
	input_pickable = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	gravity_scale = 0.0
	linear_damp = 2.65
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 4
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.65
	physics_material_override.friction = 0.4

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

	# Hover popup showing face squares (hidden by default)
	_name_popup = Panel.new()
	_name_popup.size = Vector2(140, 24)
	_name_popup.top_level = true
	_name_popup.position = Vector2.ZERO
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

	var popup_margin := MarginContainer.new()
	popup_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_margin.add_theme_constant_override("margin_left", 4)
	popup_margin.add_theme_constant_override("margin_right", 4)
	popup_margin.add_theme_constant_override("margin_top", 3)
	popup_margin.add_theme_constant_override("margin_bottom", 3)
	popup_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_popup.add_child(popup_margin)

	_name_popup_faces = HBoxContainer.new()
	_name_popup_faces.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_popup_faces.add_theme_constant_override("separation", 4)
	_name_popup_faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_margin.add_child(_name_popup_faces)

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
	_peak_speed_since_launch = 0.0
	_bump_count = 0
	_wall_bounce_count = 0
	_jitter_timer = 0.0
	_tumble_timer = 0.0
	_pending_face = null
	rarity_color = data.get_rarity_color_value() if data else Color.TRANSPARENT
	_build_face_squares()
	_update_name_popup_position()
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
		_peak_speed_since_launch = 0.0
		_last_motion_velocity = Vector2.ZERO
	_apply_visual()


func tumble(final_face: DiceFaceData) -> void:
	if _tumble_tween and _tumble_tween.is_valid():
		_tumble_tween.kill()
	_pending_face = final_face
	_tumble_timer = 0.0
	_set_random_glyph()


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
	_spawn_stop_smoke(color)
	if _bg_panel:
		var tween: Tween = create_tween()
		tween.tween_property(_bg_panel, "modulate", Color(color, 1.0), STOP_IMPACT_DURATION * 0.45)
		tween.tween_property(_bg_panel, "modulate", Color.WHITE, STOP_IMPACT_DURATION * 0.55)


func play_insurance_trigger() -> void:
	_play_radial_effect(_UITheme.ACTION_CYAN, "INSURANCE")
	var ring: CPUParticles2D = ParticlePool.acquire(self)
	if ring == null:
		return
	ParticlePool.configure_burst(ring, {
		"amount": 30,
		"lifetime": 0.4,
		"explosiveness": 0.8,
		"direction": Vector2.ZERO,
		"spread": 180.0,
		"initial_velocity_min": 80.0,
		"initial_velocity_max": 170.0,
		"gravity": Vector2.ZERO,
		"color": _UITheme.ACTION_CYAN,
	})
	ring.emitting = true
	ParticlePool.release_after(ring, 0.6)


func play_keep_lock_snap() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), KEEP_LOCK_SNAP_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, KEEP_LOCK_SNAP_DURATION * 0.55).set_ease(Tween.EASE_IN)
	_play_radial_effect(_UITheme.SUCCESS_GREEN, "LOCK")


func play_shield_absorb() -> void:
	_play_radial_effect(_UITheme.ACTION_CYAN, "SHIELD")
	var ring: CPUParticles2D = ParticlePool.acquire(self)
	if ring == null:
		return
	ParticlePool.configure_burst(ring, {
		"amount": 18,
		"lifetime": SHIELD_ABSORB_DURATION,
		"explosiveness": 0.85,
		"direction": Vector2.ZERO,
		"spread": 180.0,
		"initial_velocity_min": 70.0,
		"initial_velocity_max": 140.0,
		"gravity": Vector2.ZERO,
		"color": _UITheme.ACTION_CYAN,
	})
	ring.emitting = true
	ParticlePool.release_after(ring, SHIELD_ABSORB_DURATION + 0.2)


func play_reroll_lift() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), REROLL_LIFT_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2(1.03, 1.03), REROLL_LIFT_DURATION * 0.55).set_ease(Tween.EASE_IN)
	var alpha_tween: Tween = create_tween()
	alpha_tween.tween_property(self, "modulate:a", REROLL_LIFT_OPACITY, REROLL_LIFT_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	alpha_tween.tween_property(self, "modulate:a", 1.0, REROLL_LIFT_DURATION * 0.55).set_ease(Tween.EASE_IN)
	_play_visual_offset_pulse(-6.0, REROLL_LIFT_DURATION)
	if _bg_panel:
		var mod_tween: Tween = create_tween()
		mod_tween.tween_property(_bg_panel, "modulate", Color(1.15, 1.15, 1.15, 1.0), REROLL_LIFT_DURATION * 0.5)
		mod_tween.tween_property(_bg_panel, "modulate", Color.WHITE, REROLL_LIFT_DURATION * 0.5)


func play_launch_burst() -> void:
	var burst: CPUParticles2D = ParticlePool.acquire(self)
	if burst == null:
		return
	ParticlePool.configure_burst(burst, {
		"amount": 18,
		"lifetime": LAUNCH_BURST_DURATION,
		"explosiveness": 0.8,
		"direction": Vector2.UP,
		"spread": 60.0,
		"initial_velocity_min": 70.0,
		"initial_velocity_max": 150.0,
		"gravity": Vector2(0.0, 60.0),
		"color": Color(1.0, 1.0, 1.0, 0.6),
	})
	burst.emitting = true
	ParticlePool.release_after(burst, LAUNCH_BURST_DURATION + 0.2)


func play_explode_charge() -> void:
	_play_explode_wobble()
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
		_update_name_popup_position()

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
		var speed: float = linear_velocity.length()
		_peak_speed_since_launch = maxf(_peak_speed_since_launch, speed)
		if speed >= SETTLE_VELOCITY_THRESHOLD:
			_last_motion_velocity = linear_velocity
		# Continuous face cycling while moving.
		if _pending_face and speed >= SETTLE_VELOCITY_THRESHOLD:
			var t: float = clampf((speed - TUMBLE_SPEED_SLOW) / (TUMBLE_SPEED_FAST - TUMBLE_SPEED_SLOW), 0.0, 1.0)
			var interval: float = lerpf(TUMBLE_MAX_INTERVAL, TUMBLE_MIN_INTERVAL, t)
			_tumble_timer += delta
			if _tumble_timer >= interval:
				_tumble_timer -= interval
				_set_random_glyph()
		if speed < SETTLE_VELOCITY_THRESHOLD:
			_settle_timer += delta
			if _settle_timer >= SETTLE_TIME_REQUIRED:
				_resolve_pending_face()
				physics_state = DiePhysicsState.SETTLED
				freeze = true
				_play_settle_accent(_peak_speed_since_launch)
				settled.emit()
		else:
			_settle_timer = 0.0
		# Jitter detection: force-settle dice stuck at low speed for too long.
		if speed < JITTER_SPEED_CAP:
			_jitter_timer += delta
			if _jitter_timer >= JITTER_FORCE_SETTLE_TIME:
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
				_resolve_pending_face()
				physics_state = DiePhysicsState.SETTLED
				freeze = true
				_play_settle_accent(_peak_speed_since_launch)
				settled.emit()
		else:
			_jitter_timer = 0.0


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
	var relative_speed: float = (linear_velocity - other_die.linear_velocity).length()
	if my_speed >= BUMP_BOOST_MIN_SPEED or other_speed >= BUMP_BOOST_MIN_SPEED or relative_speed >= BUMP_BOOST_MIN_SPEED:
		var collision_dir: Vector2 = (global_position - other_die.global_position).normalized()
		if collision_dir == Vector2.ZERO:
			collision_dir = Vector2.RIGHT.rotated(randf() * TAU)
		collision_dir = collision_dir.rotated(randf_range(-BUMP_TANGENT_JITTER, BUMP_TANGENT_JITTER))
		var bump_impulse: float = clamp(
			(my_speed + other_speed + relative_speed * 0.5) * BUMP_BOOST_MULTIPLIER,
			BUMP_BOOST_IMPULSE_MIN,
			BUMP_BOOST_IMPULSE_MAX
		)
		# Dampen repeated bumps to prevent ping-pong between locked dice.
		var dampen: float = pow(BUMP_DAMPEN_FACTOR, mini(_bump_count, 10))
		bump_impulse *= dampen
		if not freeze:
			apply_central_impulse(collision_dir * bump_impulse)
			linear_velocity *= BUMP_DAMPEN_VELOCITY_FACTOR
		if not other_die.freeze:
			other_die.apply_central_impulse(-collision_dir * bump_impulse)
			other_die.linear_velocity *= BUMP_DAMPEN_VELOCITY_FACTOR
		_bump_count += 1
		other_die._bump_count += 1
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
			_handle_click(mb.shift_pressed)


func _handle_click(shift_held: bool = false) -> void:
	_press_bounce()
	if physics_state != DiePhysicsState.SETTLED and physics_state != DiePhysicsState.KEPT:
		return
	if is_keep_locked:
		return

	var target_signal: Signal = shift_toggled_keep if shift_held else toggled_keep
	if is_stopped:
		# Pick up stopped die (Cubitos-style)
		is_stopped = false
		is_kept = false
		target_signal.emit(die_index, false)
	elif is_kept:
		is_kept = false
		target_signal.emit(die_index, false)
	else:
		is_kept = true
		target_signal.emit(die_index, true)
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
	if _name_popup and _name_popup_faces and die_data:
		_update_name_popup_position()
		_name_popup.visible = true
		_name_popup.modulate.a = 0.0
		if _popup_tween and _popup_tween.is_valid():
			_popup_tween.kill()
		_popup_tween = _name_popup.create_tween()
		_popup_tween.tween_property(_name_popup, "modulate:a", 1.0, NAME_POPUP_FADE_DURATION)
	if physics_state in [DiePhysicsState.SETTLED, DiePhysicsState.KEPT] and not is_keep_locked:
		_animate_hover(Vector2(HOVER_SCALE, HOVER_SCALE))
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_mouse_exited() -> void:
	_is_hovered = false
	if _name_popup:
		if _popup_tween and _popup_tween.is_valid():
			_popup_tween.kill()
		_popup_tween = _name_popup.create_tween()
		_popup_tween.tween_property(_name_popup, "modulate:a", 0.0, NAME_POPUP_FADE_DURATION)
		_popup_tween.tween_callback(func() -> void:
			_name_popup.visible = false
		)
	_animate_hover(Vector2.ONE)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _animate_hover(target_scale: Vector2) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target_scale, SCALE_DURATION).set_ease(Tween.EASE_OUT)


func _update_name_popup_position() -> void:
	if _name_popup == null:
		return
	var half_height: float = DIE_SIZE * maxf(0.8, scale.y) * 0.5
	_name_popup.global_position = global_position + Vector2(
		-_name_popup.size.x * 0.5,
		-half_height - NAME_POPUP_GAP - _name_popup.size.y
	)


## Maps a DiceFaceData.FaceType to a display color for the popup face square.
static func face_type_color(ft: DiceFaceData.FaceType) -> Color:
	match ft:
		DiceFaceData.FaceType.NUMBER:
			return _UITheme.BRIGHT_TEXT
		DiceFaceData.FaceType.BLANK:
			return _UITheme.MUTED_TEXT
		DiceFaceData.FaceType.STOP:
			return _UITheme.DANGER_RED
		DiceFaceData.FaceType.AUTO_KEEP:
			return _UITheme.SCORE_GOLD
		DiceFaceData.FaceType.SHIELD:
			return _UITheme.ACTION_CYAN
		DiceFaceData.FaceType.MULTIPLY:
			return _UITheme.SUCCESS_GREEN
		DiceFaceData.FaceType.EXPLODE:
			return _UITheme.EXPLOSION_ORANGE
		DiceFaceData.FaceType.MULTIPLY_LEFT:
			return _UITheme.SUCCESS_GREEN
		DiceFaceData.FaceType.CURSED_STOP:
			return _UITheme.NEON_PURPLE
		DiceFaceData.FaceType.INSURANCE:
			return _UITheme.ACTION_CYAN
	return _UITheme.MUTED_TEXT


func _build_face_squares() -> void:
	if _name_popup_faces == null or die_data == null:
		return
	# Clear existing squares.
	for child: Node in _name_popup_faces.get_children():
		child.queue_free()
	var face_count: int = die_data.faces.size()
	if face_count == 0:
		return
	# Compute square size to fit within popup width with margins + spacing.
	var margin_h: float = 8.0  # 4px left + 4px right
	var spacing: float = 4.0
	var total_spacing: float = spacing * maxf(0.0, face_count - 1)
	var sq_size: float = minf(18.0, (_name_popup.size.x - margin_h - total_spacing) / face_count)
	for face: DiceFaceData in die_data.faces:
		var sq: ColorRect = ColorRect.new()
		sq.custom_minimum_size = Vector2(sq_size, sq_size)
		sq.size = Vector2(sq_size, sq_size)
		sq.color = face_type_color(face.type)
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_popup_faces.add_child(sq)
		# Show face value as text on top of the square.
		var face_lbl := Label.new()
		face_lbl.text = face.get_display_text()
		face_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face_lbl.add_theme_font_override("font", _UITheme.font_mono())
		face_lbl.add_theme_font_size_override("font_size", maxi(7, int(sq_size * 0.55)))
		face_lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.85))
		face_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sq.add_child(face_lbl)
	# Resize popup height to fit squares with margin padding.
	var margin_v: float = 6.0  # 3px top + 3px bottom
	_name_popup.size.y = sq_size + margin_v
	_name_popup.pivot_offset = _name_popup.size * 0.5


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

	# Opacity for kept dice (tweened)
	var target_opacity: float = KEPT_OPACITY if (is_kept or is_keep_locked) else 1.0
	if not is_stopped:
		if _opacity_tween and _opacity_tween.is_valid():
			_opacity_tween.kill()
		if absf(modulate.a - target_opacity) > 0.01:
			_opacity_tween = create_tween()
			_opacity_tween.tween_property(self, "modulate:a", target_opacity, KEEP_OPACITY_TWEEN_DURATION)
		else:
			modulate.a = target_opacity

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


func _resolve_pending_face() -> void:
	if _pending_face:
		show_face(_pending_face)
		pop()
		_pending_face = null


func _play_settle_accent(peak_speed: float) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	var speed_t: float = clampf((peak_speed - LANDING_SLAM_MIN_TRIGGER_SPEED) / LANDING_SLAM_SPEED_RANGE, 0.0, 1.0)
	speed_t = pow(speed_t, LANDING_SLAM_CURVE_EXPONENT)
	var slam_scale: float = lerpf(SETTLE_POP_SCALE, LANDING_SLAM_MAX_SCALE, speed_t)
	var slam_offset: float = lerpf(1.0, LANDING_SLAM_MAX_OFFSET_Y, speed_t)
	var slam_duration: float = SETTLE_POP_DURATION * lerpf(LANDING_SLAM_DURATION_MIN_FACTOR, LANDING_SLAM_DURATION_MAX_FACTOR, speed_t)
	var lateral_offset_x: float = 0.0
	if _last_motion_velocity.length() > 0.01:
		lateral_offset_x = clampf(
			_last_motion_velocity.normalized().x * LANDING_SLAM_LATERAL_MAX_OFFSET_X * speed_t,
			-LANDING_SLAM_LATERAL_MAX_OFFSET_X,
			LANDING_SLAM_LATERAL_MAX_OFFSET_X
		)
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(slam_scale, slam_scale), slam_duration * 0.45) \
		.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, slam_duration * 0.55) \
		.set_ease(Tween.EASE_IN)
	_play_visual_offset_pulse_xy(lateral_offset_x, slam_offset, slam_duration)
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

	var spray: CPUParticles2D = ParticlePool.acquire(self)
	if spray:
		spray.top_level = true
		spray.global_position = global_position
		ParticlePool.configure_burst(spray, {
			"amount": 36,
			"lifetime": 0.35,
			"explosiveness": 0.85,
			"direction": Vector2.LEFT,
			"spread": 24.0,
			"initial_velocity_min": 140.0,
			"initial_velocity_max": 260.0,
			"gravity": Vector2.ZERO,
			"color": color,
		})
		spray.emitting = true
		ParticlePool.release_after(spray, 0.55)

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
	var burst: CPUParticles2D = ParticlePool.acquire(self)
	if burst == null:
		return
	ParticlePool.configure_burst(burst, {
		"amount": 26,
		"lifetime": 0.26,
		"explosiveness": 0.9,
		"direction": Vector2.ZERO,
		"spread": 180.0,
		"initial_velocity_min": 120.0,
		"initial_velocity_max": 220.0,
		"gravity": Vector2.ZERO,
		"color": _UITheme.EXPLOSION_ORANGE,
	})
	burst.emitting = true
	ParticlePool.release_after(burst, 0.5)


func _spawn_stop_smoke(color: Color) -> void:
	var puff: CPUParticles2D = ParticlePool.acquire(self)
	if puff == null:
		return
	ParticlePool.configure_burst(puff, {
		"amount": 14,
		"lifetime": 0.28,
		"explosiveness": 0.75,
		"direction": Vector2.ZERO,
		"spread": 180.0,
		"initial_velocity_min": 28.0,
		"initial_velocity_max": 70.0,
		"gravity": Vector2(0, -24.0),
		"color": Color(color.r, color.g, color.b, 0.75),
	})
	puff.emitting = true
	ParticlePool.release_after(puff, 0.5)


func _play_explode_wobble() -> void:
	if _bg_panel == null:
		return
	var base_bg: Vector2 = _bg_panel.position
	var base_face: Vector2 = _face_label.position if _face_label else Vector2.ZERO
	var base_glyph: Vector2 = _glyph_label.position if _glyph_label else Vector2.ZERO
	var wobble: Tween = create_tween()
	wobble.tween_callback(func() -> void:
		_bg_panel.position = base_bg + Vector2(-EXPLODE_WOBBLE_OFFSET, 0)
		if _face_label:
			_face_label.position = base_face + Vector2(-EXPLODE_WOBBLE_OFFSET, 0)
		if _glyph_label:
			_glyph_label.position = base_glyph + Vector2(-EXPLODE_WOBBLE_OFFSET, 0)
	)
	wobble.tween_interval(EXPLODE_WOBBLE_STEP)
	wobble.tween_callback(func() -> void:
		_bg_panel.position = base_bg + Vector2(EXPLODE_WOBBLE_OFFSET, 0)
		if _face_label:
			_face_label.position = base_face + Vector2(EXPLODE_WOBBLE_OFFSET, 0)
		if _glyph_label:
			_glyph_label.position = base_glyph + Vector2(EXPLODE_WOBBLE_OFFSET, 0)
	)
	wobble.tween_interval(EXPLODE_WOBBLE_STEP)
	wobble.tween_callback(func() -> void:
		_bg_panel.position = base_bg + Vector2(-EXPLODE_WOBBLE_OFFSET * 0.6, 0)
		if _face_label:
			_face_label.position = base_face + Vector2(-EXPLODE_WOBBLE_OFFSET * 0.6, 0)
		if _glyph_label:
			_glyph_label.position = base_glyph + Vector2(-EXPLODE_WOBBLE_OFFSET * 0.6, 0)
	)
	wobble.tween_interval(EXPLODE_WOBBLE_STEP)
	wobble.tween_callback(func() -> void:
		_bg_panel.position = base_bg
		if _face_label:
			_face_label.position = base_face
		if _glyph_label:
			_glyph_label.position = base_glyph
	)


func _play_visual_offset_pulse(offset_y: float, duration: float) -> void:
	_play_visual_offset_pulse_xy(0.0, offset_y, duration)


func _play_visual_offset_pulse_xy(offset_x: float, offset_y: float, duration: float) -> void:
	if _bg_panel == null:
		return
	var base_bg: Vector2 = _bg_panel.position
	var base_face: Vector2 = _face_label.position if _face_label else Vector2.ZERO
	var base_glyph: Vector2 = _glyph_label.position if _glyph_label else Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_bg_panel, "position:x", base_bg.x + offset_x, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_face_label, "position:x", base_face.x + offset_x, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glyph_label, "position:x", base_glyph.x + offset_x, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bg_panel, "position:y", base_bg.y + offset_y, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_face_label, "position:y", base_face.y + offset_y, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glyph_label, "position:y", base_glyph.y + offset_y, duration * 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bg_panel, "position:x", base_bg.x, duration * 0.55).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_face_label, "position:x", base_face.x, duration * 0.55).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_glyph_label, "position:x", base_glyph.x, duration * 0.55).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_bg_panel, "position:y", base_bg.y, duration * 0.55).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_face_label, "position:y", base_face.y, duration * 0.55).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_glyph_label, "position:y", base_glyph.y, duration * 0.55).set_ease(Tween.EASE_IN)
