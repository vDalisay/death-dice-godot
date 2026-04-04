extends Node
## Autoload singleton. Builds and applies the global UI theme at startup.
## Also sets the clear color to the design-system background.

const _UITheme := preload("res://Scripts/UITheme.gd")

func _ready() -> void:
	RenderingServer.set_default_clear_color(_UITheme.BACKGROUND)
