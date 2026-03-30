class_name ScreenShake
extends Node
## Lightweight root-container shake for gameplay feedback.

const SHAKE_STEP: float = 0.03
const MAX_INTENSITY: float = 10.0

var _target: Control = null
var _base_position: Vector2 = Vector2.ZERO
var _active_nonce: int = 0


func setup(target: Control) -> void:
	_target = target
	if _target:
		_base_position = _target.position


func shake(intensity: float, duration: float) -> void:
	if _target == null or duration <= 0.0:
		return
	_active_nonce += 1
	var nonce: int = _active_nonce
	var clamped_intensity: float = clampf(intensity, 0.0, MAX_INTENSITY)
	var steps: int = maxi(2, int(ceil(duration / SHAKE_STEP)))
	var tween: Tween = create_tween()
	for i: int in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var amp: float = clamped_intensity * falloff
		var offset := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		tween.tween_callback(func() -> void:
			if nonce != _active_nonce or _target == null:
				return
			_target.position = _base_position + offset
		)
		tween.tween_interval(SHAKE_STEP)
	tween.tween_callback(func() -> void:
		if nonce != _active_nonce or _target == null:
			return
		_target.position = _base_position
	)
