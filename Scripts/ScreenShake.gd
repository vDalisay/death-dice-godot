class_name ScreenShake
extends Node
## Lightweight root-container shake for gameplay feedback.
## Uses delta-based offsets so it works with layout-managed Controls
## (VBoxContainer children, etc.) without caching stale positions.

const SHAKE_STEP: float = 0.03
const MAX_INTENSITY: float = 10.0

var _target: Control = null
var _active_nonce: int = 0
var _current_offset: Vector2 = Vector2.ZERO


func setup(target: Control) -> void:
	_target = target


func shake(intensity: float, duration: float) -> void:
	if _target == null or duration <= 0.0:
		return
	_active_nonce += 1
	var nonce: int = _active_nonce
	var clamped_intensity: float = clampf(intensity, 0.0, MAX_INTENSITY)
	var steps: int = maxi(2, int(ceil(duration / SHAKE_STEP)))
	# Pre-compute offsets to avoid lambda capture issues in the loop.
	var offsets: Array[Vector2] = []
	for i: int in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var amp: float = clamped_intensity * falloff
		offsets.append(Vector2(randf_range(-amp, amp), randf_range(-amp, amp)))
	var tween: Tween = create_tween()
	for i: int in steps:
		tween.tween_callback(_apply_shake_step.bind(nonce, offsets[i]))
		tween.tween_interval(SHAKE_STEP)
	tween.tween_callback(_end_shake.bind(nonce))


func _apply_shake_step(nonce: int, new_offset: Vector2) -> void:
	if nonce != _active_nonce or _target == null:
		return
	_target.position -= _current_offset
	_current_offset = new_offset
	_target.position += _current_offset


func _end_shake(nonce: int) -> void:
	if nonce != _active_nonce or _target == null:
		return
	_target.position -= _current_offset
	_current_offset = Vector2.ZERO
