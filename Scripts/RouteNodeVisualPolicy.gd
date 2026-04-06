class_name RouteNodeVisualPolicy
extends RefCounted
## Centralizes route-node hover overlay styling tokens.

const OUTLINE_WIDTH: int = 2
const OUTLINE_COLOR: Color = Color("#FF1744")
const PULSE_SCALE: float = 1.03
const PULSE_HALF_CYCLE: float = 0.45


func should_show_hover_outline(is_interactive: bool, is_hovered: bool) -> bool:
	return is_interactive and is_hovered


func get_outline_width() -> int:
	return OUTLINE_WIDTH


func get_outline_color() -> Color:
	return OUTLINE_COLOR


func get_pulse_scale() -> float:
	return PULSE_SCALE


func get_pulse_half_cycle() -> float:
	return PULSE_HALF_CYCLE
