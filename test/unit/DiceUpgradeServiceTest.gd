extends GdUnitTestSuite
## Unit tests for DiceUpgradeService.

var _service: RefCounted


func before_test() -> void:
	_service = auto_free(preload("res://Scripts/DiceUpgradeService.gd").new())


func _face(type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func test_count_stop_faces_includes_cursed_stop() -> void:
	var faces: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.STOP, 0),
		_face(DiceFaceData.FaceType.CURSED_STOP, 0),
		_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	assert_int(_service.count_stop_faces(faces)).is_equal(2)


func test_face_power_cursed_stop_lower_than_stop() -> void:
	assert_int(_service.face_power(_face(DiceFaceData.FaceType.CURSED_STOP, 0))).is_less(
		_service.face_power(_face(DiceFaceData.FaceType.STOP, 0))
	)


func test_upgrade_weakest_face_converts_cursed_stop_to_stop() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	die.faces[0].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[0].value = 0
	var upgraded: bool = _service.upgrade_weakest_face(die)
	assert_bool(upgraded).is_true()
	assert_int(die.faces[0].type).is_equal(DiceFaceData.FaceType.STOP)


func test_upgrade_weakest_face_does_not_remove_last_stop() -> void:
	var die: DiceData = DiceData.new()
	die.faces = [
		_face(DiceFaceData.FaceType.STOP, 0),
		_face(DiceFaceData.FaceType.NUMBER, 3),
		_face(DiceFaceData.FaceType.NUMBER, 3),
	]
	var upgraded: bool = _service.upgrade_weakest_face(die)
	assert_bool(upgraded).is_true()
	assert_int(_service.count_stop_faces(die.faces)).is_equal(1)
