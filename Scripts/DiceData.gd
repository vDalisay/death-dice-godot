class_name DiceData
extends Resource

## Standard D6 face layout (Cubitos-style):
## Faces: 1, 1, 2, ★2, BLANK, STOP
## 4/6 chance of scoring, 1/6 blank, 1/6 stop

const MAX_FACE_VALUE: int = 5
const MAX_SHIELD_VALUE: int = 3
const MAX_MULTIPLY_VALUE: int = 4
const MAX_EXPLODE_VALUE: int = 5
const MAX_MULTIPLY_LEFT_VALUE: int = 4
const MAX_CHAIN_ROLLS: int = 10

@export var dice_name: String = "Standard D6"
@export var faces: Array[DiceFaceData] = []
@export var custom_color: Color = Color.TRANSPARENT


func roll() -> DiceFaceData:
	return faces[randi() % faces.size()]


## Returns true if this die has at least one STOP face (balance invariant).
func has_stop_face() -> bool:
	for face: DiceFaceData in faces:
		if face.type == DiceFaceData.FaceType.STOP:
			return true
	return false


## Upgrades the weakest face on this die. Returns true if an upgrade occurred.
## Will not remove the last STOP face (balance invariant).
func upgrade_weakest_face() -> bool:
	var worst_index: int = -1
	var worst_power: int = 999
	for i: int in faces.size():
		var power: int = _face_power(faces[i])
		if power < worst_power:
			# Don't select STOP face if it's the only one remaining
			if faces[i].type == DiceFaceData.FaceType.STOP and _count_stop_faces() <= 1:
				continue
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
		DiceFaceData.FaceType.SHIELD:
			if face.value >= MAX_SHIELD_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.MULTIPLY:
			if face.value >= MAX_MULTIPLY_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.EXPLODE:
			if face.value >= MAX_EXPLODE_VALUE:
				return false
			face.value += 1
		DiceFaceData.FaceType.MULTIPLY_LEFT:
			if face.value >= MAX_MULTIPLY_LEFT_VALUE:
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
		DiceFaceData.FaceType.SHIELD:
			return 8 + face.value
		DiceFaceData.FaceType.AUTO_KEEP:
			return 12 + face.value
		DiceFaceData.FaceType.MULTIPLY:
			return 18 + face.value
		DiceFaceData.FaceType.EXPLODE:
			return 22 + face.value
		DiceFaceData.FaceType.MULTIPLY_LEFT:
			return 18 + face.value
	return 0


func _count_stop_faces() -> int:
	var count: int = 0
	for face: DiceFaceData in faces:
		if face.type == DiceFaceData.FaceType.STOP:
			count += 1
	return count


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


## High risk, high reward die. No blanks, 2 stops as risk tax.
static func make_gambler_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Gambler D6"
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER, 3],
		[DiceFaceData.FaceType.NUMBER, 4],
		[DiceFaceData.FaceType.NUMBER, 5],
		[DiceFaceData.FaceType.NUMBER, 5],
		[DiceFaceData.FaceType.STOP,   0],
		[DiceFaceData.FaceType.STOP,   0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Auto-keep gold mine. Punishing with 2 stops but great when it hits.
static func make_golden_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Golden D6"
	var configs: Array = [
		[DiceFaceData.FaceType.AUTO_KEEP, 2],
		[DiceFaceData.FaceType.AUTO_KEEP, 2],
		[DiceFaceData.FaceType.AUTO_KEEP, 3],
		[DiceFaceData.FaceType.BLANK,     0],
		[DiceFaceData.FaceType.STOP,      0],
		[DiceFaceData.FaceType.STOP,      0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Big numbers die. High ceiling, 2 stops as risk cost.
static func make_heavy_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Heavy D6"
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER, 4],
		[DiceFaceData.FaceType.NUMBER, 5],
		[DiceFaceData.FaceType.NUMBER, 6],
		[DiceFaceData.FaceType.BLANK,  0],
		[DiceFaceData.FaceType.STOP,   0],
		[DiceFaceData.FaceType.STOP,   0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Chain reaction die. EXPLODE faces score AND re-roll. 3 stops — very risky.
static func make_explosive_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Explosive D6"
	var configs: Array = [
		[DiceFaceData.FaceType.EXPLODE, 2],
		[DiceFaceData.FaceType.EXPLODE, 2],
		[DiceFaceData.FaceType.NUMBER,  2],
		[DiceFaceData.FaceType.STOP,    0],
		[DiceFaceData.FaceType.STOP,    0],
		[DiceFaceData.FaceType.STOP,    0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Pink die — multiplies the score of the die to the left. 3 stops, high risk.
static func make_pink_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Pink D6"
	die.custom_color = Color(1.0, 0.4, 0.7)
	var configs: Array = [
		[DiceFaceData.FaceType.MULTIPLY_LEFT, 2],
		[DiceFaceData.FaceType.MULTIPLY_LEFT, 2],
		[DiceFaceData.FaceType.STOP,          0],
		[DiceFaceData.FaceType.STOP,          0],
		[DiceFaceData.FaceType.STOP,          0],
		[DiceFaceData.FaceType.BLANK,         0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Blank canvas — cheapest die, minimal use until upgraded. 1 stop minimum.
static func make_blank_canvas_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Blank Canvas D6"
	var configs: Array = [
		[DiceFaceData.FaceType.BLANK, 0],
		[DiceFaceData.FaceType.BLANK, 0],
		[DiceFaceData.FaceType.BLANK, 0],
		[DiceFaceData.FaceType.BLANK, 0],
		[DiceFaceData.FaceType.BLANK, 0],
		[DiceFaceData.FaceType.STOP,  0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die
