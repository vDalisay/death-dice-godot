class_name FlowTransition
extends RefCounted
## Small shared fade/scale helper for modal-style UI transitions.

const DEFAULT_SURFACE_ENTER_DURATION: float = 0.14
const DEFAULT_SURFACE_EXIT_DURATION: float = 0.12


static func play_enter(
		owner: Node,
		focus: CanvasItem,
		duration: float,
		backdrop: CanvasItem = null,
		start_scale: Vector2 = Vector2(1.03, 1.03)
	) -> Tween:
	if backdrop != null:
		backdrop.modulate.a = 0.0
	focus.modulate.a = 0.0
	focus.scale = start_scale
	var tween: Tween = owner.create_tween()
	if backdrop != null:
		tween.tween_property(backdrop, "modulate:a", 1.0, duration)
		tween.parallel().tween_property(focus, "modulate:a", 1.0, duration)
	else:
		tween.tween_property(focus, "modulate:a", 1.0, duration)
	tween.parallel().tween_property(focus, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
	return tween


static func play_exit(
		owner: Node,
		focus: CanvasItem,
		duration: float,
		backdrop: CanvasItem = null,
		end_scale: Vector2 = Vector2(0.98, 0.98)
	) -> Tween:
	var tween: Tween = owner.create_tween()
	if backdrop != null:
		tween.tween_property(backdrop, "modulate:a", 0.0, duration)
		tween.parallel().tween_property(focus, "modulate:a", 0.0, duration)
	else:
		tween.tween_property(focus, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(focus, "scale", end_scale, duration).set_ease(Tween.EASE_IN)
	return tween


static func play_fade_in(
		owner: Node,
		target: CanvasItem,
		duration: float = DEFAULT_SURFACE_ENTER_DURATION,
		start_alpha: float = 0.0
	) -> Tween:
	target.visible = true
	_set_alpha(target, clampf(start_alpha, 0.0, 1.0))
	var tween: Tween = owner.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, duration)
	return tween


static func play_fade_out(
		owner: Node,
		target: CanvasItem,
		duration: float = DEFAULT_SURFACE_EXIT_DURATION
	) -> Tween:
	if not target.visible:
		return null
	var tween: Tween = owner.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, duration)
	tween.finished.connect(
		func() -> void:
			target.visible = false
			_set_alpha(target, 1.0),
		CONNECT_ONE_SHOT
	)
	return tween


static func _set_alpha(target: CanvasItem, alpha: float) -> void:
	var color: Color = target.modulate
	color.a = alpha
	target.modulate = color