extends GdUnitTestSuite
## Unit tests for DiceTray layout + die metadata passthrough.

const DiceTrayScene: PackedScene = preload("res://Scenes/DiceTray.tscn")


func test_dice_tray_spacing_is_8px() -> void:
	var tray: DiceTray = auto_free(DiceTrayScene.instantiate()) as DiceTray
	add_child(tray)
	await await_idle_frame()
	assert_int(tray.get_theme_constant("h_separation")).is_equal(8)
	assert_int(tray.get_theme_constant("v_separation")).is_equal(8)


func test_build_sets_die_names() -> void:
	GameManager.reset_run()
	var tray: DiceTray = auto_free(DiceTrayScene.instantiate()) as DiceTray
	add_child(tray)
	await await_idle_frame()
	tray.build(GameManager.dice_pool.size())
	var first_btn: DieButton = tray.get_die_button(0)
	var die_name_label: Label = first_btn.get_node("DieName") as Label
	assert_str(die_name_label.text).is_not_empty()
