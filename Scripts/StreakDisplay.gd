class_name StreakDisplay
extends Control
## Animated fire streak indicator. Shows a growing fire effect with the
## current multiplier displayed inside. Positioned in the upper-left corner.

const BASE_SIZE: Vector2 = Vector2(80, 80)
const MAX_SIZE: Vector2 = Vector2(160, 160)
const FIRE_CHARS: Array[String] = ["🔥", "🔥", "🔥", "🔥", "🔥"]
const FLICKER_INTERVAL: float = 0.12
const PULSE_DURATION: float = 0.8

var _streak: int = 0
var _multiplier: float = 1.0
var _fire_labels: Array[Label] = []
var _mult_label: Label = null
var _container: Control = null
var _flicker_timer: float = 0.0
var _pulse_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Container for fire + multiplier, anchored top-left.
	_container = Control.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.position = Vector2(12, 12)
	add_child(_container)

	# Create layered fire emoji labels for depth effect.
	for i: int in FIRE_CHARS.size():
		var lbl: Label = Label.new()
		lbl.text = FIRE_CHARS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container.add_child(lbl)
		_fire_labels.append(lbl)

	# Multiplier text, centered on the fire.
	_mult_label = Label.new()
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_mult_label)

	visible = false


func _process(delta: float) -> void:
	if not visible or _streak < 1:
		return
	# Flicker: slightly randomise fire label offsets and opacity for liveliness.
	_flicker_timer += delta
	if _flicker_timer >= FLICKER_INTERVAL:
		_flicker_timer -= FLICKER_INTERVAL
		_apply_flicker()


## Update the streak display to match the current bank_streak value.
func update_streak(streak: int, multiplier: float) -> void:
	_streak = streak
	_multiplier = multiplier
	if streak < 1:
		_hide_fire()
		return
	visible = true
	_layout_fire()
	_play_pulse()


func _hide_fire() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	visible = false


func _layout_fire() -> void:
	# Scale grows with streak: streak 1 = base, streak 10+ = max.
	var t: float = clampf(float(_streak - 1) / 9.0, 0.0, 1.0)
	var display_size: Vector2 = BASE_SIZE.lerp(MAX_SIZE, t)

	# How many fire emojis to show (1 at streak 1, up to all 5 at streak 5+).
	var fire_count: int = clampi(_streak, 1, FIRE_CHARS.size())
	var font_size: int = int(lerpf(36.0, 72.0, t))

	for i: int in _fire_labels.size():
		var lbl: Label = _fire_labels[i]
		if i >= fire_count:
			lbl.visible = false
			continue
		lbl.visible = true
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.size = display_size
		# Offset each fire label slightly for a clustered layered look.
		var spread: float = lerpf(4.0, 12.0, t)
		var x_off: float = randf_range(-spread, spread)
		var y_off: float = randf_range(-spread * 0.5, spread * 0.3)
		lbl.position = Vector2(x_off, y_off)

	# Multiplier label — bright white with black outline for contrast.
	var mult_font_size: int = int(lerpf(20.0, 36.0, t))
	_mult_label.add_theme_font_size_override("font_size", mult_font_size)
	_mult_label.add_theme_color_override("font_color", Color.WHITE)
	_mult_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mult_label.add_theme_constant_override("outline_size", int(lerpf(4.0, 8.0, t)))
	if _multiplier > 1.0:
		_mult_label.text = "x%.1f" % _multiplier
	else:
		_mult_label.text = "%d" % _streak
	_mult_label.size = display_size
	_mult_label.position = Vector2.ZERO


func _apply_flicker() -> void:
	for i: int in _fire_labels.size():
		if not _fire_labels[i].visible:
			continue
		var lbl: Label = _fire_labels[i]
		# Subtle position jitter.
		var base_pos: Vector2 = lbl.position
		lbl.position.x = base_pos.x + randf_range(-2.0, 2.0)
		lbl.position.y = base_pos.y + randf_range(-3.0, 1.0)
		# Subtle opacity flicker.
		lbl.modulate.a = randf_range(0.7, 1.0)


func _play_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_container.scale = Vector2(1.15, 1.15)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_container, "scale", Vector2.ONE, PULSE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
