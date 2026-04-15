class_name SurfaceTransitionController
extends Node
## Manages surface transitions: fading overlays in/out with tweened opacity.
## Keeps RollPhase focused on turn logic only.

const SURFACE_ENTER_DURATION: float = 0.14
const SURFACE_EXIT_DURATION: float = 0.12

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")

# ── References (call setup() after adding to the tree) ────────────────────
var _roll_phase: Node  ## Owning RollPhase — used for tween creation.
var _roll_content: Control
var _screen_shake: Node

var _surface_transition_tweens: Dictionary = {}


func setup(
	roll_phase: Node,
	roll_content: Control,
	shop_panel: Control,
	forge_panel: Control,
	stage_map_panel: Control,
	screen_shake: Node,
) -> void:
	_roll_phase = roll_phase
	_roll_content = roll_content
	_screen_shake = screen_shake


# ── Public API ────────────────────────────────────────────────────────────

func transition_surface(surface: CanvasItem, should_show: bool) -> void:
	if surface == null:
		return
	var surface_key: int = surface.get_instance_id()
	if _surface_transition_tweens.has(surface_key):
		var prior_tween: Tween = _surface_transition_tweens.get(surface_key) as Tween
		if prior_tween != null and prior_tween.is_valid():
			prior_tween.kill()
		_surface_transition_tweens.erase(surface_key)

	var tween: Tween = null
	if should_show:
		if surface.visible and surface.modulate.a >= 0.999:
			return
		tween = FlowTransitionScript.play_fade_in(_roll_phase, surface, SURFACE_ENTER_DURATION)
	else:
		if not surface.visible:
			return
		tween = FlowTransitionScript.play_fade_out(_roll_phase, surface, SURFACE_EXIT_DURATION)

	if tween == null:
		return
	_surface_transition_tweens[surface_key] = tween
	tween.finished.connect(_on_surface_transition_finished.bind(surface_key), CONNECT_ONE_SHOT)


func set_roll_surface_visible(should_show: bool, show_streak: bool = false, streak_display: Control = null) -> void:
	if should_show and _screen_shake != null:
		_screen_shake.force_restore()
	transition_surface(_roll_content, should_show)
	if streak_display == null:
		return
	if should_show and show_streak:
		transition_surface(streak_display, true)
	else:
		transition_surface(streak_display, false)


# ── Private ───────────────────────────────────────────────────────────────

func _on_surface_transition_finished(surface_key: int) -> void:
	_surface_transition_tweens.erase(surface_key)
