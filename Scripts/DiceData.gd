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
const MAX_LUCK_VALUE: int = 3
const MAX_HEART_VALUE: int = 3
const MAX_CHAIN_ROLLS: int = 10

const DiceUpgradeServiceScript: GDScript = preload("res://Scripts/DiceUpgradeService.gd")
var _upgrade_service: RefCounted = DiceUpgradeServiceScript.new()

enum Rarity { GREY, GREEN, BLUE, PURPLE }

const RARITY_GREY_COLOR: Color = Color("#888888")
const RARITY_GREEN_COLOR: Color = Color("#00E676")
const RARITY_BLUE_COLOR: Color = Color("#4488FF")
const RARITY_PURPLE_COLOR: Color = Color("#7C3AED")

@export var dice_name: String = "Standard D6"
@export var faces: Array[DiceFaceData] = []
@export var custom_color: Color = Color.TRANSPARENT
@export var rarity: Rarity = Rarity.GREY
@export var reroll_family_id: String = ""
@export var reroll_tier: int = 0
@export var reroll_upgrade_thresholds: Array[int] = []
@export var reroll_affinity_locked: bool = false


static func get_rarity_color(tier: Rarity) -> Color:
	match tier:
		Rarity.GREY:
			return RARITY_GREY_COLOR
		Rarity.GREEN:
			return RARITY_GREEN_COLOR
		Rarity.BLUE:
			return RARITY_BLUE_COLOR
		Rarity.PURPLE:
			return RARITY_PURPLE_COLOR
	return RARITY_GREY_COLOR


func get_rarity_color_value() -> Color:
	return DiceData.get_rarity_color(rarity)


func is_reroll_evolving() -> bool:
	return not reroll_family_id.is_empty()


func get_reroll_tier_label() -> String:
	if not is_reroll_evolving():
		return ""
	var lock_suffix: String = "*" if reroll_affinity_locked else ""
	return "R%d%s" % [reroll_tier + 1, lock_suffix]


func get_display_name() -> String:
	if not is_reroll_evolving():
		return dice_name
	return "%s [%s]" % [dice_name, get_reroll_tier_label()]


func roll() -> DiceFaceData:
	return faces[randi() % faces.size()]


## Returns true if this die has at least one STOP face (balance invariant).
func has_stop_face() -> bool:
	for face: DiceFaceData in faces:
		if face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
			return true
	return false


## Upgrades the weakest face on this die. Returns true if an upgrade occurred.
## Will not remove the last STOP face (balance invariant).
func upgrade_weakest_face() -> bool:
	return _upgrade_service.upgrade_weakest_face(self)


func apply_reroll_progress(reroll_count: int) -> bool:
	if not is_reroll_evolving() or reroll_upgrade_thresholds.is_empty():
		return false
	var target_tier: int = reroll_tier
	while target_tier < reroll_upgrade_thresholds.size() and reroll_count >= reroll_upgrade_thresholds[target_tier]:
		target_tier += 1
	if target_tier <= reroll_tier:
		return false
	evolve_to_reroll_tier(target_tier)
	return true


func evolve_to_reroll_tier(target_tier: int) -> void:
	if not is_reroll_evolving():
		return
	var template: DiceData = DiceData.make_reroll_chaser_d6(target_tier)
	if template == null:
		return
	var keep_locked: bool = reroll_affinity_locked
	_copy_from(template)
	reroll_affinity_locked = keep_locked or template.reroll_affinity_locked


func _copy_from(source_die: DiceData) -> void:
	dice_name = source_die.dice_name
	custom_color = source_die.custom_color
	rarity = source_die.rarity
	reroll_family_id = source_die.reroll_family_id
	reroll_tier = source_die.reroll_tier
	reroll_upgrade_thresholds = source_die.reroll_upgrade_thresholds.duplicate()
	faces.clear()
	for face: DiceFaceData in source_die.faces:
		var copied_face := DiceFaceData.new()
		copied_face.type = face.type
		copied_face.value = face.value
		faces.append(copied_face)


func _face_power(face: DiceFaceData) -> int:
	return _upgrade_service.face_power(face)


func _count_stop_faces() -> int:
	return _upgrade_service.count_stop_faces(faces)


# ---------------------------------------------------------------------------
# Factory methods
# ---------------------------------------------------------------------------

static func make_standard_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Standard D6"
	die.rarity = Rarity.GREY
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
	die.rarity = Rarity.GREEN
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


static func make_shield_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Shield D6"
	die.rarity = Rarity.GREY
	var configs: Array = [
		[DiceFaceData.FaceType.SHIELD, 1],
		[DiceFaceData.FaceType.SHIELD, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.STOP,   0],
		[DiceFaceData.FaceType.BLANK,  0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


static func make_heart_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Heart D6"
	die.rarity = Rarity.GREEN
	var configs: Array = [
		[DiceFaceData.FaceType.HEART,  1],
		[DiceFaceData.FaceType.HEART,  1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.STOP,   0],
		[DiceFaceData.FaceType.BLANK,  0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## High risk, high reward die. No blanks, 2 stops as risk tax.
static func make_gambler_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Gambler D6"
	die.rarity = Rarity.BLUE
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
	die.rarity = Rarity.BLUE
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
	die.rarity = Rarity.GREEN
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
	die.rarity = Rarity.PURPLE
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
	die.rarity = Rarity.PURPLE
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


## Safety die. INS face prevents bust once, then burns into a blank.
static func make_insurance_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Insurance D6"
	die.rarity = Rarity.BLUE
	var configs: Array = [
		[DiceFaceData.FaceType.INSURANCE, 0],
		[DiceFaceData.FaceType.NUMBER,    2],
		[DiceFaceData.FaceType.NUMBER,    2],
		[DiceFaceData.FaceType.BLANK,     0],
		[DiceFaceData.FaceType.STOP,      0],
		[DiceFaceData.FaceType.STOP,      0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


## Fortune die — LUCK faces improve dice reward rarity. 2 stops.
static func make_fortune_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Fortune D6"
	die.rarity = Rarity.GREEN
	var configs: Array = [
		[DiceFaceData.FaceType.LUCK,   1],
		[DiceFaceData.FaceType.LUCK,   1],
		[DiceFaceData.FaceType.NUMBER, 2],
		[DiceFaceData.FaceType.NUMBER, 2],
		[DiceFaceData.FaceType.STOP,   0],
		[DiceFaceData.FaceType.STOP,   0],
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
	die.rarity = Rarity.GREY
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


## Returns one instance of every known die type (for codex enumeration).
static func get_all_known_dice() -> Array[DiceData]:
	var all: Array[DiceData] = [
		make_standard_d6(),
		make_reroll_chaser_d6(),
		make_reroll_chaser_d6(1),
		make_reroll_chaser_d6(2),
		make_shield_d6(),
		make_heart_d6(),
		make_blank_canvas_d6(),
		make_simple_d6(),
		make_lucky_d6(),
		make_heavy_d6(),
		make_gambler_d6(),
		make_golden_d6(),
		make_insurance_d6(),
		make_explosive_d6(),
		make_pink_d6(),
		make_fortune_d6(),
	]
	return all


## Simple die — no stops, half numbers, half blanks. Safe filler.
static func make_simple_d6() -> DiceData:
	var die := DiceData.new()
	die.dice_name = "Simple D6"
	die.rarity = Rarity.GREY
	var configs: Array = [
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.NUMBER, 1],
		[DiceFaceData.FaceType.BLANK,  0],
		[DiceFaceData.FaceType.BLANK,  0],
		[DiceFaceData.FaceType.BLANK,  0],
	]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type  = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die


static func make_reroll_chaser_d6(tier: int = 0) -> DiceData:
	var die := DiceData.new()
	die.reroll_family_id = "reroll_chaser"
	die.reroll_upgrade_thresholds = [1, 3]
	var configs: Array = []
	match clampi(tier, 0, 2):
		0:
			die.dice_name = "Spark Chaser D6"
			die.rarity = Rarity.GREY
			die.custom_color = Color("#4FB3FF")
			die.reroll_tier = 0
			configs = [
				[DiceFaceData.FaceType.NUMBER, 1],
				[DiceFaceData.FaceType.NUMBER, 2],
				[DiceFaceData.FaceType.NUMBER, 2],
				[DiceFaceData.FaceType.AUTO_KEEP, 1],
				[DiceFaceData.FaceType.BLANK, 0],
				[DiceFaceData.FaceType.STOP, 0],
			]
		1:
			die.dice_name = "Surge Chaser D6"
			die.rarity = Rarity.GREEN
			die.custom_color = Color("#2ED0C2")
			die.reroll_tier = 1
			configs = [
				[DiceFaceData.FaceType.NUMBER, 2],
				[DiceFaceData.FaceType.NUMBER, 2],
				[DiceFaceData.FaceType.NUMBER, 3],
				[DiceFaceData.FaceType.AUTO_KEEP, 2],
				[DiceFaceData.FaceType.EXPLODE, 1],
				[DiceFaceData.FaceType.STOP, 0],
			]
		_:
			die.dice_name = "Tempest Chaser D6"
			die.rarity = Rarity.BLUE
			die.custom_color = Color("#FF8A3D")
			die.reroll_tier = 2
			configs = [
				[DiceFaceData.FaceType.NUMBER, 3],
				[DiceFaceData.FaceType.NUMBER, 3],
				[DiceFaceData.FaceType.NUMBER, 4],
				[DiceFaceData.FaceType.AUTO_KEEP, 3],
				[DiceFaceData.FaceType.EXPLODE, 2],
				[DiceFaceData.FaceType.STOP, 0],
			]
	for config: Array in configs:
		var face := DiceFaceData.new()
		face.type = config[0]
		face.value = config[1]
		die.faces.append(face)
	return die
