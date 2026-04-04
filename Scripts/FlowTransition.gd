class_name FlowTransition
extends RefCounted
## Small shared fade/scale helper for modal-style UI transitions.


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