extends GdUnitTestSuite
## Integration test: RollPhase combo detection updates HUD combo badges.


func _make_face(face_type: DiceFaceData.FaceType, value: int = 0) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = face_type
	face.value = value
	return face


func test_check_roll_combos_populates_hud_combo_row() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	# Force active turn state and inject results that satisfy Shield Wall (2 shields).
	root.turn_state = RollPhase.TurnState.ACTIVE
	if root.current_results.size() < 2:
		return
	root.current_results[0] = _make_face(DiceFaceData.FaceType.SHIELD, 1)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.SHIELD, 1)
	for i: int in root.dice_stopped.size():
		root.dice_stopped[i] = false
	root._check_roll_combos()
	runner.simulate_frames(1)
	var combo_container: HFlowContainer = root.hud.get_node("ComboRow/ComboContainer") as HFlowContainer
	assert_int(combo_container.get_child_count()).is_greater(0)
