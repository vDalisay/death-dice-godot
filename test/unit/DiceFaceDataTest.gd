extends GdUnitTestSuite
## Unit tests for DiceFaceData resource.


func test_number_face_display() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 3
	assert_str(face.get_display_text()).is_equal("3")


func test_blank_face_display() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.BLANK
	assert_str(face.get_display_text()).is_equal("—")


func test_stop_face_display() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.STOP
	assert_str(face.get_display_text()).is_equal("STOP")


func test_auto_keep_face_display() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.AUTO_KEEP
	face.value = 5
	assert_str(face.get_display_text()).is_equal("★5")


func test_default_face_is_number_zero() -> void:
	var face := DiceFaceData.new()
	assert_int(face.type).is_equal(DiceFaceData.FaceType.NUMBER)
	assert_int(face.value).is_equal(0)
