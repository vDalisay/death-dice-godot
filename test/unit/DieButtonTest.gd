extends GdUnitTestSuite
## Unit tests for the redesigned DieButton card-style tile.

const DieButtonScene: PackedScene = preload("res://Scenes/DieButton.tscn")
const _UITheme := preload("res://Scripts/UITheme.gd")


func _make_face(face_type: DiceFaceData.FaceType, value: int = 0) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = face_type
	face.value = value
	return face


# ---------------------------------------------------------------------------
# Scene setup
# ---------------------------------------------------------------------------

func test_die_button_has_minimum_100px_size() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	assert_int(int(btn.custom_minimum_size.x)).is_equal(100)
	assert_int(int(btn.custom_minimum_size.y)).is_equal(100)


func test_die_button_has_face_type_icon_node() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	assert_object(btn.get_node("FaceTypeIcon")).is_not_null()


func test_die_button_has_die_name_node() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	assert_object(btn.get_node("DieName")).is_not_null()


# ---------------------------------------------------------------------------
# Face display and glyphs
# ---------------------------------------------------------------------------

func test_show_face_sets_number_text() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.NUMBER, 5), DieButton.DieState.REROLLABLE)
	assert_str(btn.text).is_equal("5")


func test_show_face_sets_auto_keep_corner_glyph() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.AUTO_KEEP, 3), DieButton.DieState.AUTO_KEPT)
	var icon: Label = btn.get_node("FaceTypeIcon") as Label
	assert_str(icon.text).is_equal(_UITheme.GLYPH_STAR)


func test_show_face_sets_shield_corner_glyph() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.SHIELD, 1), DieButton.DieState.AUTO_KEPT)
	var icon: Label = btn.get_node("FaceTypeIcon") as Label
	assert_str(icon.text).is_equal(_UITheme.GLYPH_SHIELD)


func test_show_face_sets_insurance_corner_glyph() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.INSURANCE, 0), DieButton.DieState.AUTO_KEPT)
	var icon: Label = btn.get_node("FaceTypeIcon") as Label
	assert_str(icon.text).is_equal("!")


func test_show_face_sets_cursed_stop_glyph() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.CURSED_STOP, 0), DieButton.DieState.STOPPED)
	var icon: Label = btn.get_node("FaceTypeIcon") as Label
	assert_str(icon.text).contains("☠")


# ---------------------------------------------------------------------------
# Styling state
# ---------------------------------------------------------------------------

func test_setup_starts_unrolled_and_disabled() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.setup(0)
	assert_bool(btn.disabled).is_true()
	assert_int(btn.die_state).is_equal(DieButton.DieState.UNROLLED)


func test_rerollable_state_is_enabled() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.NUMBER, 2), DieButton.DieState.REROLLABLE)
	assert_bool(btn.disabled).is_false()


func test_kept_state_shifts_down() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.NUMBER, 2), DieButton.DieState.KEPT)
	assert_float(btn.position.y).is_greater(0.0)


func test_die_name_is_shown() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.set_die_name("Lucky")
	var die_name_label: Label = btn.get_node("DieName") as Label
	assert_str(die_name_label.text).is_equal("Lucky")


func test_explode_face_uses_styled_glyph() -> void:
	var face: DiceFaceData = _make_face(DiceFaceData.FaceType.EXPLODE, 3)
	assert_str(face.get_display_text()).is_equal("✦3")


func test_stopped_face_click_toggles_to_kept_and_back_to_stopped() -> void:
	var btn: DieButton = auto_free(DieButtonScene.instantiate()) as DieButton
	add_child(btn)
	await await_idle_frame()
	btn.show_face(_make_face(DiceFaceData.FaceType.STOP, 0), DieButton.DieState.STOPPED)
	btn.emit_signal("pressed")
	assert_int(btn.die_state).is_equal(DieButton.DieState.KEPT)
	btn.emit_signal("pressed")
	assert_int(btn.die_state).is_equal(DieButton.DieState.STOPPED)
