class_name RouteBoardStateMachine
extends RefCounted
## Encapsulates route-board interaction state transitions.

enum InteractionState { CLOSED, INTRO_REVEAL, INTERACTIVE, CLOSING }

var _state: InteractionState = InteractionState.CLOSED


func begin_open(uses_intro_reveal: bool) -> void:
	_state = InteractionState.INTRO_REVEAL if uses_intro_reveal else InteractionState.INTERACTIVE


func mark_intro_reveal_complete() -> void:
	if _state == InteractionState.INTRO_REVEAL:
		_state = InteractionState.INTERACTIVE


func begin_close() -> void:
	_state = InteractionState.CLOSING


func finish_close() -> void:
	_state = InteractionState.CLOSED


func is_intro_reveal() -> bool:
	return _state == InteractionState.INTRO_REVEAL


func is_interactive() -> bool:
	return _state == InteractionState.INTERACTIVE


func allows_hover() -> bool:
	return _state == InteractionState.INTERACTIVE


func allows_selection() -> bool:
	return _state == InteractionState.INTERACTIVE


func get_state() -> InteractionState:
	return _state
