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


func test_overlay_constants_are_sensible() -> void:
	assert_float(ScreenOverlay.SCANLINE_INTENSITY).is_greater(0.0)
	assert_float(ScreenOverlay.SCANLINE_INTENSITY).is_less(0.5)
	assert_float(ScreenOverlay.VIGNETTE_INTENSITY).is_greater(0.0)
	assert_float(ScreenOverlay.VIGNETTE_INTENSITY).is_less(1.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_PEAK).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_PEAK).is_less(0.05)
	assert_float(ScreenOverlay.CHROMATIC_JACKPOT_PEAK).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_BUST_DURATION).is_greater(0.0)
	assert_float(ScreenOverlay.CHROMATIC_JACKPOT_DURATION).is_greater(0.0)


func test_overlay_set_enabled_toggles_visibility() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	assert_bool(overlay._scanline_rect.visible).is_true()
	assert_bool(overlay._vignette_rect.visible).is_true()
	overlay.set_enabled(false)
	assert_bool(overlay._scanline_rect.visible).is_false()
	assert_bool(overlay._vignette_rect.visible).is_false()
	overlay.set_enabled(true)
	assert_bool(overlay._scanline_rect.visible).is_true()


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
	var intensity: float = overlay._scanline_material.get_shader_parameter("intensity") as float
	assert_float(intensity).is_equal(ScreenOverlay.SCANLINE_INTENSITY)


func test_chromatic_rect_starts_hidden() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	assert_bool(overlay._chromatic_rect.visible).is_false()


func test_flash_bust_does_not_error() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	overlay.flash_bust()
	assert_bool(overlay._chromatic_rect.visible).is_true()


func test_flash_jackpot_does_not_error() -> void:
	var overlay: ScreenOverlay = auto_free(ScreenOverlay.new())
	add_child(overlay)
	await get_tree().process_frame
	overlay.flash_jackpot()
	assert_bool(overlay._chromatic_rect.visible).is_true()
