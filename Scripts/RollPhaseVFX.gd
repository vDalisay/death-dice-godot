class_name RollPhaseVFX
extends Node
## Visual effects spawned during the roll phase: confetti, multiplier bursts,
## and screen-shake delegation.  Keeps RollPhase free of particle details.

const MULTIPLIER_BURST_DURATION: float = 0.42
const MULTIPLIER_BURST_BAR_OFFSET: float = 26.0
const MULTIPLIER_BURST_Y_JITTER: float = 18.0
const JACKPOT_CONFETTI_AMOUNT: int = 80
const JACKPOT_CONFETTI_LIFETIME: float = 1.8

const _UITheme := preload("res://Scripts/UITheme.gd")

var _screen_shake: Node = null
var _screen_overlay: Node = null
var _host: Control = null  ## Node used for add_child / create_tween / size.


func setup(host: Control, screen_shake: Node, screen_overlay: Node) -> void:
	_host = host
	_screen_shake = screen_shake
	_screen_overlay = screen_overlay


# ── Screen shake ──────────────────────────────────────────────────────────

func shake_screen(intensity: float, duration: float) -> void:
	if _screen_shake == null:
		return
	_screen_shake.shake(intensity, duration)


# ── Jackpot confetti ──────────────────────────────────────────────────────

func spawn_jackpot_confetti() -> void:
	if _host == null:
		return
	var confetti := CPUParticles2D.new()
	confetti.one_shot = true
	confetti.amount = JACKPOT_CONFETTI_AMOUNT
	confetti.lifetime = JACKPOT_CONFETTI_LIFETIME
	confetti.explosiveness = 0.9
	confetti.direction = Vector2(0, -1)
	confetti.spread = 100.0
	confetti.gravity = Vector2(0, 400)
	confetti.initial_velocity_min = 200.0
	confetti.initial_velocity_max = 500.0
	confetti.scale_amount_min = 2.0
	confetti.scale_amount_max = 5.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.0))
	gradient.add_point(0.33, Color(1.0, 0.65, 0.0))
	gradient.add_point(0.66, Color(1.0, 1.0, 0.4))
	gradient.set_color(1, Color(1.0, 0.85, 0.0, 0.0))
	confetti.color_ramp = gradient
	confetti.position = Vector2(_host.size.x / 2.0, _host.size.y * 0.3)
	_host.add_child(confetti)
	confetti.emitting = true
	_host.get_tree().create_timer(JACKPOT_CONFETTI_LIFETIME + 0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(confetti):
				confetti.queue_free()
	)


# ── Multiplier burst ─────────────────────────────────────────────────────

func play_multiply_face_vfx(
	dice_pool: Array,
	current_results: Array[DiceFaceData],
	dice_stopped: Array[bool],
	anchor_position: Vector2,
) -> void:
	var effect_index: int = 0
	for i: int in dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.MULTIPLY:
			var die_data: Variant = dice_pool[i]
			var stop_amplifier: bool = die_data != null and die_data is DiceData and die_data.multiplies_stops
			_spawn_multiplier_burst(
				anchor_position + Vector2(0.0, _burst_vertical_offset(effect_index)),
				face.value,
				stop_amplifier,
			)
			effect_index += 1


func _burst_vertical_offset(effect_index: int) -> float:
	if effect_index == 0:
		return 0.0
	var direction: float = -1.0 if effect_index % 2 == 0 else 1.0
	return direction * ceilf(float(effect_index) * 0.5) * MULTIPLIER_BURST_Y_JITTER


func _spawn_multiplier_burst(burst_position: Vector2, multiplier: int, is_stop_multiplier: bool) -> void:
	if _host == null:
		return
	var fx_root := Node2D.new()
	fx_root.name = "MultiplierBurstFx"
	fx_root.top_level = true
	fx_root.global_position = burst_position
	_host.add_child(fx_root)

	var flame := CPUParticles2D.new()
	flame.one_shot = true
	flame.amount = 36
	flame.lifetime = MULTIPLIER_BURST_DURATION
	flame.explosiveness = 0.82
	flame.direction = Vector2.RIGHT if not is_stop_multiplier else Vector2(0.9, -0.1)
	flame.spread = 34.0
	flame.gravity = Vector2(0.0, -18.0)
	flame.initial_velocity_min = 90.0
	flame.initial_velocity_max = 180.0
	flame.scale_amount_min = 1.4
	flame.scale_amount_max = 2.6
	var flame_gradient := Gradient.new()
	var flame_color: Color = _UITheme.ROSE_ACCENT if is_stop_multiplier else _UITheme.SCORE_GOLD
	flame_gradient.set_color(0, Color(1.0, 0.98, 0.72, 0.95))
	flame_gradient.add_point(0.45, flame_color)
	flame_gradient.set_color(1, Color(flame_color.r, flame_color.g, flame_color.b, 0.0))
	flame.color_ramp = flame_gradient
	fx_root.add_child(flame)

	var tag := Label.new()
	tag.text = "x%d+STOP" % multiplier if is_stop_multiplier else "x%d" % multiplier
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.position = Vector2(-28.0, -18.0)
	tag.size = Vector2(64.0, 24.0)
	tag.add_theme_font_override("font", _UITheme.font_stats())
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", flame_color)
	tag.add_theme_color_override("font_outline_color", Color("#05050A"))
	tag.add_theme_constant_override("outline_size", 5)
	fx_root.add_child(tag)

	flame.emitting = true
	fx_root.scale = Vector2(0.72, 0.72)
	fx_root.modulate.a = 0.95
	var tween: Tween = fx_root.create_tween()
	tween.tween_property(fx_root, "scale", Vector2(1.12, 1.12), MULTIPLIER_BURST_DURATION * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "global_position", burst_position + Vector2(34.0, -8.0), MULTIPLIER_BURST_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fx_root, "modulate:a", 0.0, MULTIPLIER_BURST_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx_root.queue_free)


# ── Overlay flashes ──────────────────────────────────────────────────────

func flash_bust() -> void:
	if _screen_overlay != null and _screen_overlay.has_method("flash_bust"):
		_screen_overlay.flash_bust()


func flash_jackpot() -> void:
	if _screen_overlay != null and _screen_overlay.has_method("flash_jackpot"):
		_screen_overlay.flash_jackpot()


# ── Utility ──────────────────────────────────────────────────────────────

static func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
