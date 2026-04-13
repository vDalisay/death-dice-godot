class_name DiceUpgradeService
extends RefCounted
## Encapsulates die face upgrade logic so DiceData remains data-centric.


func upgrade_all_faces(die: DiceData, amount: int) -> void:
	if die == null or amount == 0:
		return
	for face: DiceFaceData in die.faces:
		if face == null:
			continue
		face.value = mini(face.value + amount, _max_value_for_type(face.type))


func upgrade_weakest_face(die: DiceData) -> bool:
	var worst_index: int = -1
	var worst_power: int = 999
	for i: int in die.faces.size():
		var power: int = face_power(die.faces[i])
		if power < worst_power:
			# Don't select STOP if this is the last STOP-type face.
			if die.faces[i].type == DiceFaceData.FaceType.STOP and count_stop_faces(die.faces) <= 1:
				continue
			worst_power = power
			worst_index = i
	if worst_index < 0:
		return false

	var face: DiceFaceData = die.faces[worst_index]
	match face.type:
		DiceFaceData.FaceType.CURSED_STOP:
			face.type = DiceFaceData.FaceType.STOP
		DiceFaceData.FaceType.STOP:
			face.type = DiceFaceData.FaceType.BLANK
			face.value = 0
		DiceFaceData.FaceType.BLANK:
			face.type = DiceFaceData.FaceType.NUMBER
			face.value = 1
		DiceFaceData.FaceType.NUMBER:
			if face.value >= DiceData.MAX_FACE_VALUE:
				face.type = DiceFaceData.FaceType.AUTO_KEEP
			else:
				face.value += 1
		DiceFaceData.FaceType.AUTO_KEEP:
			if face.value >= DiceData.MAX_FACE_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.SHIELD:
			if face.value >= DiceData.MAX_SHIELD_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.MULTIPLY:
			if face.value >= DiceData.MAX_MULTIPLY_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.EXPLODE:
			if face.value >= DiceData.MAX_EXPLODE_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.INSURANCE:
			face.type = DiceFaceData.FaceType.SHIELD
			face.value = 1
		DiceFaceData.FaceType.LUCK:
			if face.value >= DiceData.MAX_LUCK_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.HEART:
			if face.value >= DiceData.MAX_HEART_VALUE:
				return false
			face.value += 1
	return true


func face_power(face: DiceFaceData) -> int:
	match face.type:
		DiceFaceData.FaceType.CURSED_STOP:
			return -1
		DiceFaceData.FaceType.STOP:
			return 0
		DiceFaceData.FaceType.BLANK:
			return 1
		DiceFaceData.FaceType.NUMBER:
			return 2 + face.value
		DiceFaceData.FaceType.SHIELD:
			return 8 + face.value
		DiceFaceData.FaceType.INSURANCE:
			return 10
		DiceFaceData.FaceType.LUCK:
			return 6 + face.value
		DiceFaceData.FaceType.HEART:
			return 7 + face.value
		DiceFaceData.FaceType.AUTO_KEEP:
			return 12 + face.value
		DiceFaceData.FaceType.MULTIPLY:
			return 18 + face.value
		DiceFaceData.FaceType.EXPLODE:
			return 22 + face.value
	return 0


func count_stop_faces(faces: Array[DiceFaceData]) -> int:
	var count: int = 0
	for face: DiceFaceData in faces:
		if face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
			count += 1
	return count


func _max_value_for_type(face_type: DiceFaceData.FaceType) -> int:
	match face_type:
		DiceFaceData.FaceType.NUMBER, DiceFaceData.FaceType.AUTO_KEEP:
			return DiceData.MAX_FACE_VALUE
		DiceFaceData.FaceType.SHIELD:
			return DiceData.MAX_SHIELD_VALUE
		DiceFaceData.FaceType.MULTIPLY:
			return DiceData.MAX_MULTIPLY_VALUE
		DiceFaceData.FaceType.EXPLODE:
			return DiceData.MAX_EXPLODE_VALUE
		DiceFaceData.FaceType.LUCK:
			return DiceData.MAX_LUCK_VALUE
		DiceFaceData.FaceType.HEART:
			return DiceData.MAX_HEART_VALUE
		_:
			return maxi(0, 999)
