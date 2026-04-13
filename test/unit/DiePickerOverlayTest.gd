extends GdUnitTestSuite

const OverlayScene: PackedScene = preload("res://Scenes/DiePickerOverlay.tscn")


func test_open_builds_card_per_die() -> void:
	var overlay: DiePickerOverlay = auto_free(OverlayScene.instantiate()) as DiePickerOverlay
	add_child(overlay)
	await await_idle_frame()
	var dice_pool: Array[DiceData] = [DiceData.make_standard_d6(), DiceData.make_lucky_d6()]
	overlay.open(dice_pool)
	await await_idle_frame()
	var grid: GridContainer = overlay.get_node("CenterContainer/Card/MarginContainer/Content/Grid") as GridContainer
	assert_int(grid.get_child_count()).is_equal(dice_pool.size())


func test_select_emits_die_selected() -> void:
	var overlay: DiePickerOverlay = auto_free(OverlayScene.instantiate()) as DiePickerOverlay
	add_child(overlay)
	await await_idle_frame()
	var selected_indices: Array[int] = []
	overlay.die_selected.connect(func(index: int) -> void:
		selected_indices.append(index)
	)
	overlay.open([DiceData.make_standard_d6()])
	await await_idle_frame()
	overlay.call("_on_select_pressed", 0)
	await await_idle_frame()
	assert_int(selected_indices.size()).is_equal(1)
	assert_int(selected_indices[0]).is_equal(0)


func test_cancel_emits_canceled() -> void:
	var overlay: DiePickerOverlay = auto_free(OverlayScene.instantiate()) as DiePickerOverlay
	add_child(overlay)
	await await_idle_frame()
	var canceled_hits: Array[int] = []
	overlay.canceled.connect(func() -> void:
		canceled_hits.append(1)
	)
	overlay.open([DiceData.make_standard_d6()])
	await await_idle_frame()
	overlay.call("_on_cancel_pressed")
	await await_idle_frame()
	assert_int(canceled_hits.size()).is_equal(1)
