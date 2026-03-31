extends GdUnitTestSuite
## Unit tests for ScreenOverlay shader overlay system.


func test_scanline_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/scanline.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_vignette_shader_loads() -> void:
	var shader: Shader = load("res://Shaders/vignette.gdshader") as Shader
	assert_object(shader).is_not_null()


func test_overlay_constants_are_sensible() -> void:
	var script: GDScript = preload("res://Scripts/ScreenOverlay.gd")
	assert_float(script.SCANLINE_INTENSITY).is_greater(0.0)
	assert_float(script.SCANLINE_INTENSITY).is_less(0.5)
	assert_float(script.VIGNETTE_INTENSITY).is_greater(0.0)
	assert_float(script.VIGNETTE_INTENSITY).is_less(1.0)


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
