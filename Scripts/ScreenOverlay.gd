class_name ScreenOverlay
extends CanvasLayer
## Full-screen post-processing overlays (scanline + vignette).
## Added as a child of the root Control. Uses CanvasLayer to render on top.

const ScanlineShader: Shader = preload("res://Shaders/scanline.gdshader")
const VignetteShader: Shader = preload("res://Shaders/vignette.gdshader")

const SCANLINE_INTENSITY: float = 0.06
const VIGNETTE_INTENSITY: float = 0.35

var _scanline_rect: ColorRect = null
var _vignette_rect: ColorRect = null
var _enabled: bool = true


func _ready() -> void:
	layer = 100
	_build_scanline()
	_build_vignette()


func set_enabled(value: bool) -> void:
	_enabled = value
	if _scanline_rect:
		_scanline_rect.visible = value
	if _vignette_rect:
		_vignette_rect.visible = value


func _build_scanline() -> void:
	_scanline_rect = ColorRect.new()
	_scanline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = ScanlineShader
	mat.set_shader_parameter("intensity", SCANLINE_INTENSITY)
	_scanline_rect.material = mat
	add_child(_scanline_rect)


func _build_vignette() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VignetteShader
	mat.set_shader_parameter("intensity", VIGNETTE_INTENSITY)
	_vignette_rect.material = mat
	add_child(_vignette_rect)
