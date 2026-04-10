class_name ScreenOverlay
extends CanvasLayer
## Full-screen post-processing overlays (scanline + vignette + event shaders).
## Uses CanvasLayer at layer 100 so the screen-texture shaders sample the
## composited UI from all lower layers.

const ScanlineShader: Shader = preload("res://Shaders/scanline.gdshader")
const VignetteShader: Shader = preload("res://Shaders/vignette.gdshader")
const ChromaticShader: Shader = preload("res://Shaders/chromatic_aberration.gdshader")
const BarrelDistortionShader: Shader = preload("res://Shaders/barrel_distortion.gdshader")
const StaticNoiseShader: Shader = preload("res://Shaders/static_noise.gdshader")

const CRT_MASK_TYPE: int = 5
const CRT_CURVE: float = 0.08
const CRT_COLOR_OFFSET: float = 0.0025
const CRT_MASK_BRIGHTNESS: float = 0.94
const CRT_ASPECT: float = 0.5625
const CRT_BLEND_STRENGTH: float = 1.0
const VIGNETTE_INTENSITY: float = 0.72
const VIGNETTE_RADIUS: float = 0.84
const VIGNETTE_SOFTNESS: float = 0.62
const VIGNETTE_PULSE_STRENGTH: float = 0.11
const VIGNETTE_BRUISE_STRENGTH: float = 0.26
const VIGNETTE_DRIFT_STRENGTH: float = 0.16
const VIGNETTE_COLOR: Color = Color("#020705")
const BARREL_STRENGTH: float = 0.0
const BARREL_EDGE_FADE: float = 0.0
const BARREL_BREATH_STRENGTH: float = 0.0
const CHROMATIC_AMBIENT_INTENSITY: float = 0.0018
const CHROMATIC_AMBIENT_DRIFT: float = 0.1
const CHROMATIC_BUST_PEAK: float = 0.031
const CHROMATIC_JACKPOT_PEAK: float = 0.02
const CHROMATIC_BUST_DURATION: float = 0.5
const CHROMATIC_JACKPOT_DURATION: float = 0.4
const DISTRESS_STATIC_PEAK: float = 0.72
const DISTRESS_STATIC_DURATION: float = 0.32
const STATIC_TEAR_STRENGTH: float = 0.62
const STATIC_BLOCK_STRENGTH: float = 0.38
const BUST_TEAR_STRENGTH: float = 0.9
const BUST_BLOCK_STRENGTH: float = 0.56
const BUST_GLOW_COLLAPSE_PEAK: float = 0.0
const DISTRESS_FLASH_ALPHA: float = 0.48
const DISTRESS_FLASH_DURATION: float = 0.12

var _scanline_rect: ColorRect = null
var _scanline_material: ShaderMaterial = null
var _vignette_rect: ColorRect = null
var _vignette_material: ShaderMaterial = null
var _barrel_rect: ColorRect = null
var _barrel_material: ShaderMaterial = null
var _distress_flash_rect: ColorRect = null
var _static_rect: ColorRect = null
var _static_material: ShaderMaterial = null
var _chromatic_rect: ColorRect = null
var _chromatic_material: ShaderMaterial = null
var _chromatic_tween: Tween = null
var _static_tween: Tween = null
var _scanline_bust_tween: Tween = null
var _enabled: bool = true


func _ready() -> void:
	layer = 100
	_build_scanline()
	_build_vignette()
	_build_barrel_distortion()
	_build_distress_flash()
	_build_static_noise()
	_build_chromatic()


func set_enabled(value: bool) -> void:
	_enabled = value
	if _scanline_rect:
		_scanline_rect.visible = value
	if _vignette_rect:
		_vignette_rect.visible = value
	if _barrel_rect:
		_barrel_rect.visible = value
	if _distress_flash_rect:
		_distress_flash_rect.visible = value and _distress_flash_rect.modulate.a > 0.0
	if _static_rect:
		_static_rect.visible = value and _static_rect.visible
	if _chromatic_rect:
		_chromatic_rect.visible = value
	if not value and _distress_flash_rect:
		_distress_flash_rect.modulate.a = 0.0
	if not value and _static_rect:
		_static_rect.visible = false


## Flash chromatic aberration for bust events.
func flash_bust() -> void:
	_flash_chromatic(CHROMATIC_BUST_PEAK, CHROMATIC_BUST_DURATION)
	distress_burst()


## Flash chromatic aberration for jackpot/combo events.
func flash_jackpot() -> void:
	_flash_chromatic(CHROMATIC_JACKPOT_PEAK, CHROMATIC_JACKPOT_DURATION)


func distress_burst() -> void:
	if not _enabled:
		return
	if _distress_flash_rect:
		_distress_flash_rect.visible = true
		_distress_flash_rect.modulate.a = DISTRESS_FLASH_ALPHA
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(_distress_flash_rect, "modulate:a", 0.0, DISTRESS_FLASH_DURATION)
		flash_tween.tween_callback(_hide_distress_flash)
	if _static_material == null or _static_rect == null:
		return
	if _static_tween and _static_tween.is_valid():
		_static_tween.kill()
	if _scanline_bust_tween and _scanline_bust_tween.is_valid():
		_scanline_bust_tween.kill()
	_static_rect.visible = true
	_static_material.set_shader_parameter("tear_strength", STATIC_TEAR_STRENGTH)
	_static_material.set_shader_parameter("block_strength", STATIC_BLOCK_STRENGTH)
	_static_tween = create_tween()
	_static_tween.parallel().tween_method(_set_static_tear_strength, STATIC_TEAR_STRENGTH, BUST_TEAR_STRENGTH, DISTRESS_STATIC_DURATION * 0.18).set_ease(Tween.EASE_OUT)
	_static_tween.parallel().tween_method(_set_static_block_strength, STATIC_BLOCK_STRENGTH, BUST_BLOCK_STRENGTH, DISTRESS_STATIC_DURATION * 0.2).set_ease(Tween.EASE_OUT)
	_static_tween.tween_method(_set_static_intensity, 0.0, DISTRESS_STATIC_PEAK, DISTRESS_STATIC_DURATION * 0.22).set_ease(Tween.EASE_OUT)
	_static_tween.parallel().tween_method(_set_static_tear_strength, BUST_TEAR_STRENGTH, STATIC_TEAR_STRENGTH, DISTRESS_STATIC_DURATION * 0.78).set_ease(Tween.EASE_IN)
	_static_tween.parallel().tween_method(_set_static_block_strength, BUST_BLOCK_STRENGTH, STATIC_BLOCK_STRENGTH, DISTRESS_STATIC_DURATION * 0.78).set_ease(Tween.EASE_IN)
	_static_tween.tween_method(_set_static_intensity, DISTRESS_STATIC_PEAK, 0.0, DISTRESS_STATIC_DURATION * 0.78).set_ease(Tween.EASE_IN)
	_static_tween.tween_callback(_hide_static_noise)
	_scanline_bust_tween = create_tween()
	_scanline_bust_tween.tween_method(_set_scanline_glow_collapse, 0.0, BUST_GLOW_COLLAPSE_PEAK, DISTRESS_STATIC_DURATION * 0.16).set_ease(Tween.EASE_OUT)
	_scanline_bust_tween.tween_method(_set_scanline_glow_collapse, BUST_GLOW_COLLAPSE_PEAK, 0.0, DISTRESS_STATIC_DURATION * 0.84).set_ease(Tween.EASE_IN)


func _flash_chromatic(peak: float, duration: float) -> void:
	if not _enabled or _chromatic_material == null:
		return
	if _chromatic_tween and _chromatic_tween.is_valid():
		_chromatic_tween.kill()
	_chromatic_rect.visible = true
	_chromatic_tween = create_tween()
	_chromatic_tween.tween_method(_set_chromatic_intensity, 0.0, peak, duration * 0.3).set_ease(Tween.EASE_OUT)
	_chromatic_tween.tween_method(_set_chromatic_intensity, peak, 0.0, duration * 0.7).set_ease(Tween.EASE_IN)
	_chromatic_tween.tween_callback(_hide_chromatic)


func _set_chromatic_intensity(value: float) -> void:
	if _chromatic_material:
		_chromatic_material.set_shader_parameter("intensity", value)


func _set_static_intensity(value: float) -> void:
	if _static_material:
		_static_material.set_shader_parameter("intensity", value)


func _set_static_tear_strength(value: float) -> void:
	if _static_material:
		_static_material.set_shader_parameter("tear_strength", value)


func _set_static_block_strength(value: float) -> void:
	if _static_material:
		_static_material.set_shader_parameter("block_strength", value)


func _set_scanline_glow_collapse(_value: float) -> void:
	pass  # CRT shader has no glow_collapse parameter


func _hide_distress_flash() -> void:
	if _distress_flash_rect:
		_distress_flash_rect.visible = false


func _hide_static_noise() -> void:
	if _static_rect:
		_static_rect.visible = false
	if _static_material:
		_static_material.set_shader_parameter("tear_strength", STATIC_TEAR_STRENGTH)
		_static_material.set_shader_parameter("block_strength", STATIC_BLOCK_STRENGTH)


func _hide_chromatic() -> void:
	if _chromatic_rect:
		_chromatic_rect.visible = _enabled


func _build_scanline() -> void:
	_scanline_rect = ColorRect.new()
	_scanline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanline_material = ShaderMaterial.new()
	_scanline_material.shader = ScanlineShader
	_scanline_material.set_shader_parameter("mask_type", CRT_MASK_TYPE)
	_scanline_material.set_shader_parameter("curve", CRT_CURVE)
	_scanline_material.set_shader_parameter("color_offset", CRT_COLOR_OFFSET)
	_scanline_material.set_shader_parameter("mask_brightness", CRT_MASK_BRIGHTNESS)
	_scanline_material.set_shader_parameter("aspect", CRT_ASPECT)
	_scanline_material.set_shader_parameter("blend_strength", CRT_BLEND_STRENGTH)
	_scanline_rect.material = _scanline_material
	add_child(_scanline_rect)


func _build_vignette() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VignetteShader
	_vignette_material.set_shader_parameter("radius", VIGNETTE_RADIUS)
	_vignette_material.set_shader_parameter("softness", VIGNETTE_SOFTNESS)
	_vignette_material.set_shader_parameter("intensity", VIGNETTE_INTENSITY)
	_vignette_material.set_shader_parameter("pulse_strength", VIGNETTE_PULSE_STRENGTH)
	_vignette_material.set_shader_parameter("bruise_strength", VIGNETTE_BRUISE_STRENGTH)
	_vignette_material.set_shader_parameter("drift_strength", VIGNETTE_DRIFT_STRENGTH)
	_vignette_material.set_shader_parameter("color", VIGNETTE_COLOR)
	_vignette_rect.material = _vignette_material
	add_child(_vignette_rect)


func _build_barrel_distortion() -> void:
	_barrel_rect = ColorRect.new()
	_barrel_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barrel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barrel_material = ShaderMaterial.new()
	_barrel_material.shader = BarrelDistortionShader
	_barrel_material.set_shader_parameter("strength", BARREL_STRENGTH)
	_barrel_material.set_shader_parameter("edge_fade", BARREL_EDGE_FADE)
	_barrel_material.set_shader_parameter("breath_strength", BARREL_BREATH_STRENGTH)
	_barrel_rect.material = _barrel_material
	add_child(_barrel_rect)


func _build_distress_flash() -> void:
	_distress_flash_rect = ColorRect.new()
	_distress_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_distress_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distress_flash_rect.color = Color("#6F0F18")
	_distress_flash_rect.modulate.a = 0.0
	_distress_flash_rect.visible = false
	add_child(_distress_flash_rect)


func _build_static_noise() -> void:
	_static_rect = ColorRect.new()
	_static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_rect.visible = false
	_static_material = ShaderMaterial.new()
	_static_material.shader = StaticNoiseShader
	_static_material.set_shader_parameter("intensity", 0.0)
	_static_material.set_shader_parameter("tear_strength", STATIC_TEAR_STRENGTH)
	_static_material.set_shader_parameter("block_strength", STATIC_BLOCK_STRENGTH)
	_static_rect.material = _static_material
	add_child(_static_rect)


func _build_chromatic() -> void:
	_chromatic_rect = ColorRect.new()
	_chromatic_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chromatic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chromatic_rect.visible = _enabled
	_chromatic_material = ShaderMaterial.new()
	_chromatic_material.shader = ChromaticShader
	_chromatic_material.set_shader_parameter("intensity", 0.0)
	_chromatic_material.set_shader_parameter("ambient_intensity", CHROMATIC_AMBIENT_INTENSITY)
	_chromatic_material.set_shader_parameter("ambient_drift", CHROMATIC_AMBIENT_DRIFT)
	_chromatic_rect.material = _chromatic_material
	add_child(_chromatic_rect)
