class_name ScreenOverlay
extends CanvasLayer
## Full-screen post-processing overlays (scanline + vignette + event shaders).
## Added as a child of the root Control. Uses CanvasLayer to render on top.

const ScanlineShader: Shader = preload("res://Shaders/scanline.gdshader")
const VignetteShader: Shader = preload("res://Shaders/vignette.gdshader")
const ChromaticShader: Shader = preload("res://Shaders/chromatic_aberration.gdshader")

const SCANLINE_INTENSITY: float = 0.06
const VIGNETTE_INTENSITY: float = 0.35
const CHROMATIC_BUST_PEAK: float = 0.025
const CHROMATIC_JACKPOT_PEAK: float = 0.015
const CHROMATIC_BUST_DURATION: float = 0.5
const CHROMATIC_JACKPOT_DURATION: float = 0.4

var _scanline_rect: ColorRect = null
var _vignette_rect: ColorRect = null
var _chromatic_rect: ColorRect = null
var _chromatic_material: ShaderMaterial = null
var _chromatic_tween: Tween = null
var _enabled: bool = true


func _ready() -> void:
	layer = 100
	_build_scanline()
	_build_vignette()
	_build_chromatic()


func set_enabled(value: bool) -> void:
	_enabled = value
	if _scanline_rect:
		_scanline_rect.visible = value
	if _vignette_rect:
		_vignette_rect.visible = value


## Flash chromatic aberration for bust events.
func flash_bust() -> void:
	_flash_chromatic(CHROMATIC_BUST_PEAK, CHROMATIC_BUST_DURATION)


## Flash chromatic aberration for jackpot/combo events.
func flash_jackpot() -> void:
	_flash_chromatic(CHROMATIC_JACKPOT_PEAK, CHROMATIC_JACKPOT_DURATION)


func _flash_chromatic(peak: float, duration: float) -> void:
	if not _enabled or _chromatic_material == null:
		return
	if _chromatic_tween and _chromatic_tween.is_valid():
		_chromatic_tween.kill()
	_chromatic_rect.visible = true
	_chromatic_tween = create_tween()
	_chromatic_tween.tween_method(_set_chromatic_intensity, 0.0, peak, duration * 0.3).set_ease(Tween.EASE_OUT)
	_chromatic_tween.tween_method(_set_chromatic_intensity, peak, 0.0, duration * 0.7).set_ease(Tween.EASE_IN)
	_chromatic_tween.tween_callback(func() -> void:
		_chromatic_rect.visible = false
	)


func _set_chromatic_intensity(value: float) -> void:
	if _chromatic_material:
		_chromatic_material.set_shader_parameter("intensity", value)


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


func _build_chromatic() -> void:
	_chromatic_rect = ColorRect.new()
	_chromatic_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chromatic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chromatic_rect.visible = false
	_chromatic_material = ShaderMaterial.new()
	_chromatic_material.shader = ChromaticShader
	_chromatic_material.set_shader_parameter("intensity", 0.0)
	_chromatic_rect.material = _chromatic_material
	add_child(_chromatic_rect)
