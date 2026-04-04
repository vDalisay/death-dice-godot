extends GdUnitTestSuite
## Targeted support-dice rules coverage for turn-persistent shields and bank-time hearts.


func test_rolled_shield_persists_for_turn_after_face_changes() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	root.accumulated_shield_count = 0
	root.current_results[0] = _make_face(DiceFaceData.FaceType.SHIELD, 1)
	root._register_rolled_shields([0], false)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 1)
	assert_int(root._count_shields()).is_equal(1)


func test_banked_hearts_reduce_stop_counter_at_bank_resolution() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	root.accumulated_stop_count = 3
	root.current_results[0] = _make_face(DiceFaceData.FaceType.HEART, 1)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.HEART, 1)
	root.dice_stopped[0] = false
	root.dice_stopped[1] = false
	root.dice_keep[0] = true
	root.dice_keep[1] = false
	root.dice_keep_locked[0] = false
	root.dice_keep_locked[1] = true
	var relief: int = root._apply_banked_heart_relief()
	assert_int(relief).is_equal(2)
	assert_int(root.accumulated_stop_count).is_equal(1)


func _make_face(face_type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = face_type
	face.value = value
	return face