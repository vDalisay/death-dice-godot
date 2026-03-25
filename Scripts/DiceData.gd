class_name DiceData
extends Resource

## Standard D6 face layout (Cubitos-style):
## Faces: 1, 1, 2, ★2, BLANK, STOP
## 4/6 chance of scoring, 1/6 blank, 1/6 stop

const MAX_FACE_VALUE: int = 5

@export var dice_name: String = "Standard D6"
@export var faces: Array[DiceFaceData] = []


func roll() -> DiceFaceData:
	return faces[randi() % faces.size()]


## Upgrades the weakest face on this die. Returns true if an upgrade occurred.
func upgrade_weakest_face() -> bool:
	var worst_index: int = -1
	var worst_power: int = 999
	for i: int in faces.size():
		var power: int = _face_power(faces[i])
		if power < worst_power:
			worst_power = power
			worst_index = i
	if worst_index < 0:
		return false
	var face: DiceFaceData = faces[worst_index]
	match face.type:
		DiceFaceData.FaceType.STOP:
			face.type = DiceFaceData.FaceType.BLANK
			face.value = 0
		DiceFaceData.FaceType.BLANK:
			face.type = DiceFaceData.FaceType.NUMBER
			face.value = 1
		DiceFaceData.FaceType.NUMBER:
			if face.value >= MAX_FACE_VALUE:
				face.type = DiceFaceData.FaceType.AUTO_KEEP
			else:
				face.value += 1
		DiceFaceData.FaceType.AUTO_KEEP:
			if face.value >= MAX_FACE_VALUE:
				return false
			face.value += 1
	return true


func _face_power(face: DiceFaceData) -> int:
	match face.type:
		DiceFaceData.FaceType.STOP:
			return 0
		DiceFaceData.FaceType.BLANK:
			return 1
		DiceFaceData.FaceType.NUMBER:
			return 2 + face.value
		DiceFaceData.FaceType.AUTO_KEEP:
			return 10 + face.value
	return 0


# ---------------------------------------------------------------------------
# Factory methods
# ---------------------------------------------------------------------------

static func make_standard_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Standard D6"
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER,    1],
		[DiceFaceData.FaceType.NUMBER,    1],
		[DiceFaceData.FaceType.NUMBER,    2],
		[DiceFaceData.FaceType.AUTO_KEEP, 2],  # Instantly kept & banked
		[DiceFaceData.FaceType.BLANK,     0],
		[DiceFaceData.FaceType.STOP,      0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


static func make_lucky_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Lucky D6"
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER,    2],
		[DiceFaceData.FaceType.NUMBER,    2],
		[DiceFaceData.FaceType.NUMBER,    3],
		[DiceFaceData.FaceType.AUTO_KEEP, 3],
		[DiceFaceData.FaceType.NUMBER,    1],
		[DiceFaceData.FaceType.STOP,      0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die
