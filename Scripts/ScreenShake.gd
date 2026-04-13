class_name ScreenShake
extends Node
## Lightweight root-container shake for gameplay feedback.
## Uses ALL FOUR offset properties to translate without resizing the target
## Control. Setting only `position` on a full-rect anchored Control modifies
## offset_left/offset_top while leaving offset_right/offset_bottom at 0, which
## RESIZES the control and causes layout cascades. Instead we shift all four
## offsets by the same delta so size is preserved.

const SHAKE_STEP: float = 0.03
const MAX_INTENSITY: float = 10.0

var _target: Control = null
var _active_nonce: int = 0
var _current_delta: Vector2 = Vector2.ZERO
## Stored base offsets captured at shake start so we can restore precisely.
var _base_offset_left: float = 0.0
var _base_offset_top: float = 0.0
var _base_offset_right: float = 0.0
var _base_offset_bottom: float = 0.0


func setup(target: Control) -> void:
	_target = target


func shake(intensity: float, duration: float) -> void:
	if _target == null or duration <= 0.0:
		return
	# Restore to base before starting a new shake so offsets don't accumulate.
	force_restore()
	_active_nonce += 1
	var nonce: int = _active_nonce
	# Capture current offsets as the base for this shake sequence.
	_base_offset_left   = _target.offset_left
	_base_offset_top    = _target.offset_top
	_base_offset_right  = _target.offset_right
	_base_offset_bottom = _target.offset_bottom
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


## Forcefully restore target to its base offsets and cancel any pending shake.
## Must be called before any scene transition or New Run to prevent drift.
func force_restore() -> void:
	_active_nonce += 1
	_current_delta = Vector2.ZERO
	if _target == null:
		return
	_target.offset_left   = _base_offset_left
	_target.offset_top    = _base_offset_top
	_target.offset_right  = _base_offset_right
	_target.offset_bottom = _base_offset_bottom


func _exit_tree() -> void:
	force_restore()


func _apply_shake_step(nonce: int, new_delta: Vector2) -> void:
	if nonce != _active_nonce or _target == null:
		return
	_current_delta = new_delta
	_target.offset_left   = _base_offset_left   + _current_delta.x
	_target.offset_top    = _base_offset_top    + _current_delta.y
	_target.offset_right  = _base_offset_right  + _current_delta.x
	_target.offset_bottom = _base_offset_bottom + _current_delta.y


func _end_shake(nonce: int) -> void:
	if nonce != _active_nonce or _target == null:
		return
	_current_delta = Vector2.ZERO
	_target.offset_left   = _base_offset_left
	_target.offset_top    = _base_offset_top
	_target.offset_right  = _base_offset_right
	_target.offset_bottom = _base_offset_bottom
