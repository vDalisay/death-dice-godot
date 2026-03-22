class_name DiceData
extends Resource

## Standard D6 face layout (Cubitos-style):
## Faces: 1, 1, 2, 2, BLANK, STOP
## 4/6 chance of scoring, 1/6 blank, 1/6 stop

@export var dice_name: String = "Standard D6"
@export var faces: Array[DiceFaceData] = []

func roll() -> DiceFaceData:
	return faces[randi() % faces.size()]

static func make_standard_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Standard D6"
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 2],
		[DiceFaceData.FaceType.NUMBER, 2],
		[DiceFaceData.FaceType.BLANK,  0],
		[DiceFaceData.FaceType.STOP,   0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die
