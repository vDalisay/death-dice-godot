extends GdUnitTestSuite
## Unit tests for ScreenOverlay shader overlay system.


func test_scanline_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/scanline.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_vignette_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/vignette.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_chromatic_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/chromatic_aberration.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_static_noise_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/static_noise.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_overlay_constants_are_sensible() -> void:
	assert_int(ScreenOverlay.CRT_MASK_TYPE).is_greater(0)
	assert_int(ScreenOverlay.CRT_MASK_TYPE).is_less_equal(5)
	assert_float(ScreenOverlay.CRT_CURVE).is_greater_equal(0.0)
	assert_float(ScreenOverlay.CRT_CURVE).is_less(0.5)
	assert_float(ScreenOverlay.CRT_COLOR_OFFSET).is_greater_equal(-0.5)
	assert_float(ScreenOverlay.CRT_COLOR_OFFSET).is_less_equal(0.5)
	assert_float(ScreenOverlay.CRT_MASK_BRIGHTNESS).is_greater(0.0)
	assert_float(ScreenOverlay.CRT_MASK_BRIGHTNESS).is_less_equal(1.0)
	assert_float(ScreenOverlay.CRT_ASPECT).is_greater(0.0)
	assert_float(ScreenOverlay.CRT_ASPECT).is_less_equal(1.0)
	assert_float(ScreenOverlay.CRT_BLEND_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.CRT_BLEND_STRENGTH).is_less_equal(1.0)
	assert_float(ScreenOverlay.VIGNETTE_INTENSITY).is_greater(0.0)
	assert_float(ScreenOverlay.VIGNETTE_INTENSITY).is_less(1.0)
	assert_float(ScreenOverlay.VIGNETTE_PULSE_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.VIGNETTE_BRUISE_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.VIGNETTE_DRIFT_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_AMBIENT_INTENSITY).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_AMBIENT_INTENSITY).is_less(ScreenOverlay.CHROMATIC_JACKPOT_PEAK)
	assert_float(ScreenOverlay.CHROMATIC_AMBIENT_DRIFT).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_PEAK).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_PEAK).is_less(0.05)
	assert_float(ScreenOverlay.CHROMATIC_JACKPOT_PEAK).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_PEAK).is_greater(ScreenOverlay.CHROMATIC_JACKPOT_PEAK)
	assert_float(ScreenOverlay.CHROMATIC_BUST_DURATION).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_JACKPOT_DURATION).is_greater(0.0)
	assert_float(ScreenOverlay.BARREL_BREATH_STRENGTH).is_greater_equal(0.0)
	assert_float(ScreenOverlay.STATIC_TEAR_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.STATIC_BLOCK_STRENGTH).is_greater(0.0)
	assert_float(ScreenOverlay.BUST_TEAR_STRENGTH).is_greater(ScreenOverlay.STATIC_TEAR_STRENGTH)
	assert_float(ScreenOverlay.BUST_BLOCK_STRENGTH).is_greater(ScreenOverlay.STATIC_BLOCK_STRENGTH)
	assert_float(ScreenOverlay.BUST_GLOW_COLLAPSE_PEAK).is_greater_equal(0.0)


func test_overlay_set_enabled_toggles_visibility() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	assert_bool(overlay._scanline_rect.visible).is_true()
	assert_bool(overlay._vignette_rect.visible).is_true()
	assert_bool(overlay._barrel_rect.visible).is_true()
	overlay.set_enabled(false)
	assert_bool(overlay._scanline_rect.visible).is_false()
	assert_bool(overlay._vignette_rect.visible).is_false()
	assert_bool(overlay._barrel_rect.visible).is_false()
	overlay.set_enabled(true)
	assert_bool(overlay._scanline_rect.visible).is_true()


func test_overlay_uses_canvas_layer_above_ui_layout() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	assert_object(overlay).is_instanceof(CanvasLayer)
	assert_int(overlay.layer).is_equal(100)


func test_scanline_overlay_covers_full_screen() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	assert_float(overlay._scanline_rect.anchor_left).is_equal(0.0)
	assert_float(overlay._scanline_rect.anchor_top).is_equal(0.0)
	assert_float(overlay._scanline_rect.anchor_right).is_equal(1.0)
	assert_float(overlay._scanline_rect.anchor_bottom).is_equal(1.0)


func test_scanline_material_uses_configured_intensity() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	var mask_type: int = overlay._scanline_material.get_shader_parameter("mask_type") as int
	var curve_val: float = overlay._scanline_material.get_shader_parameter("curve") as float
	var color_offset: float = overlay._scanline_material.get_shader_parameter("color_offset") as float
	var mask_brightness: float = overlay._scanline_material.get_shader_parameter("mask_brightness") as float
	var aspect_val: float = overlay._scanline_material.get_shader_parameter("aspect") as float
	var blend_strength: float = overlay._scanline_material.get_shader_parameter("blend_strength") as float
	assert_int(mask_type).is_equal(ScreenOverlay.CRT_MASK_TYPE)
	assert_float(curve_val).is_equal(ScreenOverlay.CRT_CURVE)
	assert_float(color_offset).is_equal(ScreenOverlay.CRT_COLOR_OFFSET)
	assert_float(mask_brightness).is_equal(ScreenOverlay.CRT_MASK_BRIGHTNESS)
	assert_float(aspect_val).is_equal(ScreenOverlay.CRT_ASPECT)
	assert_float(blend_strength).is_equal(ScreenOverlay.CRT_BLEND_STRENGTH)


func test_vignette_material_uses_configured_params() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	var intensity: float = overlay._vignette_material.get_shader_parameter("intensity") as float
	var pulse_strength: float = overlay._vignette_material.get_shader_parameter("pulse_strength") as float
	var bruise_strength: float = overlay._vignette_material.get_shader_parameter("bruise_strength") as float
	var drift_strength: float = overlay._vignette_material.get_shader_parameter("drift_strength") as float
	assert_float(intensity).is_equal(ScreenOverlay.VIGNETTE_INTENSITY)
	assert_float(pulse_strength).is_equal(ScreenOverlay.VIGNETTE_PULSE_STRENGTH)
	assert_float(bruise_strength).is_equal(ScreenOverlay.VIGNETTE_BRUISE_STRENGTH)
	assert_float(drift_strength).is_equal(ScreenOverlay.VIGNETTE_DRIFT_STRENGTH)


func test_static_noise_material_uses_configured_glitch_params() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	var tear_strength: float = overlay._static_material.get_shader_parameter("tear_strength") as float
	var block_strength: float = overlay._static_material.get_shader_parameter("block_strength") as float
	assert_float(tear_strength).is_equal(ScreenOverlay.STATIC_TEAR_STRENGTH)
	assert_float(block_strength).is_equal(ScreenOverlay.STATIC_BLOCK_STRENGTH)


func test_chromatic_rect_starts_visible_with_ambient_instability() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	var ambient_intensity: float = overlay._chromatic_material.get_shader_parameter("ambient_intensity") as float
	var ambient_drift: float = overlay._chromatic_material.get_shader_parameter("ambient_drift") as float
	assert_bool(overlay._chromatic_rect.visible).is_true()
	assert_float(ambient_intensity).is_equal(ScreenOverlay.CHROMATIC_AMBIENT_INTENSITY)
	assert_float(ambient_drift).is_equal(ScreenOverlay.CHROMATIC_AMBIENT_DRIFT)


func test_flash_bust_does_not_error() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	overlay.flash_bust()
	assert_bool(overlay._chromatic_rect.visible).is_true()
	assert_bool(overlay._static_rect.visible).is_true()


func test_distress_burst_shows_red_flash_and_static() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	overlay.distress_burst()
	assert_bool(overlay._distress_flash_rect.visible).is_true()
	assert_bool(overlay._static_rect.visible).is_true()


func test_flash_jackpot_does_not_error() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	overlay.flash_jackpot()
	assert_bool(overlay._chromatic_rect.visible).is_true()
